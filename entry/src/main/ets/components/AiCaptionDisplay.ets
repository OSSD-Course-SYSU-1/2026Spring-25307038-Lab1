/*
 * Custom AI Caption Display Component
 * Replaces the built-in AICaptionComponent (@kit.SpeechKit) which requires
 * SystemCapability.AI.AICaption (unavailable on emulators).
 *
 * Displays real-time speech recognition results from Huawei Cloud ASR.
 */

@Component
export struct AiCaptionDisplay {
  @Prop captionText: string = '';
  @Prop interimText: string = '';
  @Prop statusText: string = '';
  @Prop isVisible: boolean = false;
  @Prop positionY: number = 0.85; // Relative Y (0-1)
  @Prop fontSize: number = 18;
  @Prop fontColor: ResourceColor = Color.White;
  @Prop bgColor: ResourceColor = 'rgba(0, 0, 0, 0.6)';

  private getHasText(): boolean {
    return this.captionText.length > 0 || this.interimText.length > 0 || this.statusText.length > 0;
  }

  build() {
    if (this.isVisible && this.getHasText()) {
      Stack() {
        Column() {
          // Status text (connecting, listening, error)
          if (this.statusText && !this.captionText) {
            Text(this.statusText)
              .fontSize(Math.max(12, this.fontSize - 4))
              .fontColor(this.statusText.includes('失败') || this.statusText.includes('错误') ?
                '#FF6B6B' : 'rgba(255, 255, 255, 0.6)')
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          }

          // Final recognized text
          if (this.captionText) {
            Text(this.captionText)
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
              .textAlign(TextAlign.Center)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 12, right: 12, top: 6, bottom: 2 })
          }

          // Interim text (only show when no final text)
          if (this.interimText && !this.captionText) {
            Row() {
              Text(this.interimText)
                .fontSize(this.fontSize - 2)
                .fontColor('rgba(255, 255, 255, 0.6)')
                .fontStyle(FontStyle.Italic)
                .textAlign(TextAlign.Center)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(' ●')
                .fontSize(10)
                .fontColor('#4DA6FF')
            }
            .padding({ left: 12, right: 12, top: 2, bottom: 6 })
            .width('100%')
          }
        }
        .backgroundColor(this.bgColor)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .position({
        x: 0,
        y: `${this.positionY * 100}%`
      })
      .padding({ left: 20, right: 20 })
      .alignContent(Alignment.Center)
      .hitTestBehavior(HitTestMode.None)
    }
  }
}
