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

@Component
export struct SubtitleColorPicker {
  @State red: number = 255;
  @State green: number = 255;
  @State blue: number = 255;
  @State hexPreview: string = '#FFFFFF';
  onConfirm?: (color: string) => void;
  onCancel?: () => void;

  updateHexPreview(): void {
    const rHex = this.red.toString(16).padStart(2, '0');
    const gHex = this.green.toString(16).padStart(2, '0');
    const bHex = this.blue.toString(16).padStart(2, '0');
    this.hexPreview = `#${rHex}${gHex}${bHex}`.toUpperCase();
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text($r('app.string.subtitle_choose_color'))
            .fontSize(18)
            .fontWeight(700)
            .fontColor(Color.White)

          Blank()

          Image($r('app.media.ic_subtitle_close'))
            .width(22)
            .height(22)
            .fillColor(Color.White)
            .onClick(() => {
              if (this.onCancel) {
                this.onCancel();
              }
            })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // Color preview circle
        Column() {
        }
        .width(64)
        .height(64)
        .borderRadius('50%')
        .backgroundColor(this.hexPreview)
        .border({ width: 2, color: Color.White })
        .margin({ bottom: 20 })

        // Hex display
        Text(this.hexPreview)
          .fontSize(16)
          .fontColor('rgba(255, 255, 255, 0.7)')
          .fontFamily('monospace')
          .margin({ bottom: 20 })

        // Red slider
        Row() {
          Text('R')
            .fontSize(14)
            .fontWeight(600)
            .fontColor('#FF6B6B')
            .width(20)

          Slider({
            value: this.red,
            min: 0,
            max: 255,
            step: 1,
            style: SliderStyle.InSet
          })
            .trackThickness(16)
            .blockSize({ width: 14, height: 14 })
            .trackColor('rgba(255, 107, 107, 0.3)')
            .selectedColor('#FF6B6B')
            .layoutWeight(1)
            .onChange((value: number) => {
              this.red = value;
              this.updateHexPreview();
            })

          Text(`${this.red}`)
            .fontSize(14)
            .fontColor(Color.White)
            .fontFamily('monospace')
            .width(36)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Green slider
        Row() {
          Text('G')
            .fontSize(14)
            .fontWeight(600)
            .fontColor('#63B959')
            .width(20)

          Slider({
            value: this.green,
            min: 0,
            max: 255,
            step: 1,
            style: SliderStyle.InSet
          })
            .trackThickness(16)
            .blockSize({ width: 14, height: 14 })
            .trackColor('rgba(99, 185, 89, 0.3)')
            .selectedColor('#63B959')
            .layoutWeight(1)
            .onChange((value: number) => {
              this.green = value;
              this.updateHexPreview();
            })

          Text(`${this.green}`)
            .fontSize(14)
            .fontColor(Color.White)
            .fontFamily('monospace')
            .width(36)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Blue slider
        Row() {
          Text('B')
            .fontSize(14)
            .fontWeight(600)
            .fontColor('#4ECDC4')
            .width(20)

          Slider({
            value: this.blue,
            min: 0,
            max: 255,
            step: 1,
            style: SliderStyle.InSet
          })
            .trackThickness(16)
            .blockSize({ width: 14, height: 14 })
            .trackColor('rgba(78, 205, 196, 0.3)')
            .selectedColor('#4ECDC4')
            .layoutWeight(1)
            .onChange((value: number) => {
              this.blue = value;
              this.updateHexPreview();
            })

          Text(`${this.blue}`)
            .fontSize(14)
            .fontColor(Color.White)
            .fontFamily('monospace')
            .width(36)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .margin({ bottom: 20 })

        // Confirm button
        Button($r('app.string.dialog_confirm'))
          .width('100%')
          .height(40)
          .fontSize(16)
          .fontColor(Color.Black)
          .backgroundColor(Color.White)
          .borderRadius(20)
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm(this.hexPreview);
            }
          })
      }
      .width('85%')
      .backgroundColor('#1A1A1A')
      .borderRadius(16)
      .padding({ top: 24, left: 20, right: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(0, 0, 0, 0.6)')
    .onClick(() => {
      if (this.onCancel) {
        this.onCancel();
      }
    })
  }
}
