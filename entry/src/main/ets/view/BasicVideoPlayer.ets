/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { display, window } from '@kit.ArkUI';
import { deviceInfo, emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { AvPlayerController } from '../controller/AvPlayerController';
import { VideoOperate } from '../components/VideoOperate';
import { ExitVideo } from '../components/ExitVideo';
import { ScaleDialog } from '../components/ScaleDialog';
import { TimeUtil } from '../common/utils/TimeUtils';
import { GlobalContext } from '../common/utils/GlobalContext';
import { CommonConstants } from '../common/constants/CommonConstants';
import { VideoData } from '../model/VideoData';
import { PiPWindowController } from '../controller/PipWindowController';
import { SetBrightness } from '../components/SetBirghness';
import { CaptionFont, SubtitleConstants, registerMyFont } from '../model/SubtitleConfig';
import { AiCaptionConstants, AiCaptionLangOption } from '../model/AiCaptionConfig';
import { VideoAudioCaptureService, AudioSourceType, CaptureResult, ASRState } from '../services/VideoAudioCaptureService';
import { BookmarkStore } from '../services/BookmarkStore';
import { AiCaptionDisplay } from '../components/AiCaptionDisplay';
import { BusinessError } from '@kit.BasicServicesKit';
import { KeyCode } from '@kit.InputKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BreakpointConstants } from '../common/constants/BreakpointConstants';

const SURFACE_WIDTH = 0.9; // Surface width ratio
const SURFACE_HEIGHT = 1.78; // Surface height ratio
const TIMEOUT = 0; // Timer ID
const SET_TIME_OUT = 8000; // Interval: 8s
const TAG = '[BasicVideoPlayer]';

@Component
export struct BasicVideoPlayer {
  @Consume('systemStatusAreaHeight') systemStatusAreaHeight: number;
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop videoData: VideoData;
  @State isSwiping: boolean = false;
  @State isClickScreen: boolean = false;
  @State @Watch('onIsFullScreenChange') isFullScreen: boolean = false;
  @StorageProp(BreakpointConstants.CURRENT_BREAKPOINT) currentBreakpoint: string =
    BreakpointConstants.BREAKPOINT_SM;
  @State surfaceW: number = 0;
  @State surfaceH: number = 0;
  @State volume: number = 100; // 0-100
  @State show: boolean = false; // Indicates whether the videoPanel component is displayed.
  @State percent: number = 0;
  @State windowWidth: number = 300;
  @State windowHeight: number = 300;
  @State isCalcWHFinished: boolean = false;
  @State brightnessVisible: boolean = false; //whether to show slider/image
  @State screenBrightness: number = 0; //screen luminance
  @State isShowCaptionConfig: boolean = false; //whether to show caption settings
  @State isChangingSubtitlePosition: boolean = false; // subtitle position drag mode
  @State captionFont: CaptionFont = SubtitleConstants.DEFAULT_CAPTION_FONT;
  @State showPlaybackError: boolean = false;
  @State playbackErrorMessage: string = '';
  @State showMoreMenu: boolean = false;
  @State isWindowFullScreen: boolean = false;
  @State isBookmarked: boolean = false;
  @State windowScaleSelect: number = 0;

  // AI Caption states
  @State isAiCaptionShown: boolean = false;
  @State aiSourceLang: string = AiCaptionConstants.SOURCE_LANG_ZH;
  @State aiTargetLang: string = AiCaptionConstants.TARGET_LANG_ZH;
  @State aiCaptionOpacity: number = 0.8;
  @State aiCaptionNoResult: boolean = false; // show 'unable to recognize' fallback
  @State aiCaptionText: string = '';         // final recognized text
  @State aiCaptionInterimText: string = '';  // interim recognized text
  @State aiCaptionStatusText: string = '';   // status: connecting, listening, error
  @State asrState: ASRState = 'idle';
  @StorageLink('currentLanguageType') currentLanguageType: number = 0;

  // Subtitle position state (relative position: 0-1)
  @State subtitleRelX: number = 0.5;
  @State subtitleRelY: number = 0.85;
  @State isDraggingSubtitle: boolean = false;

  private screenHeight: number = 0; //screen height
  private get isPhone(): boolean {
    return this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM;
  }
  @Link avPlayerController: AvPlayerController;
  private uiAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private windowClass = this.uiAbilityContext.windowStage.getMainWindowSync();
  private surfaceId: string = '';
  private timeout: number = 0; // Timer ID
  private xComponentController: XComponentController = new XComponentController();
  private pipWindowController: PiPWindowController =
    new PiPWindowController(this.avPlayerController, this.xComponentController); //the instance of picture in picture
  private pipScaleDialogController: CustomDialogController = new CustomDialogController({
    builder: ScaleDialog({
      windowScaleSelect: $windowScaleSelect,
      onSelect: (): void => {
        this.startPiP();
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });
  private captureService: VideoAudioCaptureService = new VideoAudioCaptureService();
  private bookmarkStore: BookmarkStore = BookmarkStore.getInstance();

  onIsFullScreenChange() {
    if (this.isFullScreen) {
      this.screenHeight = this.windowClass.getWindowProperties().windowRect.width;
    } else {
      this.screenHeight = this.windowClass.getWindowProperties().windowRect.height;
    }
  }

  // Immersive fullscreen toggle for PC/tablet (window-level, independent of UI orientation state)
  toggleWindowFullScreen(): void {
    this.isWindowFullScreen = !this.isWindowFullScreen;
    try {
      this.windowClass.setWindowLayoutFullScreen(this.isWindowFullScreen, (err) => {
        if (err.code) {
          hilog.error(CommonConstants.LOG_DOMAIN, TAG,
            `setWindowLayoutFullScreen failed, code: ${err.code}, message: ${err.message}`);
          this.isWindowFullScreen = !this.isWindowFullScreen;
        }
      });
    } catch (err) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG,
        `setWindowLayoutFullScreen exception: ${JSON.stringify(err)}`);
      this.isWindowFullScreen = !this.isWindowFullScreen;
    }
  }

  setTimer(): void {
    let that = this;
    this.timeout = setTimeout(() => {
      that.isClickScreen = false; // Hide the operation panel
    }, SET_TIME_OUT); // Hide in 8 seconds
  }

  clearTimer(): void {
    if (this.timeout !== TIMEOUT) {
      clearTimeout(this.timeout);
      this.timeout = TIMEOUT;
    }
  }

  aboutToAppear() {
    // AI字幕使用华为云ASR: 模拟器和真机均可使用, 不受SystemCapability限制
    console.info('🔍 [字幕] 华为云ASR服务 | 设备:', deviceInfo.deviceType, '| API:', deviceInfo.sdkApiVersion);

    if (!this.isPhone) {
      const windowRect = this.windowClass.getWindowProperties().windowRect;
      this.windowWidth = windowRect.width;
      this.windowHeight = windowRect.height;
    } else {
      this.windowWidth = display.getDefaultDisplaySync().width;
      this.windowHeight = display.getDefaultDisplaySync().height;
    }
    this.surfaceW = this.windowWidth * SURFACE_WIDTH;
    this.surfaceH = this.surfaceW / SURFACE_HEIGHT;
    this.avPlayerController.isPlaying = true;

    this.screenHeight = this.windowClass.getWindowProperties().windowRect.height;

    AppStorage.setOrCreate('windowClass', this.windowClass);

    registerMyFont(this.getUIContext());

    this.captionFont = this.avPlayerController.captionFont;

    // Ensure AppStorage speed defaults are set (prevents 0.5X vs 1.0X mismatch)
    AppStorage.setOrCreate('speedName', $r('app.string.video_speed_1_0X'));
    AppStorage.setOrCreate('speedIndex', 2);

    // Initialize AI Caption (Huawei Cloud ASR)
    this.initAiCaption();

    // Initialize bookmark check
    this.initBookmark();

    // Restore saved subtitle position
    let savedX = AppStorage.get<number>('subtitleRelX');
    let savedY = AppStorage.get<number>('subtitleRelY');
    if (savedX !== undefined) this.subtitleRelX = savedX;
    if (savedY !== undefined) this.subtitleRelY = savedY;

    // PC/tablet: always landscape, no orientation switching
    if (!this.isPhone) {
      this.isFullScreen = true;
    }

    // listen rotation (phone only)
    display.on('change', async () => {
      if (!this.isPhone) {
        return;
      }
      let rotation = await display.getDefaultDisplaySync().rotation;
      if (rotation === 0 || rotation === 2) {
        this.isFullScreen = false;
      } else {
        this.isFullScreen = true;
      }

    });

    // 監聽摺疊屏顯示模式變化（摺疊/展開）
    try {
      display.on('foldDisplayModeChange', (mode: display.FoldDisplayMode) => {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `FoldDisplayMode changed: ${mode}`);
        // 摺疊狀態變化後重新計算視頻尺寸
        this.windowWidth = display.getDefaultDisplaySync().width;
        this.windowHeight = display.getDefaultDisplaySync().height;
        this.setVideoWH();
      });
    } catch (err) {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `foldDisplayModeChange not supported, code: ${(err as BusinessError).code}`);
    }

    emitter.on(CommonConstants.AVPLAYER_PREPARED, (res) => {
      if (res.data) {
        this.percent = res.data.percent;
        this.setVideoWH();
        this.isCalcWHFinished = true;
        // 横屏视频自动全屏播放
        if (this.percent >= 1) {
          this.isFullScreen = true;
        }
      }
    });
    emitter.on(CommonConstants.innerEventTrue, (res) => {
      if (res.data) {
        this.avPlayerController.isPlaying = res.data.flag;
      }
    });
    emitter.on(CommonConstants.innerEventFalse, (res) => {
      if (res.data) {
        this.avPlayerController.isPlaying = res.data.flag;
      }
    });
    emitter.on(CommonConstants.innerEventWH, (res) => {
      if (res.data) {
        this.windowWidth = res.data.width;
        this.windowHeight = res.data.height;
        this.setVideoWH();
      }
    });
    if (!this.avPlayerController.isPlaying) {
      this.clearTimer();
    }

    this.pipWindowController.createPipController();

    emitter.on(CommonConstants.AVPLAYER_ERROR, (res) => {
      if (res.data) {
        this.showPlaybackError = true;
        let dataObj = res.data as object;
        this.playbackErrorMessage = dataObj['message'] as string || '该链接无法播放';
      }
    });
  }

  aboutToDisappear() {
    this.avPlayerController.videoRelease();
    emitter.off(CommonConstants.innerEventFalse.eventId);
    emitter.off(CommonConstants.innerEventTrue.eventId);
    emitter.off(CommonConstants.innerEventFalse.eventId);
    emitter.off(CommonConstants.innerEventWH.eventId);
    emitter.off(CommonConstants.AVPLAYER_ERROR.eventId);

    display.off('change');
    display.off('foldDisplayModeChange');

    // Restore auto-rotation when leaving player to prevent rotation lock on tablets
    this.windowClass.setPreferredOrientation(window.Orientation.AUTO_ROTATION).catch((err: BusinessError) => {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `aboutToDisappear setPreferredOrientation failed, code is ${err.code}, message is ${err.message}`);
    });

    // Restore window layout if immersive fullscreen was active
    if (this.isWindowFullScreen) {
      this.isWindowFullScreen = false;
      this.windowClass.setWindowLayoutFullScreen(false).catch((err: BusinessError) => {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `aboutToDisappear restore windowLayout failed, code is ${err.code}`);
      });
    }

    this.pipWindowController.destroyPipController();

    // Release AI Caption resources
    this.captureService.stop();
  }

  onPageHide() {
    this.avPlayerController.videoPause();
  }

  setVideoWH(): void {
    if (this.percent >= 1) { // Horizontal video
      this.surfaceW = Math.round(this.windowWidth);
      this.surfaceH = Math.round(this.surfaceW / this.percent);
    } else { // Vertical video
      this.surfaceH = Math.round(this.windowHeight);
      this.surfaceW = Math.round(this.surfaceH * this.percent);
    }
  }

  openCaptionSettings(): void {
    this.isShowCaptionConfig = true;
  }

  startPiP(): void {
    this.pipWindowController.pipController?.startPiP();
  }

  initAiCaption(): void {
    // AI字幕使用 HarmonyOS CoreSpeechKit 本地引擎
    // 具体引擎 + 采集由 captureService 内部路由
    console.info('[字幕][DIAG] AI字幕初始化 | CoreSpeechKit模式');
  }

  async initBookmark(): Promise<void> {
    try {
      await this.bookmarkStore.init(this.uiAbilityContext);
      this.isBookmarked = this.bookmarkStore.isBookmarked(this.videoData.videoSrc);
    } catch (e) {
      console.error(`[Bookmark] init失败: ${JSON.stringify(e)}`);
    }
  }

  async shareVideo(): Promise<void> {
    try {
      let shareTitle = typeof this.videoData.name === 'string'
        ? this.videoData.name as string
        : this.videoData.videoSrc.substring(0, 50);
      let shareData: systemShare.SharedData;
      if (this.videoData.type === 1 || this.videoData.type === 4) {
        // 本地视频：分享文件uri
        let fd = await this.uiAbilityContext.resourceManager.getRawFd(this.videoData.videoSrc);
        let filePath = this.uiAbilityContext.filesDir + '/' + shareTitle;
        shareData = new systemShare.SharedData({
          utd: utd.UniformDataType.VIDEO,
          title: shareTitle
        });
      } else {
        // 网络视频：分享链接
        shareData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: this.videoData.videoSrc,
          title: shareTitle,
          description: '来自ikun播放器的分享'
        });
      }
      let controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      controller.show(this.uiAbilityContext, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
    } catch (e) {
      console.error(`[分享] 失败: ${JSON.stringify(e)}`);
      this.getUIContext().getPromptAction().showToast({ message: '分享失败', duration: 1500 });
    }
  }

  async toggleBookmark(): Promise<void> {
    const title = typeof this.videoData.name === 'string'
      ? this.videoData.name as string
      : this.videoData.videoSrc.substring(0, 50);
    try {
      this.isBookmarked = await this.bookmarkStore.toggle(
        this.videoData.videoSrc,
        title,
        this.videoData.type,
        '' // thumbnail path - placeholder, real capture needs AVImageGenerator
      );
      const msg = this.isBookmarked ? '已收藏' : '已取消收藏';
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      console.error(`[Bookmark] toggle失败: ${JSON.stringify(e)}`);
    }
  }

  async toggleAiCaption(): Promise<void> {
    this.isAiCaptionShown = !this.isAiCaptionShown;
    const t0 = Date.now();

    if (this.isAiCaptionShown) {
      console.info(`[字幕][DIAG] ═══ AI字幕 开启 ═══ | videoType=${this.videoData.type} | videoSrc=${this.videoData.videoSrc.substring(0, 80)}`);

      // Reset state
      this.aiCaptionText = '';
      this.aiCaptionInterimText = '';
      this.aiCaptionNoResult = false;
      this.aiCaptionStatusText = '';

      // Auto-detect video source type
      const sourceType = this.captureService.detectSourceType(
        this.videoData.type, this.videoData.videoSrc);

      console.info(`[字幕] 视频源检测: 类型=${this.videoData.type}, 源类型=${sourceType}`);

      // Wire capture result callbacks (always set these before starting)
      this.captureService.onResult = (result: CaptureResult) => {
        if (result.isFinal) {
          this.aiCaptionText = result.text;
          this.aiCaptionInterimText = '';
          this.aiCaptionNoResult = false;
          this.aiCaptionStatusText = '';
        } else {
          this.aiCaptionInterimText = result.text;
        }
      };

      this.captureService.onStateChange = (state: ASRState, msg?: string) => {
        this.asrState = state;
        console.info(`[字幕] 状态变更: ${state}${msg ? ', ' + msg : ''}`);
        if (state === 'connected' || state === 'streaming') {
          this.aiCaptionStatusText = msg ?? '聆听中...';
        } else if (state === 'connecting') {
          this.aiCaptionStatusText = msg ?? '正在初始化...';
        } else if (state === 'error') {
          this.aiCaptionStatusText = msg ?? '服务异常';
          this.aiCaptionNoResult = true;
        } else if (state === 'closed') {
          this.aiCaptionStatusText = '连接已断开';
        }
      };

      this.captureService.onError = (error: string) => {
        console.error(`[字幕] 错误: ${error}`);
        this.aiCaptionStatusText = `错误: ${error}`;
        this.aiCaptionNoResult = true;
      };

      if (sourceType === AudioSourceType.LOCAL_FILE) {
        // Local file: CoreSpeechKit batch mode
        console.info(`[字幕][DIAG] 本地文件路径 | 使用CoreSpeechKit批处理`);
        this.aiCaptionStatusText = '检测到本地视频，正在启动语音识别...';
        try {
          await this.captureService.start(this.videoData.type, this.videoData.videoSrc);
        } catch (error) {
          const err = error as BusinessError;
          console.error(`[字幕] 本地识别启动失败: ${err.message}`);
          this.aiCaptionStatusText = `启动失败: ${err.message}`;
          this.aiCaptionNoResult = true;
        }
      } else {
        // Network / streaming: CoreSpeechKit streaming + AudioPipeline
        console.info(`[字幕][DIAG] 网络源 | CoreSpeechKit流式 + AudioPipeline内录`);
        this.aiCaptionStatusText = '正在初始化语音识别...';

        try {
          await this.captureService.start(this.videoData.type, this.videoData.videoSrc);
          console.info(`[字幕][DIAG] AI字幕全链路就绪`);
        } catch (error) {
          const err = error as BusinessError;
          const totalElapsed = Date.now() - t0;
          console.error(`[字幕][DIAG] AI字幕启动失败 | 总耗时=${totalElapsed}ms | error="${err.message}"`);
          this.aiCaptionStatusText = `启动失败: ${err.message}`;
          this.aiCaptionNoResult = true;
        }
      }

      console.info(`[字幕] AI字幕已启动 (源: ${sourceType})`);
    } else {
      console.info(`[字幕][DIAG] ═══ AI字幕 关闭 ═══`);
      // Stop all capture services
      this.captureService.stop();

      this.aiCaptionText = '';
      this.aiCaptionInterimText = '';
      this.aiCaptionStatusText = '';
      this.aiCaptionNoResult = false;
    }
  }

  onAiSourceLangChange(value: string): void {
    this.aiSourceLang = value;
    if (value === AiCaptionConstants.SOURCE_LANG_ZH) {
      this.aiTargetLang = AiCaptionConstants.TARGET_LANG_ZH;
    } else {
      this.aiTargetLang = AiCaptionConstants.TARGET_LANG_EN;
    }
  }

  onAiTargetLangChange(value: string): void {
    this.aiTargetLang = value;
  }

  getTargetLangOptions(): AiCaptionLangOption[] {
    if (this.aiSourceLang === AiCaptionConstants.SOURCE_LANG_ZH) {
      return AiCaptionConstants.TARGET_LANG_OPTIONS_ZH;
    }
    return AiCaptionConstants.TARGET_LANG_OPTIONS_EN;
  }

  @BuilderParam
  progressBuilder?: () => void;

  @Builder
  UnifiedCaptionDialog() {
    Column() {
      Scroll() {
      Column() {
        // Header
        Row() {
          Text($r('app.string.subtitle_settings_title'))
            .fontSize(18).fontWeight(700).fontColor(Color.White)
          Blank()
          Row({ space: 16 }) {
            Image($r('app.media.ic_subtitle_close')).width(22).height(22).fillColor(Color.White)
              .onClick(() => { this.isShowCaptionConfig = false; })
            Image($r('app.media.ic_subtitle_check')).width(22).height(22).fillColor(Color.White)
              .onClick(() => {
                this.avPlayerController.captionFont = this.captionFont;
                this.isShowCaptionConfig = false;
              })
          }
        }
        .width('100%').margin({ bottom: 16 })

        // --- Traditional Subtitle Settings ---
        if (this.avPlayerController.hasCaption) {
          // Language switch
          Row() {
            Text($r('app.string.language_switch')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Row({ space: 12 }) {
              Button($r('app.string.Chinese')).fontSize(14)
                .fontColor(this.currentLanguageType === 0 ? Color.Black : Color.White)
                .backgroundColor(this.currentLanguageType === 0 ?
                'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                .borderRadius(20).padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => { this.avPlayerController.languageChange(0); })
              Button($r('app.string.English')).fontSize(14)
                .fontColor(this.currentLanguageType === 1 ? Color.Black : Color.White)
                .backgroundColor(this.currentLanguageType === 1 ?
                'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                .borderRadius(20).padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => { this.avPlayerController.languageChange(1); })
            }
          }
          .width('100%').padding({ top: 4, bottom: 10 }).justifyContent(FlexAlign.SpaceBetween)

          Divider().color('rgba(255,255,255,0.2)')

          // Font family
          Row({ space: 20 }) {
            Text($r('app.string.subtitle_font')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Row({ space: 12 }) {
              ForEach(SubtitleConstants.CAPTION_FONT_FAMILY,
                (family: ResourceStr, index: number) => {
                  Button(family).fontSize(16)
                    .fontColor(this.captionFont.family === family ? Color.Black : Color.White)
                    .backgroundColor(this.captionFont.family === family ?
                    'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                    .borderRadius(20).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .onClick(() => { this.captionFont.family = family; })
                }, (family: ResourceStr, index: number) => `${family}_${index}`)
            }
          }
          .width('100%').padding({ top: 14, bottom: 14 }).justifyContent(FlexAlign.SpaceBetween)

          Divider().color('rgba(255,255,255,0.2)')

          // Font size
          Column() {
            Row() {
              Text($r('app.string.subtitle_font_size')).fontColor(Color.White).fontSize(16).fontWeight(500)
              Text(`${this.captionFont.size}`).fontColor('rgba(255, 255, 255, 0.6)').fontSize(14)
            }
            .width('100%').justifyContent(FlexAlign.SpaceBetween)
            Slider({
              value: this.captionFont.size,
              min: SubtitleConstants.CAPTION_FONT_SIZE_MIN,
              max: SubtitleConstants.CAPTION_FONT_SIZE_MAX,
              step: 1, style: SliderStyle.InSet
            })
              .trackThickness(20).blockSize({ width: 14, height: 14 })
              .trackColor('rgba(255, 255, 255, 0.4)').selectedColor(Color.White)
              .onChange((value: number) => { this.captionFont.size = value; })
          }
          .width('100%').margin({ top: 14, bottom: 4 })

          Divider().color('rgba(255,255,255,0.2)')

          // Font color
          Row() {
            Text($r('app.string.subtitle_font_color')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
              ForEach(SubtitleConstants.CAPTION_FONT_COLOR,
                (color: ResourceColor, index: number) => {
                  Column() {
                    if (this.captionFont.color === color) {
                      Column() {}.width(12).height(12).borderRadius('50%')
                        .border({ width: 1, color: 'rgb(241,243,245)' })
                    }
                  }
                  .width(28).height(28).borderRadius('50%').backgroundColor(color)
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => { this.captionFont.color = color; })
                }, (color: ResourceColor, index: number) => `${color}_${index}`)
            }
            .width('60%')
          }
          .width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 14 })

          Divider().color('rgba(255,255,255,0.2)')

          // Change position
          Row() {
            Button($r('app.string.subtitle_change_position'))
              .fontSize(14).fontColor(Color.White)
              .backgroundColor('rgba(255,255,255,0.15)').borderRadius(20)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .onClick(() => {
                this.isShowCaptionConfig = false;
                this.isChangingSubtitlePosition = true;
              })
          }
          .width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })
        } else {
          Column() {
            Text($r('app.string.subtitle_not_available_title'))
              .fontSize(18).fontWeight(600).fontColor(Color.White).margin({ bottom: 12 })
            Text($r('app.string.subtitle_not_available_desc'))
              .fontSize(14).fontColor('rgba(255, 255, 255, 0.6)')
              .textAlign(TextAlign.Center).width('100%')
          }
          .width('100%').padding({ top: 20, bottom: 10 }).alignItems(HorizontalAlign.Center)
        }

        // --- AI Caption Section ---
        Divider().color('rgba(255,255,255,0.3)').margin({ top: 10, bottom: 16 })

        Text('AI 实时字幕').fontSize(16).fontWeight(600).fontColor(Color.White)
          .width('100%').margin({ bottom: 12 })

        // AI Toggle
        Row() {
          Text('开启AI实时字幕').fontSize(14).fontColor('rgba(255, 255, 255, 0.85)')
          Toggle({ type: ToggleType.Switch, isOn: this.isAiCaptionShown })
            .onChange((isOn: boolean) => {
              if (isOn !== this.isAiCaptionShown) {
                this.toggleAiCaption();
              }
            })
        }
        .width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 12 })

        if (this.isAiCaptionShown) {
          // Source language
          Text('源语言').fontSize(13).fontColor('rgba(255, 255, 255, 0.6)')
            .width('100%').margin({ bottom: 6 })
          Row({ space: 8 }) {
            ForEach(AiCaptionConstants.SOURCE_LANG_OPTIONS,
              (option: AiCaptionLangOption) => {
                Button(option.label).fontSize(13)
                  .fontColor(this.aiSourceLang === option.value ? Color.Black : Color.White)
                  .backgroundColor(this.aiSourceLang === option.value ?
                  'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.15)')
                  .borderRadius(16).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .onClick(() => { this.onAiSourceLangChange(option.value); })
              }, (option: AiCaptionLangOption) => `src_${option.value}`)
          }
          .width('100%').margin({ bottom: 10 })

          // Target language
          Text('目标语言').fontSize(13).fontColor('rgba(255, 255, 255, 0.6)')
            .width('100%').margin({ bottom: 6 })
          Row({ space: 8 }) {
            ForEach(this.getTargetLangOptions(),
              (option: AiCaptionLangOption) => {
                Button(option.label).fontSize(13)
                  .fontColor(this.aiTargetLang === option.value ? Color.Black : Color.White)
                  .backgroundColor(this.aiTargetLang === option.value ?
                  'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.15)')
                  .borderRadius(16).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .onClick(() => { this.onAiTargetLangChange(option.value); })
              }, (option: AiCaptionLangOption) => `tgt_${option.value}`)
          }
          .width('100%').margin({ bottom: 8 })

          Text('AI字幕通过华为云语音识别自动生成实时字幕，支持中英文。请先在AiCaptionConfig中配置华为云AK/SK。')
            .fontSize(11).fontColor('rgba(255, 255, 255, 0.4)').width('100%')
        }
      }
      .width('100%').backgroundColor('#1A1A1A').borderRadius(16)
      .padding({ top: 24, left: 20, right: 20, bottom: 28 })
      .onClick(() => { /* prevent propagation */ })
      }
      .width('85%').constraintSize({ maxHeight: '75%' }).scrollBar(BarState.Auto)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(0, 0, 0, 0.6)')
    .onClick(() => {
      this.avPlayerController.captionFont = this.captionFont;
      this.isShowCaptionConfig = false;
    })
  }

  @Builder
  MoreMenuBuilder() {
    Column() {
      Column() {
        Text('更多功能')
          .fontSize(18)
          .fontWeight(700)
          .fontColor(Color.White)
          .margin({ bottom: 16 })
          .width('100%')
          .textAlign(TextAlign.Center)

        Row() {
          Text('收藏')
            .fontSize(16)
            .fontColor(Color.White)
          Blank()
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.toggleBookmark();
          this.showMoreMenu = false;
        })

        Divider().color('rgba(255,255,255,0.2)')

        Row() {
          Text('分享')
            .fontSize(16)
            .fontColor(Color.White)
          Blank()
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.showMoreMenu = false;
          this.shareVideo();
        })

        Divider().color('rgba(255,255,255,0.2)')

        Row() {
          Text('下载')
            .fontSize(16)
            .fontColor(Color.White)
          Blank()
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.showMoreMenu = false;
        })

        Divider().color('rgba(255,255,255,0.2)')

        Row() {
          Text('举报')
            .fontSize(16)
            .fontColor(Color.White)
          Blank()
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.showMoreMenu = false;
        })

        Divider().color('rgba(255,255,255,0.2)')

        Button('关闭')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('rgba(255,255,255,0.15)')
          .borderRadius(20)
          .padding({ left: 24, right: 24, top: 8, bottom: 8 })
          .margin({ top: 12 })
          .onClick(() => {
            this.showMoreMenu = false;
          })
      }
      .width('75%')
      .backgroundColor('#1A1A1A')
      .borderRadius(16)
      .padding({ top: 24, left: 20, right: 20, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(0, 0, 0, 0.6)')
    .onClick(() => {
      this.showMoreMenu = false;
    })
  }

  @Builder
  CoverXComponent() {
    XComponent({
      id: 'xComponent',
      type: XComponentType.SURFACE,
      controller: this.xComponentController
    })
      .onLoad(() => {
        this.surfaceId = this.xComponentController.getXComponentSurfaceId();
        this.avPlayerController.initAVPlayer(this.videoData, this.surfaceId);
      })
      .height(this.isCalcWHFinished ? `${this.surfaceH}px` : '100%')
      .width(this.isCalcWHFinished ? `${this.surfaceW}px` : '100%')
  }

  build() {
    Stack() {

      Column() {
        this.CoverXComponent()
      }
      .align(Alignment.TopStart)
      .margin({ top: $r('app.float.size_80') })
      .id('Video')
      .justifyContent(FlexAlign.Center)

      if (this.isFullScreen) {
        SetBrightness({ screenBrightness: this.screenBrightness, visible: this.brightnessVisible })
          .width('100%').height('100%')
      }

      Text()
        .height(`${this.surfaceH}px`)
        .width(`${this.surfaceW}px`)
        .margin({ top: $r('app.float.size_80') })
        .backgroundColor(Color.Black)
        .opacity($r('app.float.size_zero_five'))
        .visibility(this.isSwiping ? Visibility.Visible : Visibility.Hidden)

      Row() {
        Text(TimeUtil.millisecondsToTime(this.avPlayerController.currentTime))
          .fontSize($r('app.float.size_24'))
          .opacity($r('app.float.size_1'))
          .fontColor($r('app.color.slider_selected'))
        Text('/' + TimeUtil.millisecondsToTime(this.avPlayerController.durationTime))
          .fontSize($r('app.float.size_24'))
          .opacity($r('app.float.size_1'))
          .fontColor(Color.White)
      }
      .margin({ top: $r('app.float.size_80') })
      .visibility(this.isSwiping ? Visibility.Visible : Visibility.Hidden)

      Column() {
        if (this.isClickScreen) {
          Row() {
            ExitVideo({ videoName: this.videoData.name, isFullScreen: this.isFullScreen })
              .layoutWeight(1)
            Row({ space: 12 }) {
              // 字幕功能 (Subtitle/Caption settings)
              Image($r('app.media.ic_subtitle_setting'))
                .width($r('app.float.size_25'))
                .height($r('app.float.size_25'))
                .onClick(() => {
                  this.openCaptionSettings();
                })

              // 小窗功能 (Picture-in-Picture: select scale then start PiP)
              Image($r('app.media.ic_video_window_scale'))
                .width($r('app.float.size_25'))
                .height($r('app.float.size_25'))
                .onClick(() => {
                  this.pipScaleDialogController.open();
                })

              // 更多功能 (More menu)
              Text('≡')
                .fontSize(22)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
                .onClick(() => {
                  this.showMoreMenu = true;
                })
            }
            .margin({ right: $r('app.float.size_25') })
          }
          .padding({ top: `${this.systemStatusAreaHeight}px` })
          .width('100%')
        }

        Blank()
        // Subtitle display with drag-to-move support (hidden when AI captions are active)
        if (!this.isAiCaptionShown) {
        Column() {
          Text(this.avPlayerController.currentCaption || '')
            .fontColor(this.captionFont.color)
            .fontSize(this.captionFont.size)
            .fontFamily(this.captionFont.family)
            .textAlign(TextAlign.Center)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(this.avPlayerController.currentCaption ? 'rgba(0, 0, 0, 0.5)' : Color.Transparent)
            .border({
              width: (this.isDraggingSubtitle || this.isChangingSubtitlePosition) ? 2 : 0,
              color: Color.Red
            })
        }
        .width('100%')
        .margin({ bottom: 20 })
        .position({
          x: `${this.subtitleRelX * 100}%`,
          y: `${this.subtitleRelY * 100}%`
        })
        .translate({
          x: '-50%',
          y: '-50%'
        })
        .gesture(
          PanGesture({ direction: PanDirection.All })
            .onActionStart(() => {
              this.isDraggingSubtitle = true;
            })
            .onActionUpdate((event: GestureEvent) => {
              let newX = this.subtitleRelX + this.getUIContext().px2vp(event.offsetX) / this.windowWidth;
              let newY = this.subtitleRelY + this.getUIContext().px2vp(event.offsetY) / this.windowHeight;
              // Clamp within screen bounds (0.05 - 0.95 for safety)
              this.subtitleRelX = Math.max(0.05, Math.min(0.95, newX));
              this.subtitleRelY = Math.max(0.05, Math.min(0.95, newY));
            })
            .onActionEnd(() => {
              this.isDraggingSubtitle = false;
              // Save position
              AppStorage.setOrCreate('subtitleRelX', this.subtitleRelX);
              AppStorage.setOrCreate('subtitleRelY', this.subtitleRelY);
            })
        )
        }

        // AI Caption display - uses Huawei Cloud ASR (works on emulator and real device)
        AiCaptionDisplay({
          captionText: this.aiCaptionText,
          interimText: this.aiCaptionInterimText,
          statusText: this.aiCaptionStatusText,
          isVisible: this.isAiCaptionShown,
          positionY: this.subtitleRelY,
          fontSize: this.captionFont.size,
          fontColor: this.captionFont.color
        })

        // Position mode done button - enlarged hit area
        if (this.isChangingSubtitlePosition) {
          Row() {
            Button($r('app.string.subtitle_position_done'))
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor('rgba(0, 150, 255, 0.9)')
              .borderRadius(24)
              .padding({ left: 32, right: 32, top: 14, bottom: 14 })
              .hitTestBehavior(HitTestMode.Default)
              .onClick(() => {
                this.isChangingSubtitlePosition = false;
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .position({ x: '50%', y: '92%' })
          .translate({ x: '-50%', y: '0' })
        }

        if (this.isClickScreen && !this.isChangingSubtitlePosition) {
          Column() {
            // Progress bar
            if (this.progressBuilder) {
              VideoOperate({
                avPlayerController: this.avPlayerController,
                isSwiping: this.isSwiping,
                isFullScreen: this.isFullScreen,
                isWindowFullScreen: this.isWindowFullScreen,
                onWindowFullScreenToggle: this.toggleWindowFullScreen,
                progressBuilder: this.progressBuilder,
                volumePercent: this.volume,
                onVolumeChange: (value: number) => {
                  this.volume = value;
                  this.avPlayerController.setPlayerVolume(value);
                }
              })
                .width('100%')
            } else {
              VideoOperate({
                avPlayerController: this.avPlayerController,
                isSwiping: this.isSwiping,
                isFullScreen: this.isFullScreen,
                isWindowFullScreen: this.isWindowFullScreen,
                onWindowFullScreenToggle: this.toggleWindowFullScreen,
                volumePercent: this.volume,
                onVolumeChange: (value: number) => {
                  this.volume = value;
                  this.avPlayerController.setPlayerVolume(value);
                }
              })
                .width('100%')
            }

          }
          .justifyContent(FlexAlign.Center)
        }
      }
      .onTouch((event: TouchEvent) => {
        if (event.type == TouchType.Down || event.type == TouchType.Move) {
          this.isClickScreen = true;
          this.clearTimer();
        } else if (event.type == TouchType.Up) {
          this.setTimer();
        }
      })
      .height('100%')
      .width('100%')

      // Unified caption settings dialog (includes traditional subtitles + AI caption)
      if (this.isShowCaptionConfig) {
        this.UnifiedCaptionDialog()
      }

      if (this.showMoreMenu) {
        this.MoreMenuBuilder()
      }

      if (this.showPlaybackError) {
        Column() {
          Text(this.playbackErrorMessage)
            .fontSize(20)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 24 })

          Button($r('app.string.video_playback_error_back'))
            .backgroundColor('#ffffff')
            .fontColor('#333333')
            .fontSize(16)
            .borderRadius(20)
            .padding({ left: 32, right: 32, top: 10, bottom: 10 })
            .onClick(() => {
              this.showPlaybackError = false;
              this.avPlayerController.playbackError = false;
              this.avPlayerController.errorMessage = '';
              this.avPlayerController.videoRelease();
              this.pageStack.pop();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.92)')
        .zIndex(100)
      }
    }
    .gesture(
      //sliding in the vertical direction
      PanGesture({ direction: PanDirection.Vertical })
        .onActionStart(() => {
        })
        .onActionUpdate((event: GestureEvent) => {
          //the area on the right side of the screen
          if (event.fingerList[0].globalX > (820 / 2)) {
            this.brightnessVisible = true;
            let curBrightness = this.screenBrightness -
              this.getUIContext().vp2px(event.offsetY) / this.screenHeight;
            curBrightness = curBrightness >= 1.0 ? 1.0 : curBrightness;
            curBrightness = curBrightness <= 0.0 ? 0.0 : curBrightness;
            this.screenBrightness = curBrightness;
            hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'this brightness is: ' + this.screenBrightness);

          } else {
            this.brightnessVisible = false;
            let curVolume = this.volume - this.getUIContext().vp2px(event.offsetY) / this.screenHeight * 70;
            curVolume = curVolume >= 100 ? 100 : curVolume;
            curVolume = curVolume <= 0 ? 0 : curVolume;
            this.volume = curVolume;
            this.avPlayerController.setPlayerVolume(curVolume);
            AppStorage.setOrCreate('isMuted', curVolume === 0);
            hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'this volume is: ' + this.volume);
          }
        })
        .onActionEnd(() => {
          setTimeout(() => {
            this.brightnessVisible = false;
          }, 3000)
        })
    )

    .gesture(
      LongPressGesture({ repeat: true })
        .onAction(() => {
          this.avPlayerController.videoSpeedTwo();
          AppStorage.setOrCreate('speedName', $r('app.string.video_speed_2_0X'));
          AppStorage.setOrCreate('speedIndex', 5);
        })
        .onActionEnd(() => {
          this.avPlayerController.videoSpeedOne();
          AppStorage.setOrCreate('speedName', $r('app.string.video_speed_1_0X'));
          AppStorage.setOrCreate('speedIndex', 2);
        })
    )
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (!event || event.type !== KeyType.Down) {
        return;
      }
      // Space / K: Play/Pause
      if (event.keyCode === KeyCode.KEYCODE_SPACE || event.keyCode === KeyCode.KEYCODE_K) {
        if (this.avPlayerController.isPlaying) {
          this.avPlayerController.videoPause();
        } else {
          this.avPlayerController.videoPlay();
        }
        return;
      }
      // Left arrow: Rewind 5s
      if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
        let newTime = this.avPlayerController.currentTime - 5 * CommonConstants.SECOND_TO_MS;
        this.avPlayerController.videoSeek(newTime > 0 ? newTime : 0);
        return;
      }
      // Right arrow: Forward 5s
      if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
        let newTime = this.avPlayerController.currentTime + 5 * CommonConstants.SECOND_TO_MS;
        this.avPlayerController.videoSeek(newTime);
        return;
      }
      // J: Rewind 10s
      if (event.keyCode === KeyCode.KEYCODE_J) {
        let newTime = this.avPlayerController.currentTime - 10 * CommonConstants.SECOND_TO_MS;
        this.avPlayerController.videoSeek(newTime > 0 ? newTime : 0);
        return;
      }
      // L: Forward 10s
      if (event.keyCode === KeyCode.KEYCODE_L) {
        let newTime = this.avPlayerController.currentTime + 10 * CommonConstants.SECOND_TO_MS;
        this.avPlayerController.videoSeek(newTime);
        return;
      }
      // Up arrow: Volume up
      if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) {
        let curVolume = this.volume + 5;
        curVolume = curVolume >= 100 ? 100 : curVolume;
        this.volume = curVolume;
        this.avPlayerController.setPlayerVolume(curVolume);
        return;
      }
      // Down arrow: Volume down
      if (event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        let curVolume = this.volume - 5;
        curVolume = curVolume <= 0 ? 0 : curVolume;
        this.volume = curVolume;
        this.avPlayerController.setPlayerVolume(curVolume);
        return;
      }
      // F: Fullscreen toggle
      if (event.keyCode === KeyCode.KEYCODE_F) {
        if (!this.isPhone) {
          this.toggleWindowFullScreen();
        } else {
          this.isFullScreen = !this.isFullScreen;
        }
        return;
      }
      // ESC: Exit fullscreen / go back
      if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        if (!this.isPhone) {
          if (this.isWindowFullScreen) {
            this.toggleWindowFullScreen();
          } else {
            this.pageStack.pop();
          }
        } else if (this.isFullScreen) {
          this.isFullScreen = false;
        } else {
          this.pageStack.pop();
        }
        return;
      }
      // M: Mute/Unmute
      if (event.keyCode === KeyCode.KEYCODE_M) {
        let isMuted = AppStorage.get<boolean>('isMuted');
        if (isMuted) {
          this.avPlayerController.setPlayerVolume(this.volume > 0 ? this.volume : 50);
          AppStorage.setOrCreate('isMuted', false);
        } else {
          this.avPlayerController.setPlayerVolume(0);
          AppStorage.setOrCreate('isMuted', true);
        }
        return;
      }
    })
  }
}
