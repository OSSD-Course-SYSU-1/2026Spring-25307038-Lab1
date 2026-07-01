/*
 * CoreSpeechProvider - HarmonyOS CoreSpeechKit speech recognition.
 *
 * Supports two modes:
 *   1. BATCH (local files): extract audio, feed entire file, finish.
 *   2. STREAMING (network/capture): start engine, accept writeAudioChunk()
 *      from external source (e.g. AudioPipeline), finish on stop.
 *
 * API Reference: @kit.CoreSpeechKit
 */

import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { VideoDataType } from '../common/constants/CommonConstants';

// ─── Shared types (moved from HuaweiCloudASRService) ───

export type ASRState = 'idle' | 'connecting' | 'connected' | 'streaming' | 'error' | 'closed';

export interface CaptureResult {
  text: string;
  isFinal: boolean;
}

export interface CoreSpeechConfig {
  language: string;
  online: number;
  recognitionMode: string;
}

// ─── Internal types ───

interface Mp4Box {
  size: number;
  type: string;
  offset: number;
}

// ─── Provider ───

export class CoreSpeechProvider {
  private config: CoreSpeechConfig;
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private isActive: boolean = false;
  private isEngineReady: boolean = false;

  onResult?: (result: CaptureResult) => void;
  onStateChange?: (state: ASRState, message?: string) => void;
  onError?: (error: string) => void;

  constructor(config: CoreSpeechConfig) {
    this.config = config;
    this.sessionId = 'core_speech_' + Date.now().toString();
  }

  // ─── BATCH MODE: local file (backward compatible) ───

  async start(videoSrc: string, videoType: VideoDataType): Promise<void> {
    this.isActive = true;
    this.onStateChange?.('connecting', '正在初始化本地语音识别引擎...');

    try {
      await this.createEngine();
      this.setListener();
      this.startListening();
      await this.processLocalAudio(videoSrc, videoType);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CoreSpeech] 启动失败: ${err.message}`);
      this.onError?.(`本地语音识别启动失败: ${err.message}`);
    }
  }

  // ─── STREAMING MODE: network / playback capture ───

  /**
   * Initialize engine and start listening WITHOUT processing a file.
   * Caller should feed audio via writeAudioChunk().
   */
  async startStreaming(): Promise<void> {
    this.isActive = true;
    this.onStateChange?.('connecting', '正在初始化语音识别引擎...');

    await this.createEngine();
    this.setListener();

    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      },
      extraParams: {
        'recognitionMode': 1,
        'maxAudioDuration': 8 * 60 * 60 * 1000
      }
    };

    try {
      this.asrEngine?.startListening(startParams);
      this.isEngineReady = true;
      console.info('[CoreSpeech] 流式识别就绪');
      this.onStateChange?.('streaming', '内录采集中...');
    } catch (error) {
      console.error(`[CoreSpeech] startListening失败: ${JSON.stringify(error)}`);
      throw new Error(`startListening失败: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Feed a PCM chunk (640 or 1280 bytes) to the recognition engine.
   * Called by AudioPipeline's PcmChunkCallback for real-time streaming.
   */
  writeAudioChunk(chunk: ArrayBuffer): void {
    if (!this.isActive || !this.isEngineReady || !this.asrEngine) {
      return;
    }
    try {
      this.asrEngine.writeAudio(this.sessionId, new Uint8Array(chunk));
    } catch (error) {
      console.error(`[CoreSpeech] writeAudio失败: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Signal end of audio stream. The engine will finalize recognition.
   * Results arrive via onResult callback.
   */
  finishStreaming(): void {
    if (!this.isEngineReady) {
      return;
    }
    try {
      this.asrEngine?.finish(this.sessionId);
      console.info('[CoreSpeech] 流式识别结束');
    } catch (error) {
      console.error(`[CoreSpeech] finish失败: ${JSON.stringify(error)}`);
    }
  }

  // ─── Engine lifecycle ───

  private async createEngine(): Promise<void> {
    const extraParam: Record<string, Object> = {
      'locate': 'CN',
      'recognizerMode': this.config.recognitionMode
    };

    const initParams: speechRecognizer.CreateEngineParams = {
      language: this.config.language,
      online: this.config.online,
      extraParams: extraParam
    };

    try {
      this.asrEngine = await speechRecognizer.createEngine(initParams);
      console.info('[CoreSpeech] 引擎创建成功');
      this.onStateChange?.('connected', '语音识别引擎就绪');
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CoreSpeech] 创建引擎失败: ${err.code}, ${err.message}`);
      throw new Error(`引擎创建失败 (${err.code}): ${err.message}`);
    }
  }

  private setListener(): void {
    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string) => {
        console.info(`[CoreSpeech] 识别开始: ${sessionId}`);
        this.onStateChange?.('streaming', '正在识别...');
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        console.info(`[CoreSpeech] 事件: ${eventCode}, ${eventMessage}`);
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        console.info(`[CoreSpeech] 识别结果: ${JSON.stringify(result)}`);
        if (result && result.result) {
          this.onResult?.({
            text: result.result,
            isFinal: true
          });
        }
      },
      onComplete: (sessionId: string, eventMessage: string) => {
        console.info(`[CoreSpeech] 识别完成: ${sessionId}`);
        this.onStateChange?.('closed', '识别完成');
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        console.error(`[CoreSpeech] 错误: ${errorCode}, ${errorMessage}`);
        this.onError?.(`识别错误 (${errorCode}): ${errorMessage}`);
      }
    };

