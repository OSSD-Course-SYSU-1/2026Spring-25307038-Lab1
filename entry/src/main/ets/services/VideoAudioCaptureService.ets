/*
 * VideoAudioCaptureService - Detects video source type and routes
 * to the appropriate audio capture + speech recognition strategy:
 *
 *   LOCAL_FILE        → CoreSpeechKit batch mode (reads file → feeds engine)
 *   NETWORK / STREAM  → CoreSpeechKit streaming + AudioPipeline system capture
 *
 * All paths use HarmonyOS CoreSpeechKit (@kit.CoreSpeechKit).
 */

import { VideoDataType } from '../common/constants/CommonConstants';
import { CoreSpeechProvider, CoreSpeechConfig, CaptureResult, ASRState } from './CoreSpeechProvider';
import { AudioPipeline, AudioPipelineSource } from '../utils/AudioPipeline';

export enum AudioSourceType {
  LOCAL_FILE = 'local_file',
  PLAYBACK_CAPTURE = 'playback_capture'
}

export { CaptureResult, ASRState };

export class VideoAudioCaptureService {
  private sourceType: AudioSourceType = AudioSourceType.PLAYBACK_CAPTURE;
  private coreSpeechProvider: CoreSpeechProvider | null = null;
  private audioPipeline: AudioPipeline | null = null;
  private videoUrl: string = '';
  private videoType: VideoDataType | null = null;

  // Callbacks
  onResult?: (result: CaptureResult) => void;
  onStateChange?: (state: ASRState, message?: string) => void;
  onError?: (error: string) => void;

  /**
   * Detect video source type.
   */
  detectSourceType(videoType: VideoDataType, videoSrc: string): AudioSourceType {
    this.videoType = videoType;
    this.videoUrl = videoSrc;

    let detectedType: AudioSourceType;

    switch (videoType) {
      case VideoDataType.RAW_FILE:
      case VideoDataType.RAW_M3U8_FILE:
      case VideoDataType.RAW_MP4_FILE:
        detectedType = AudioSourceType.LOCAL_FILE;
        break;
      default:
        detectedType = AudioSourceType.PLAYBACK_CAPTURE;
        break;
    }

    console.info(`[字幕][DIAG] 源检测 | videoType=${videoType} | url=${videoSrc.substring(0, 80)} | result=${detectedType}`);
    return detectedType;
  }

  /**
   * Start audio capture + speech recognition based on source type.
   */
  async start(videoType: VideoDataType, videoSrc: string): Promise<void> {
    this.sourceType = this.detectSourceType(videoType, videoSrc);
    const t0 = Date.now();
    console.info(`[字幕][DIAG] captureService启动 | sourceType=${this.sourceType} | url=${videoSrc.substring(0, 80)}`);

    switch (this.sourceType) {
      case AudioSourceType.LOCAL_FILE:
        console.info(`[字幕][DIAG] 路由到CoreSpeechKit (本地文件/批处理)`);
        await this.startBatchRecognition();
        break;

      case AudioSourceType.PLAYBACK_CAPTURE:
      default:
        console.info(`[字幕][DIAG] 路由到CoreSpeechKit (流式) + AudioPipeline (系统内录)`);
        await this.startStreamingRecognition();
        const totalElapsed = Date.now() - t0;
        console.info(`[字幕][DIAG] 全链路就绪 | 总耗时=${totalElapsed}ms`);
        break;
    }
  }

  // ─── Batch: local file ───

  private async startBatchRecognition(): Promise<void> {
    this.onStateChange?.('connecting', '正在初始化本地语音识别...');

    const config: CoreSpeechConfig = {
      language: 'zh-CN',
      online: 1,
      recognitionMode: 'long'
    };

    this.coreSpeechProvider = new CoreSpeechProvider(config);
    this.wireProviderCallbacks();

    try {
      await this.coreSpeechProvider.start(this.videoUrl, this.videoType!);
    } catch (error) {
      const err = error as Error;
      console.error(`[VideoAudioCapture] 批处理识别错误: ${err.message}`);
      this.onError?.(err.message);
    }
  }

  // ─── Streaming: network / playback capture ───

  private async startStreamingRecognition(): Promise<void> {
    // Step 1: Create and start CoreSpeechProvider (engine + listener)
    const config: CoreSpeechConfig = {
      language: 'zh-CN',
      online: 1,
      recognitionMode: 'long'
    };

    this.coreSpeechProvider = new CoreSpeechProvider(config);
    this.wireProviderCallbacks();

    try {
      await this.coreSpeechProvider.startStreaming();
      console.info(`[字幕][DIAG] CoreSpeech引擎就绪 | 开始AudioPipeline内录`);
    } catch (error) {
      const err = error as Error;
      console.error(`[字幕][DIAG] 引擎启动失败: ${err.message}`);
      this.onError?.(err.message);
      return;
    }

    // Step 2: Start AudioPipeline for system audio capture
    this.audioPipeline = new AudioPipeline();
    this.audioPipeline.onError = (err: string) => {
      console.error(`[字幕][DIAG] AudioPipeline错误: ${err}`);
      this.onError?.(err);
    };
    this.audioPipeline.onStateChange = (state: string) => {
      this.onStateChange?.('streaming', state);
    };

    // Wire PCM output → CoreSpeechProvider streaming input
    this.audioPipeline.setOnPcmChunk((pcmData: ArrayBuffer) => {
      if (this.coreSpeechProvider) {
        this.coreSpeechProvider.writeAudioChunk(pcmData);
      }
    }, 640);

    try {
      await this.audioPipeline.start(AudioPipelineSource.PLAYBACK_CAPTURE);
      console.info(`[字幕][DIAG] AudioPipeline已启动 | PCM→ASR桥接已建立`);
    } catch (error) {
      const err = error as Error;
      console.error(`[字幕][DIAG] AudioPipeline启动失败: ${err.message}`);
      this.onError?.(err.message);
    }
  }

  // ─── Callback wiring ───

  private wireProviderCallbacks(): void {
    if (!this.coreSpeechProvider) return;

    this.coreSpeechProvider.onResult = (result: CaptureResult) => {
      this.onResult?.(result);
    };
    this.coreSpeechProvider.onStateChange = (state: ASRState, message?: string) => {
      this.onStateChange?.(state, message);
    };
    this.coreSpeechProvider.onError = (error: string) => {
      console.error(`[VideoAudioCapture] CoreSpeech错误: ${error}`);
      this.onError?.(error);
    };
  }

  // ─── Lifecycle ───

  async stop(): Promise<void> {
    console.info(`[字幕][DIAG] captureService停止 | sourceType=${this.sourceType}`);

    if (this.coreSpeechProvider) {
      // Signal end of audio stream if streaming
      this.coreSpeechProvider.finishStreaming();
      this.coreSpeechProvider.stop();
      this.coreSpeechProvider = null;
    }

    if (this.audioPipeline) {
      await this.audioPipeline.release();
      this.audioPipeline = null;
    }

    console.info(`[字幕][DIAG] captureService已完全停止`);
  }

  get currentSourceType(): AudioSourceType {
    return this.sourceType;
  }
}
