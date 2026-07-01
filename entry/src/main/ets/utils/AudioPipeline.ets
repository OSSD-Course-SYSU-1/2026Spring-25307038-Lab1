/*
 * AudioPipeline - Unified audio capture pipeline for AI captioning.
 *
 * Supports two capture sources:
 *   1. PLAYBACK_CAPTURE - Captures system audio output directly (API 10+).
 *      Uses AudioCapturer with SOURCE_TYPE_PLAYBACK_CAPTURE to capture
 *      whatever the device is playing (video audio, music, etc.)
 *      without going through microphone/air.
 *
 *   2. DOWNLOAD_DECODE - Downloads remote audio files and decodes to PCM.
 *      Download + file save is handled in ArkTS.
 *      Audio decoding (AAC/MP3/FLAC/Vorbis/Opus/AMR → PCM) uses
 *      Native C++ OH_AudioCodec via libentry.so.
 *
 * Audio format output: PCM 16kHz mono 16-bit S16LE
 */

import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import nativeDecoder from 'libentry.so';

const TAG = '[AudioPipeline]';
const CHUNK_SIZE_640 = 640;   // ~20ms PCM for real-time ASR
const LOG_DOMAIN = 0x0001;

export enum AudioPipelineSource {
  PLAYBACK_CAPTURE = 'playback_capture',
  DOWNLOAD_DECODE = 'download_decode'
}

export type PcmChunkCallback = (pcmData: ArrayBuffer) => void;

export class AudioPipeline {
  private audioCapturer: audio.AudioCapturer | undefined = undefined;
  private isCapturing: boolean = false;
  private boundReadDataCallback: ((buffer: ArrayBuffer) => void) | undefined = undefined;
  private accumulatedBuffer: ArrayBuffer | undefined = undefined;
  private accumulatedLength: number = 0;
  private chunkSize: number = CHUNK_SIZE_640;

  private onPcmChunk: PcmChunkCallback | undefined = undefined;
  private currentSource: AudioPipelineSource = AudioPipelineSource.PLAYBACK_CAPTURE;

  // Download state
  private isDownloading: boolean = false;

  // Native decoder state
  private isNativeDecoding: boolean = false;

  // Diagnostics
  private chunksEmitted: number = 0;
  private bytesEmitted: number = 0;
  private firstChunkTime: number = 0;
  private pipelineStartTime: number = 0;

  // Callbacks
  onError?: (error: string) => void;
  onStateChange?: (state: string, message?: string) => void;

  /**
   * Register the PCM chunk callback. All captured/decoded PCM data
   * arrives through this callback in 640-byte chunks (~20ms).
   */
  setOnPcmChunk(callback: PcmChunkCallback, chunkSize?: number): void {
    this.onPcmChunk = callback;
    if (chunkSize) {
      this.chunkSize = chunkSize;
    }
  }

  /**
   * Detects whether a URL points to a directly downloadable media file
   * (as opposed to an HTML streaming page).
   */
  static isDownloadableMediaUrl(url: string): boolean {
    const lower = url.toLowerCase();
    // Direct audio files
    if (lower.endsWith('.mp3') || lower.endsWith('.aac') ||
        lower.endsWith('.m4a') || lower.endsWith('.wav') ||
        lower.endsWith('.ogg') || lower.endsWith('.flac') ||
        lower.endsWith('.wma') || lower.endsWith('.opus')) {
      return true;
    }
    // Video files (need audio track extraction via Native decoder)
    if (lower.endsWith('.mp4') || lower.endsWith('.webm') ||
        lower.endsWith('.mov') || lower.endsWith('.mkv') ||
        lower.endsWith('.avi') || lower.endsWith('.flv')) {
      return true;
    }
    return false;
  }

