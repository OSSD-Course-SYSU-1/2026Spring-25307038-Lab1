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

import { CaptionFont, SubtitleConstants } from '../model/SubtitleConfig';
import { SubtitleColorPicker } from './ColorPickerDialog';
import { AvPlayerController } from '../controller/AvPlayerController';

@Component
export struct CaptionFontComponent {
  @Prop captionFont: CaptionFont = SubtitleConstants.DEFAULT_CAPTION_FONT;
  @Prop hasCaption: boolean = true;
  @Prop avPlayerController: AvPlayerController = new AvPlayerController();
  @State showColorPicker: boolean = false;
  @State customColor: string = '#FFFFFF';
  @StorageLink('currentLanguageType') currentLanguageType: number = 0;
  onStartPositionChange?: () => void;
  close: (captionFont: CaptionFont | null) => void = () => {
  };

  isPresetColorSelected(color: ResourceColor): boolean {
    return this.captionFont.color === color &&
      !this.isCustomColorActive();
  }

  isCustomColorActive(): boolean {
    return typeof this.captionFont.color === 'string' &&
      this.captionFont.color.startsWith('#') &&
      this.captionFont.color.length === 7;
  }

  @Builder
  FontFamilyButton(text: ResourceStr) {
    Button(text)
      .fontSize(16)
      .fontColor(this.captionFont.family === text ? Color.Black : Color.White)
      .backgroundColor(this.captionFont.family === text ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
      .borderRadius(20)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .onClick(() => {
        this.captionFont.family = text;
      })
  }

  @Builder
  FontColorDot(captionFontColor: ResourceColor) {
    Column() {
      if (this.isPresetColorSelected(captionFontColor)) {
        Column() {
        }
        .width(12)
        .height(12)
        .borderRadius('50%')
        .border({ width: 1, color: 'rgb(241,243,245)' })
      }
    }
    .width(28)
    .height(28)
    .borderRadius('50%')
    .backgroundColor(captionFontColor)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.captionFont.color = captionFontColor;
    })
  }

  @Builder
  CustomColorDot() {
    Column() {
      if (this.isCustomColorActive()) {
        Column() {
        }
        .width(12)
        .height(12)
        .borderRadius('50%')
        .border({ width: 1, color: 'rgb(241,243,245)' })
      }

      Image($r('app.media.ic_subtitle_plus'))
        .width(14)
        .height(14)
        .fillColor(Color.White)
    }
    .width(28)
    .height(28)
    .borderRadius('50%')
    .backgroundColor(this.isCustomColorActive() ? this.captionFont.color : 'rgba(255, 255, 255, 0.15)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showColorPicker = true;
    })
  }

  build() {
    Stack() {
      Column() {
        Column() {
          Row() {
            Column() {
              Text($r('app.string.subtitle_settings_title'))
                .fontSize(18)
                .fontWeight(700)
                .fontColor(Color.White)
            }

            Blank()
            Row({ space: 16 }) {
              Image($r('app.media.ic_subtitle_close'))
                .width(22)
                .height(22)
                .fillColor(Color.White)
                .onClick(() => {
                  this.close(null);
                })
              Image($r('app.media.ic_subtitle_check'))
                .width(22)
                .height(22)
                .fillColor(Color.White)
                .onClick(() => {
                  this.close(this.captionFont);
                })
            }
          }
          .width('100%')
          .margin({ bottom: 16 })

          if (!this.hasCaption) {
            Column() {
              Text($r('app.string.subtitle_not_available_title'))
                .fontSize(18)
                .fontWeight(600)
                .fontColor(Color.White)
                .margin({ bottom: 12 })

              Text($r('app.string.subtitle_not_available_desc'))
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.6)')
                .textAlign(TextAlign.Center)
                .width('100%')

              Image($r('app.media.ic_video_translate'))
                .width(48)
                .height(48)
                .opacity(0.3)
                .margin({ top: 20 })
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
            .alignItems(HorizontalAlign.Center)
          }

          if (this.hasCaption) {
            Column() {
              // Language selection row
              Row() {
                Column() {
                  Text($r('app.string.language_switch'))
                    .fontColor(Color.White)
                    .fontSize(16)
                    .fontWeight(500)
                }

                Row({ space: 12 }) {
                  Button($r('app.string.Chinese'))
                    .fontSize(14)
                    .fontColor(this.currentLanguageType === 0 ? Color.Black : Color.White)
                    .backgroundColor(this.currentLanguageType === 0 ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                    .borderRadius(20)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.currentLanguageType = 0;
                      AppStorage.setOrCreate('currentLanguageType', 0);
                      this.avPlayerController.languageChange(0);
                    })

                  Button($r('app.string.English'))
                    .fontSize(14)
                    .fontColor(this.currentLanguageType === 1 ? Color.Black : Color.White)
                    .backgroundColor(this.currentLanguageType === 1 ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                    .borderRadius(20)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.currentLanguageType = 1;
                      AppStorage.setOrCreate('currentLanguageType', 1);
                      this.avPlayerController.languageChange(1);
                    })
                }
              }
              .width('100%')
              .padding({ top: 4, bottom: 10 })
              .justifyContent(FlexAlign.SpaceBetween)

              Divider()
                .color('rgba(255,255,255,0.2)')

              // Font family row
              Row({ space: 20 }) {
                Column() {
                  Text($r('app.string.subtitle_font'))
                    .fontColor(Color.White)
                    .fontSize(16)
                    .fontWeight(500)
                }

                Row({ space: 12 }) {
                  ForEach(SubtitleConstants.CAPTION_FONT_FAMILY,
                    (captionFontFamily: ResourceStr, index: number) => {
                      this.FontFamilyButton(captionFontFamily)
                    }, (captionFontFamily: ResourceStr, index: number) =>
                      `${captionFontFamily}_${index}`)
                }
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .justifyContent(FlexAlign.SpaceBetween)

              Divider()
                .color('rgba(255,255,255,0.2)')

              // Font size row
              Column() {
                Row() {
                  Column() {
                    Text($r('app.string.subtitle_font_size'))
                      .fontColor(Color.White)
                      .fontSize(16)
                      .fontWeight(500)
                  }

                  Column() {
                    Text(`${this.captionFont.size}`)
                      .fontColor('rgba(255, 255, 255, 0.6)')
                      .fontSize(14)
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  Slider({
                    value: this.captionFont.size,
                    min: SubtitleConstants.CAPTION_FONT_SIZE_MIN,
                    max: SubtitleConstants.CAPTION_FONT_SIZE_MAX,
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .trackThickness(20)
                    .blockSize({
                      width: 14,
                      height: 14
                    })
                    .trackColor('rgba(255, 255, 255, 0.4)')
                    .selectedColor(Color.White)
                    .onChange((value: number) => {
                      this.captionFont.size = value;
                    })
                }
                .justifyContent(FlexAlign.Start)
                .width('calc(100% + 10vp)')
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ top: 14, bottom: 4 })

              Divider()
                .color('rgba(255,255,255,0.2)')

              // Font color row
              Row() {
                Column() {
                  Text($r('app.string.subtitle_font_color'))
                    .fontColor(Color.White)
                    .fontSize(16)
                    .fontWeight(500)
                }

                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
                  ForEach(SubtitleConstants.CAPTION_FONT_COLOR,
                    (captionFontColor: ResourceColor, index: number) => {
                      this.FontColorDot(captionFontColor)
                    }, (captionFontColor: ResourceColor, index: number) =>
                      `${captionFontColor}_${index}`)

                  this.CustomColorDot()
                }
                .width('60%')
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 14 })

              Divider()
                .color('rgba(255,255,255,0.2)')

              // Change subtitle position button
              Row() {
                Button($r('app.string.subtitle_change_position'))
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor('rgba(255,255,255,0.15)')
                  .borderRadius(20)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .onClick(() => {
                    if (this.onStartPositionChange) {
                      this.onStartPositionChange();
                    }
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 16 })
            }
          }
        }
        .width('85%')
        .backgroundColor('#1A1A1A')
        .borderRadius(16)
        .padding({ top: 24, left: 20, right: 20, bottom: 28 })
        .onClick(() => {
          // Prevent event propagation
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0, 0, 0, 0.6)')
      .onClick(() => {
        this.close(null);
      })

      // Color picker overlay
      if (this.showColorPicker) {
        SubtitleColorPicker({
          onConfirm: (color: string) => {
            this.captionFont.color = color;
            this.customColor = color;
            this.showColorPicker = false;
          },
          onCancel: () => {
            this.showColorPicker = false;
          }
        })
      }
    }
  }
}
