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

import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { emitter, BusinessError } from '@kit.BasicServicesKit';
import { TimeUtil } from '../common/utils/TimeUtils';
import { AvPlayerController } from '../controller/AvPlayerController';
import { SpeedDialog } from './SpeedDialog';
import { CommonConstants } from '../common/constants/CommonConstants';
import { BreakpointConstants } from '../common/constants/BreakpointConstants';

const TAG = '[VideoOperate]';

@Component
export struct VideoOperate {
  @State speedSelect: number = 2; // Speed Magnification Selection (default 1.0X)
  @State showQualityList: boolean = false; // whether to show quality list
  @Link isFullScreen: boolean;
  @Link isWindowFullScreen: boolean;
  @Link isSwiping: boolean;
  @Link avPlayerController: AvPlayerController;
  onVolumeChange?: (value: number) => void;
  onWindowFullScreenToggle?: () => void;
  volumePercent: number = 100;
  @State showVolumeSlider: boolean = false;
  @State volumeValue: number = 100;
  @StorageLink('speedIndex') speedIndex: number = 2; // Index of the playback rate list (default 1.0X)
  @StorageLink('sliderWidth') sliderWidth: string = '';
  @StorageLink('speedName') speedName: Resource = $r('app.string.video_speed_1_0X');
  @StorageLink('isMuted') isMuted: boolean = false;
  @StorageLink('videoScaleType') videoScaleType: number = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
  @StorageProp(BreakpointConstants.CURRENT_BREAKPOINT) currentBreakpoint: string =
    BreakpointConstants.BREAKPOINT_SM;
  private dialogController: CustomDialogController = new CustomDialogController({
    builder: SpeedDialog({ avPlayerController: this.avPlayerController, speedSelect: this.speedSelect }),
    alignment: DialogAlignment.Center,
    offset: { dx: $r('app.float.size_zero'), dy: $r('app.float.size_down_20') }
  });
  private uiAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private windowClass = this.uiAbilityContext.windowStage.getMainWindowSync();

  private get isPhone(): boolean {
    return this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM;
  }