    this.asrEngine?.setListener(listener);
  }

  private startListening(): void {
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      },
      extraParams: {
        'recognitionMode': 1,
        'maxAudioDuration': 8 * 60 * 60 * 1000
      }
    };

    try {
      this.asrEngine?.startListening(startParams);
      console.info('[CoreSpeech] 开始监听');
    } catch (error) {
      console.error(`[CoreSpeech] 开始监听失败: ${JSON.stringify(error)}`);
    }
  }

  // ─── Batch audio processing (local files) ───

  private async processLocalAudio(videoSrc: string,
    videoType: VideoDataType): Promise<void> {
    try {
      const pcmData = await this.extractAudioFromLocalVideo(videoSrc, videoType);
      if (!pcmData || pcmData.byteLength === 0) {
        this.onError?.('无法从本地视频提取音频数据');
        return;
      }
      console.info(`[CoreSpeech] 提取音频数据: ${pcmData.byteLength} bytes`);
      await this.feedAudioToEngine(pcmData);
    } catch (error) {
      console.error(`[CoreSpeech] 音频处理失败: ${JSON.stringify(error)}`);
      this.onError?.('音频数据处理失败');
    }
  }

  private async extractAudioFromLocalVideo(videoSrc: string,
    videoType: VideoDataType): Promise<ArrayBuffer | null> {
    try {
      const file = fileIo.openSync(videoSrc, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      if (stat.size === 0) {
        fileIo.closeSync(file);
        return null;
      }
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);

      console.info(`[CoreSpeech] 读取文件: ${stat.size} bytes`);

      if (videoType === VideoDataType.RAW_MP4_FILE ||
        videoSrc.toLowerCase().endsWith('.mp4')) {
        return this.extractAudioFromMp4(buffer);
      }
      return buffer;
    } catch (error) {
      console.error(`[CoreSpeech] 文件读取失败: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private extractAudioFromMp4(data: ArrayBuffer): ArrayBuffer | null {
    try {
      const view = new DataView(data);
      const boxes = this.parseMp4Boxes(view);
      const mdatBox = boxes.find(b => b.type === 'mdat');
      if (!mdatBox) return null;
      const dataOffset = mdatBox.offset + 8;
      const dataSize = mdatBox.size - 8;
      if (dataSize <= 0) return null;
      return view.buffer.slice(dataOffset, dataOffset + dataSize);
    } catch {
      return null;
    }
  }

  private parseMp4Boxes(view: DataView): Mp4Box[] {
    const boxes: Mp4Box[] = [];
    let offset = 0;
    while (offset < view.byteLength - 8) {
      let size = view.getUint32(offset);
      let type = '';
      for (let i = 0; i < 4; i++) {
        const char = view.getUint8(offset + 4 + i);
        if (char >= 0x20 && char <= 0x7e) {
          type += String.fromCharCode(char);
        }
      }
      if (size === 1) {
        const high = view.getUint32(offset + 8);
        const low = view.getUint32(offset + 12);
        size = high * 0x100000000 + low;
      }
      if (size <= 0 || offset + size > view.byteLength) break;
      if (type.length > 0) {
        boxes.push({ size: size, type: type, offset: offset });
      }
      offset += size;
    }
    return boxes;
  }

  private async feedAudioToEngine(pcmData: ArrayBuffer): Promise<void> {
    const chunkSize = 1280;
    let offset = 0;
    while (offset < pcmData.byteLength && this.isActive) {
      const end = Math.min(offset + chunkSize, pcmData.byteLength);
      const chunk = new Uint8Array(pcmData.slice(offset, end));
      try {
        this.asrEngine?.writeAudio(this.sessionId, chunk);
      } catch (error) {
        console.error(`[CoreSpeech] 写入音频失败: ${JSON.stringify(error)}`);
      }
      offset = end;
      if (offset < pcmData.byteLength) {
        await new Promise<void>(resolve => setTimeout(resolve, 20));
      }
    }
    try {
      this.asrEngine?.finish(this.sessionId);
    } catch (error) {
      console.error(`[CoreSpeech] finish失败: ${JSON.stringify(error)}`);
    }
  }

  // ─── Lifecycle ───

  stop(): void {
    this.isActive = false;
    this.isEngineReady = false;
    try {
      this.asrEngine?.cancel(this.sessionId);
      this.asrEngine?.shutdown();
    } catch (error) {
      console.error(`[CoreSpeech] 停止失败: ${JSON.stringify(error)}`);
    }
    this.asrEngine = null;
  }
}