  /**
   * Start audio capture for the given source.
   * @param source The capture source type
   * @param url Optional URL for DOWNLOAD_DECODE source
   */
  async start(source: AudioPipelineSource, url?: string): Promise<void> {
    this.currentSource = source;
    this.pipelineStartTime = Date.now();
    this.chunksEmitted = 0;
    this.bytesEmitted = 0;
    this.firstChunkTime = 0;

    hilog.info(LOG_DOMAIN, TAG,
      `[DIAG] AudioPipeline启动 | source=${source} | url=${url ? url.substring(0, 80) : 'none'}`);
    this.onStateChange?.('connecting');

    switch (source) {
      case AudioPipelineSource.PLAYBACK_CAPTURE:
        try {
          await this.startPlaybackCapture();
          hilog.info(LOG_DOMAIN, TAG,
            `[DIAG] PLAYBACK_CAPTURE 启动成功`);
        } catch (playbackErr) {
          const err = playbackErr as Error;
          hilog.warn(LOG_DOMAIN, TAG,
            `[DIAG] PLAYBACK_CAPTURE 失败 -> 回退 DOWNLOAD_DECODE | 原因: ${err.message}`);
          if (url) {
            this.currentSource = AudioPipelineSource.DOWNLOAD_DECODE;
            await this.startDownloadDecode(url);
          } else {
            hilog.error(LOG_DOMAIN, TAG,
              `[DIAG] PLAYBACK_CAPTURE 失败且无URL回退 | 1秒后重试PLAYBACK_CAPTURE`);
            // Retry playback capture after a brief delay
            // (emulator audio service may need warm-up time)
            await new Promise<void>(r => setTimeout(r, 1000));
            await this.startPlaybackCapture();
          }
        }
        break;
      case AudioPipelineSource.DOWNLOAD_DECODE:
        if (!url) {
          throw new Error('URL is required for DOWNLOAD_DECODE source');
        }
        await this.startDownloadDecode(url);
        break;
    }
  }

  // ───── PLAYBACK_CAPTURE ─────

  /**
   * Uses AudioCapturer with SOURCE_TYPE_PLAYBACK_CAPTURE to capture
   * system audio output directly (internal audio, not microphone).
   */
  private async startPlaybackCapture(): Promise<void> {
    const t0 = Date.now();
    hilog.info(LOG_DOMAIN, TAG,
      `[DIAG] 创建AudioCapturer | source=SOURCE_TYPE_PLAYBACK_CAPTURE(2) | rate=16000 | channels=1 | format=S16LE`);

    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    const audioCapturerInfo: audio.AudioCapturerInfo = {
      source: 2 as audio.SourceType, // SOURCE_TYPE_PLAYBACK_CAPTURE
      capturerFlags: 0
    };

    const audioCapturerOptions: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo,
      capturerInfo: audioCapturerInfo
    };