  async toggleFullScreen(): Promise<void> {
    if (!this.isPhone) {
      return;
    }
    this.isFullScreen = !this.isFullScreen;
    try {
      if (this.isFullScreen) {
        await this.windowClass.setWindowLayoutFullScreen(true);
        await this.windowClass.setPreferredOrientation(window.Orientation.LANDSCAPE);
      } else {
        await this.windowClass.setPreferredOrientation(window.Orientation.PORTRAIT);
        await this.windowClass.setWindowLayoutFullScreen(false);
      }
    } catch (err) {
      this.isFullScreen = !this.isFullScreen; // Revert state on failure
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `toggleFullScreen failed: ${JSON.stringify(err)}`);
    }
  }

  aboutToAppear(): void {
    this.windowClass.on('windowSizeChange', (newSize: window.Size) => {
      let eventWHData: emitter.EventData = {
        data: {
          'width': newSize.width,
          'height': newSize.height
        }
      };
      emitter.emit(CommonConstants.innerEventWH, eventWHData);
    });
  }

  @BuilderParam
  progressBuilder: () => void = this.defaultProgressBuilder;

  @Builder
  defaultProgressBuilder() {
    Row() {
      Slider({
        value: this.avPlayerController.currentTime,
        min: 0,
        max: this.avPlayerController.durationTime,
        style: SliderStyle.OutSet
      })
        .id('Slider')
        .blockColor(Color.White)
        .trackColor(Color.Gray)
        .selectedColor($r('app.color.slider_selected'))
        .trackThickness(this.isFullScreen ? 4 : 2)
        .showTips(false)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode == SliderChangeMode.Begin) {
            this.isSwiping = true;
            this.avPlayerController.videoPause();
          }
          this.avPlayerController.videoSeek(value);

          if (mode == SliderChangeMode.End) {
            this.isSwiping = false;
            this.avPlayerController.videoPlay();
          }
        })
    }
    .layoutWeight(1)
  }

  private getQualityLabel(bitrate: number): string {
    if (bitrate <= 0) return '自动';
    if (bitrate <= 400000) return '流畅';
    if (bitrate <= 800000) return '标清';
    if (bitrate <= 2000000) return '高清';
    return '超清';
  }

  @Builder
  qualityListItem(bitrate: number, label: string, index: number) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(this.avPlayerController.currentBitrateIndex === index ? '#4DA6FF' : Color.White)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(4)
    .backgroundColor(this.avPlayerController.currentBitrateIndex === index ?
      'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.01)')
    .onClick(() => {
      this.avPlayerController.setBitrate(bitrate);
      this.avPlayerController.currentBitrateIndex = index;
      this.avPlayerController.currentBitrateLabel = label;
      this.showQualityList = false;
    })
  }

  @Builder
  qualityListBuilder() {
    Column() {
      this.qualityListItem(0, '自动', 0)
      ForEach(this.avPlayerController.availableBitrates,
        (bitrate: number, idx: number) => {
          this.qualityListItem(bitrate, this.getQualityLabel(bitrate), idx + 1)
        }, (bitrate: number, idx: number) => `quality_${bitrate}_${idx}`)
    }
    .backgroundColor('rgba(30, 30, 30, 0.95)')
    .borderRadius(8)
    .padding({ top: 6, bottom: 6 })
    .position({ x: 0, y: 30 })
    .width(80)
    .zIndex(10)
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Row() {
            Image(this.avPlayerController.isPlaying ? $r('app.media.ic_video_play') :
            $r('app.media.ic_video_pause'))// Play/Pause
              .id('play')
              .width($r('app.float.size_25'))
              .height($r('app.float.size_25'))
              .onClick(() => {
                this.avPlayerController.isPlaying ? this.avPlayerController.videoPause() :
                this.avPlayerController.videoPlay();
              })

            // Left side time
            Text(TimeUtil.millisecondsToTime(this.avPlayerController.currentTime))
              .fontColor(Color.White)
              .textAlign(TextAlign.End)
              .fontWeight(FontWeight.Regular)
              .fontSize(this.isFullScreen ? 14 : 12)
              .margin({ left: $r('app.float.size_5') })
          }

          this.progressBuilder()

          Row() {
            // Right side time
            Text(TimeUtil.millisecondsToTime(this.avPlayerController.durationTime))
              .fontColor(Color.White)
              .fontWeight(FontWeight.Regular)
              .fontSize(this.isFullScreen ? 14 : 12)

            if (this.isFullScreen) {
              Button(this.speedName, { type: ButtonType.Normal })
                .border({ width: $r('app.float.size_1'), color: Color.White })
                .width($r('app.float.size_64'))
                .height($r('app.float.size_25'))
                .fontSize($r('app.float.size_15'))
                .borderRadius($r('app.float.size_20'))
                .fontColor(Color.White)
                .backgroundColor('#00000000')
                .opacity($r('app.float.size_1'))
                .padding({ left: $r('app.float.size_5'), right: $r('app.float.size_5') })
                .margin({ left: $r('app.float.size_8') })
                .id('Speed')
                .onClick(() => {
                  this.speedSelect = this.speedIndex;
                  this.dialogController.open();
                })

              Stack() {
                Button() {
                  Image(this.isMuted ? $r('app.media.ic_video_speaker_slash') : $r('app.media.ic_video_speaker'))
                    .width($r('app.float.size_25'))
                    .height($r('app.float.size_25'))
                }
                .type(ButtonType.Normal)
                .width($r('app.float.size_25'))
                .height($r('app.float.size_25'))
                .borderRadius($r('app.float.size_20'))
                .backgroundColor('#00000000')
                .fontColor(Color.White)
                .onClick(() => {
                  this.showVolumeSlider = !this.showVolumeSlider;
                })

                if (this.showVolumeSlider) {
                  Slider({
                    value: this.volumeValue,
                    min: 0,
                    max: 100,
                    step: 1,
                    style: SliderStyle.OutSet,
                    direction: Axis.Vertical,
                    reverse: true
                  })
                    .height(90)
                    .width(30)
                    .position({ x: -2.5, y: -90 })
                    .blockColor(Color.White)
                    .trackColor('rgba(255, 255, 255, 0.2)')
                    .selectedColor(Color.White)
                    .trackThickness(4)
                    .shadow({ radius: 4, color: '#80000000', offsetY: -2 })
                    .zIndex(100)
                    .onChange((value: number) => {
                      this.volumeValue = value;
                      if (this.onVolumeChange) {
                        this.onVolumeChange(value);
                      }
                      if (value === 0) {
                        this.isMuted = true;
                      } else {
                        this.isMuted = false;
                      }
                    })
                }
              }
              .width($r('app.float.size_25'))
              .height($r('app.float.size_25'))
              .margin({ left: $r('app.float.size_5') })
            }
            // PC/tablet immersive window fullscreen toggle
            if (!this.isPhone) {
              Image(this.isWindowFullScreen ? $r('app.media.ic_exit_fullscreen') : $r('app.media.fullscreen'))
                .size({ width: 25, height: 25 })
                .margin({ left: 10 })
                .onClick(() => {
                  this.onWindowFullScreenToggle?.();
                })
            }
            // Phone fullscreen toggle (orientation)
            if (this.isPhone) {
              Image(this.isFullScreen ? $r('app.media.ic_exit_fullscreen') : $r('app.media.fullscreen'))
                .size({ width: this.isFullScreen ? 28 : 32, height: this.isFullScreen ? 28 : 32 })
                .margin({ left: 10 })
                .onClick(() => {
                  this.toggleFullScreen();
                })
            }
          }
        }
        .height(this.isFullScreen ? 30 : 40)

        // Second row: quality selector
        Row() {
          // Quality selector - show only in fullscreen, click to list all
          if (this.isFullScreen && this.avPlayerController.showQualitySelector) {
            Stack() {
              Button() {
                Text(this.avPlayerController.currentBitrateLabel)
                  .fontSize(12)
                  .fontColor(Color.White)
              }
              .type(ButtonType.Normal)
              .height(25)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .borderRadius(4)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                this.showQualityList = !this.showQualityList;
              })

              // Quality list overlay
              if (this.showQualityList) {
                this.qualityListBuilder()
              }
            }
            .width(60)
            .height(30)
          }
        }
        .height(26)
      }
      .backgroundColor('#1a000000')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        // Close quality list when clicking outside
        if (this.showQualityList) {
          this.showQualityList = false;
        }
      })
      .padding({
        top: 5,
        bottom: this.isFullScreen ? 10 : 20,
        left: $r('app.float.size_20'),
        right: $r('app.float.size_20')
      })
      .height('auto')
      .width('100%')


    }
    .width('100%')
  }
}