    try {
      this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);
      const elapsed = Date.now() - t0;
      hilog.info(LOG_DOMAIN, TAG,
        `[DIAG] AudioCapturer创建成功 | 耗时=${elapsed}ms | state=${this.audioCapturer.state}`);
      this.onStateChange?.('connected', '系统音频内录已就绪');
    } catch (error) {
      const err = error as BusinessError;
      const elapsed = Date.now() - t0;
      const errCode = err.code ?? 'unknown';
      hilog.error(LOG_DOMAIN, TAG,
        `[DIAG] AudioCapturer创建失败 | 耗时=${elapsed}ms | code=${errCode} | msg="${err.message}"`);
      throw new Error(`内录初始化失败(错误码${errCode})`);
    }

    await this.startCapturerReadLoop();
  }

  // ───── DOWNLOAD + NATIVE DECODE ─────

  /**
   * Downloads a media file then decodes it to PCM using Native OH_AudioCodec.
   * Falls back to PLAYBACK_CAPTURE if download fails.
   */
  private async startDownloadDecode(url: string): Promise<void> {
    this.onStateChange?.('connecting', '正在下载音频文件...');

    try {
      const tempFilePath = await this.downloadToTempFile(url);
      hilog.info(LOG_DOMAIN, TAG, `Downloaded to: ${tempFilePath}`);

      // Native AudioCodec decoder: AAC/MP3/FLAC/Vorbis/Opus/AMR → PCM
      await this.nativeDecodeToPcm(tempFilePath);

      // Clean up temp file after decoding
      try {
        fs.unlinkSync(tempFilePath);
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, `Failed to delete temp file: ${tempFilePath}`);
      }

    } catch (error) {
      const err = error as BusinessError;
      hilog.error(LOG_DOMAIN, TAG, `Download/decode failed: ${err.message}`);
      this.onError?.(`音频下载/解码失败: ${err.message}`);

      // Fallback to playback capture on failure
      await this.startPlaybackCapture();
    }
  }

  /**
   * Decodes a downloaded audio file to PCM using the Native OH_AudioCodec.
   * PCM chunks are delivered via the registered onPcmChunk callback.
   * Protected by a 60s timeout to prevent hanging on invalid input.
   */
  private async nativeDecodeToPcm(filePath: string): Promise<void> {
    this.isNativeDecoding = true;
    const t0 = Date.now();
    this.onStateChange?.('streaming', 'Native解码中...');

    hilog.info(LOG_DOMAIN, TAG,
      `[DIAG] Native解码开始 | file=${filePath}`);

    // Reset accumulation state for the native decoder output
    this.accumulatedBuffer = new ArrayBuffer(this.chunkSize);
    this.accumulatedLength = 0;

    const DECODE_TIMEOUT_MS = 60000; // 60s timeout

    try {
      await this.withTimeout(
        nativeDecoder.startDecode(filePath, (pcmChunk: ArrayBuffer) => {
          this.onAudioData(pcmChunk);
        }),
        DECODE_TIMEOUT_MS,
        'Native decode timed out'
      );

      const elapsed = Date.now() - t0;
      hilog.info(LOG_DOMAIN, TAG,
        `[DIAG] Native解码完成 | 耗时=${elapsed}ms | 输出块=${this.chunksEmitted} | 输出字节=${this.bytesEmitted}`);

    } catch (decodeErr) {
      const err = decodeErr as Error;
      const elapsed = Date.now() - t0;
      hilog.error(LOG_DOMAIN, TAG,
        `[DIAG] Native解码失败 | 耗时=${elapsed}ms | error=${err.message}`);
      throw err;
    } finally {
      this.isNativeDecoding = false;
    }
  }

  /**
   * Wraps a promise with a timeout. Rejects if the promise
   * doesn't settle within the given milliseconds.
   */
  private withTimeout<T>(promise: Promise<T>, ms: number, message: string): Promise<T> {
    return Promise.race([
      promise,
      new Promise<T>((_, reject) =>
        setTimeout(() => reject(new Error(message)), ms)
      )
    ]);
  }

  /**
   * Downloads a URL to a temporary file in the app's cache directory.
   * Returns the absolute file path on success.
   */
  private async downloadToTempFile(url: string): Promise<string> {
    const t0 = Date.now();
    hilog.info(LOG_DOMAIN, TAG,
      `[DIAG] 开始下载 | url=${url.substring(0, 100)}`);

    const httpRequest = http.createHttp();
    this.isDownloading = true;

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 120000
      });

      const elapsed = Date.now() - t0;

      if (response.responseCode !== 200) {
        hilog.error(LOG_DOMAIN, TAG,
          `[DIAG] 下载失败 | HTTP=${response.responseCode} | 耗时=${elapsed}ms`);
        throw new Error(`HTTP ${response.responseCode}`);
      }

      const buffer = response.result as ArrayBuffer;
      if (!buffer || buffer.byteLength === 0) {
        hilog.error(LOG_DOMAIN, TAG,
          `[DIAG] 下载空响应 | 耗时=${elapsed}ms`);
        throw new Error('Empty response body');
      }

      const sizeKB = Math.round(buffer.byteLength / 1024);
      const rateKBps = Math.round(sizeKB / (elapsed / 1000));
      hilog.info(LOG_DOMAIN, TAG,
        `[DIAG] 下载完成 | 大小=${sizeKB}KB | 耗时=${elapsed}ms | 速率=${rateKBps}KB/s`);

      // Save to temp file in app cache dir
      const context = getContext();
      const tempDir = context.cacheDir;
      const fileName = `audio_dl_${Date.now()}.tmp`;
      const filePath = `${tempDir}/${fileName}`;

      const file = fs.openSync(filePath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, buffer);
      fs.closeSync(file);

      hilog.info(LOG_DOMAIN, TAG,
        `Downloaded ${buffer.byteLength} bytes to ${filePath}`);
      return filePath;

    } finally {
      this.isDownloading = false;
      httpRequest.destroy();
    }
  }

  // ───── COMMON CAPTURE LOOP ─────

  /**
   * Starts the AudioCapturer readData loop and feeds PCM chunks
   * to the registered callback.
   */
  private async startCapturerReadLoop(): Promise<void> {
    if (!this.audioCapturer) {
      this.onError?.('AudioCapturer未初始化');
      return;
    }

    this.accumulatedBuffer = new ArrayBuffer(this.chunkSize);
    this.accumulatedLength = 0;

    this.boundReadDataCallback = (buffer: ArrayBuffer) => {
      this.onAudioData(buffer);
    };

    this.audioCapturer.on('readData', this.boundReadDataCallback);

    try {
      await this.audioCapturer.start();
      this.isCapturing = true;
      const elapsed = Date.now() - this.pipelineStartTime;
      this.onStateChange?.('streaming', '内录采集中...');
      hilog.info(LOG_DOMAIN, TAG,
        `[DIAG] 采集循环已启动 | source=${this.currentSource} | chunk=${this.chunkSize}bytes | 距pipeline启动=${elapsed}ms`);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(LOG_DOMAIN, TAG,
        `[DIAG] AudioCapturer.start()失败: ${err.message}`);
      this.onError?.(`启动采集失败: ${err.message}`);
    }
  }

  /**
   * Accumulates incoming PCM data and emits fixed-size chunks
   * through the onPcmChunk callback.
   */
  private onAudioData(buffer: ArrayBuffer): void {
    if ((!this.isCapturing && !this.isNativeDecoding) || !this.onPcmChunk) {
      return;
    }

    // Log first audio data arrival
    if (this.firstChunkTime === 0) {
      this.firstChunkTime = Date.now();
      const delay = this.firstChunkTime - this.pipelineStartTime;
      hilog.info(LOG_DOMAIN, TAG,
        `[DIAG] 首个音频数据到达 | 距启动=${delay}ms | 大小=${buffer.byteLength}bytes | source=${this.currentSource}`);
    }

    let inputOffset = 0;
    let remaining = buffer.byteLength;

    while (remaining > 0) {
      const spaceLeft = this.chunkSize - this.accumulatedLength;
      const copySize = Math.min(remaining, spaceLeft);

      if (this.accumulatedBuffer) {
        const destView = new Uint8Array(this.accumulatedBuffer);
        destView.set(
          new Uint8Array(buffer, inputOffset, copySize),
          this.accumulatedLength
        );
      }

      this.accumulatedLength += copySize;
      inputOffset += copySize;
      remaining -= copySize;

      if (this.accumulatedLength >= this.chunkSize && this.accumulatedBuffer) {
        const chunk = this.accumulatedBuffer.slice(0, this.chunkSize);
        this.onPcmChunk(chunk);

        this.chunksEmitted++;
        this.bytesEmitted += this.chunkSize;

        // Log every 50 chunks (~1 second)
        if (this.chunksEmitted % 50 === 0) {
          const elapsed = Date.now() - this.firstChunkTime;
          const rate = Math.round(this.bytesEmitted / (elapsed / 1000));
          hilog.info(LOG_DOMAIN, TAG,
            `[DIAG] PCM输出统计 | chunks=${this.chunksEmitted} | bytes=${this.bytesEmitted} | rate=${rate} B/s | source=${this.currentSource}`);
        }

        this.accumulatedBuffer = new ArrayBuffer(this.chunkSize);
        this.accumulatedLength = 0;
      }
    }
  }

  // ───── LIFECYCLE ─────

  /**
   * Stops audio capture and native decoding.
   */
  async stop(): Promise<void> {
    hilog.info(LOG_DOMAIN, TAG,
      `[DIAG] AudioPipeline停止 | chunksEmitted=${this.chunksEmitted} | bytesEmitted=${this.bytesEmitted}`);
    this.isCapturing = false;
    this.isNativeDecoding = false;

    // Stop native decoder if running
    try {
      nativeDecoder.stopDecode();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, TAG, 'Error stopping native decoder');
    }

    if (this.audioCapturer && this.boundReadDataCallback) {
      this.audioCapturer.off('readData', this.boundReadDataCallback);
      this.boundReadDataCallback = undefined;
    }

    if (this.audioCapturer) {
      try {
        await this.audioCapturer.stop();
        hilog.info(LOG_DOMAIN, TAG, 'AudioCapturer stopped');
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(LOG_DOMAIN, TAG, `stop() failed: ${err.message}`);
      }
    }

    this.onStateChange?.('closed', '采集已停止');
  }

  /**
   * Releases all resources (capturer, decoder, download state).
   */
  async release(): Promise<void> {
    await this.stop();

    if (this.audioCapturer) {
      try {
        await this.audioCapturer.release();
        this.audioCapturer = undefined;
        hilog.info(LOG_DOMAIN, TAG, 'AudioCapturer released');
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(LOG_DOMAIN, TAG, `release() failed: ${err.message}`);
      }
    }

    this.onPcmChunk = undefined;
    this.onError = undefined;
    this.onStateChange = undefined;
    this.isCapturing = false;
    this.isDownloading = false;
    this.isNativeDecoding = false;
  }

  get isActive(): boolean {
    return this.isCapturing || this.isDownloading || this.isNativeDecoding;
  }

  get source(): AudioPipelineSource {
    return this.currentSource;
  }
}
