$file = "C:\Users\gnw28\Desktop\APPSOURSE\avplayer-online-video-master\entry\src\main\ets\view\BasicVideoPlayer.ets"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

# --- Find positions ---
$builder1_start = $content.IndexOf("`n  @Builder`n  AiCaptionConfigDialog()")
$builder1_end = $content.IndexOf("`n  @Builder`n  MoreMenuBuilder()", $builder1_start + 10)
Write-Host "AiCaptionConfigDialog: $builder1_start -> $builder1_end"

# --- Build the new UnifiedCaptionDialog builder ---
$newBuilder = @"
`n  @Builder
  UnifiedCaptionDialog() {
    Column() {
      Column() {
        Row() {
          Text(`$r('app.string.subtitle_settings_title'))
            .fontSize(18).fontWeight(700).fontColor(Color.White)
          Blank()
          Row({ space: 16 }) {
            Image(`$r('app.media.ic_subtitle_close')).width(22).height(22).fillColor(Color.White)
              .onClick(() => { this.isShowCaptionConfig = false; })
            Image(`$r('app.media.ic_subtitle_check')).width(22).height(22).fillColor(Color.White)
              .onClick(() => { this.avPlayerController.captionFont = this.captionFont; this.isShowCaptionConfig = false; })
          }
        }
        .width('100%').margin({ bottom: 16 })
        if (this.avPlayerController.hasCaption) {
          Row() {
            Text(`$r('app.string.language_switch')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Row({ space: 12 }) {
              Button(`$r('app.string.Chinese')).fontSize(14)
                .fontColor(this.avPlayerController.currentLanguageType === 0 ? Color.Black : Color.White)
                .backgroundColor(this.avPlayerController.currentLanguageType === 0 ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                .borderRadius(20).padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => { this.avPlayerController.languageChange(0); })
              Button(`$r('app.string.English')).fontSize(14)
                .fontColor(this.avPlayerController.currentLanguageType === 1 ? Color.Black : Color.White)
                .backgroundColor(this.avPlayerController.currentLanguageType === 1 ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                .borderRadius(20).padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => { this.avPlayerController.languageChange(1); })
            }
          }
          .width('100%').padding({ top: 4, bottom: 10 }).justifyContent(FlexAlign.SpaceBetween)
          Divider().color('rgba(255,255,255,0.2)')
          Row({ space: 20 }) {
            Text(`$r('app.string.subtitle_font')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Row({ space: 12 }) {
              ForEach(SubtitleConstants.CAPTION_FONT_FAMILY, (family: ResourceStr, index: number) => {
                Button(family).fontSize(16)
                  .fontColor(this.captionFont.family === family ? Color.Black : Color.White)
                  .backgroundColor(this.captionFont.family === family ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.1)')
                  .borderRadius(20).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .onClick(() => { this.captionFont.family = family; })
              }, (family: ResourceStr, index: number) => `${"$"}{family}_${"$"}{index}`)
            }
          }
          .width('100%').padding({ top: 14, bottom: 14 }).justifyContent(FlexAlign.SpaceBetween)
          Divider().color('rgba(255,255,255,0.2)')
          Column() {
            Row() {
              Text(`$r('app.string.subtitle_font_size')).fontColor(Color.White).fontSize(16).fontWeight(500)
              Text(`${"$"}{this.captionFont.size}`).fontColor('rgba(255, 255, 255, 0.6)').fontSize(14)
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)
            Slider({ value: this.captionFont.size, min: SubtitleConstants.CAPTION_FONT_SIZE_MIN, max: SubtitleConstants.CAPTION_FONT_SIZE_MAX, step: 1, style: SliderStyle.InSet })
              .trackThickness(20).blockSize({ width: 14, height: 14 }).trackColor('rgba(255, 255, 255, 0.4)').selectedColor(Color.White)
              .onChange((value: number) => { this.captionFont.size = value; })
          }.width('100%').margin({ top: 14, bottom: 4 })
          Divider().color('rgba(255,255,255,0.2)')
          Row() {
            Text(`$r('app.string.subtitle_font_color')).fontColor(Color.White).fontSize(16).fontWeight(500)
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
              ForEach(SubtitleConstants.CAPTION_FONT_COLOR, (color: ResourceColor, index: number) => {
                Column() {
                  if (this.captionFont.color === color) {
                    Column() {}.width(12).height(12).borderRadius('50%').border({ width: 1, color: 'rgb(241,243,245)' })
                  }
                }.width(28).height(28).borderRadius('50%').backgroundColor(color).justifyContent(FlexAlign.Center)
                .onClick(() => { this.captionFont.color = color; })
              }, (color: ResourceColor, index: number) => `${"$"}{color}_${"$"}{index}`)
            }.width('60%')
          }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 14 })
          Divider().color('rgba(255,255,255,0.2)')
          Row() {
            Button(`$r('app.string.subtitle_change_position')).fontSize(14).fontColor(Color.White)
              .backgroundColor('rgba(255,255,255,0.15)').borderRadius(20)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .onClick(() => { this.isShowCaptionConfig = false; this.isChangingSubtitlePosition = true; })
          }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })
        } else {
          Column() {
            Text(`$r('app.string.subtitle_not_available_title')).fontSize(18).fontWeight(600).fontColor(Color.White).margin({ bottom: 12 })
            Text(`$r('app.string.subtitle_not_available_desc')).fontSize(14).fontColor('rgba(255, 255, 255, 0.6)').textAlign(TextAlign.Center).width('100%')
          }.width('100%').padding({ top: 20, bottom: 10 }).alignItems(HorizontalAlign.Center)
        }
        Divider().color('rgba(255,255,255,0.3)').margin({ top: 10, bottom: 16 })
        Text('AI ' + [char]0x5B9E + [char]0x65F6 + [char]0x5B57 + [char]0x5E55).fontSize(16).fontWeight(600).fontColor(Color.White).width('100%').margin({ bottom: 12 })
        Row() {
          Text([char]0x5F00 + [char]0x542F + 'AI' + [char]0x5B9E + [char]0x65F6 + [char]0x5B57 + [char]0x5E55).fontSize(14).fontColor('rgba(255, 255, 255, 0.85)')
          Toggle({ type: ToggleType.Switch, isOn: this.isAiCaptionShown })
            .onChange((isOn: boolean) => { if (isOn !== this.isAiCaptionShown) { this.toggleAiCaption(); } })
        }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 12 })
        if (this.isAiCaptionShown) {
          Text([char]0x6E90 + [char]0x8BED + [char]0x8A00).fontSize(13).fontColor('rgba(255, 255, 255, 0.6)').width('100%').margin({ bottom: 6 })
          Row({ space: 8 }) {
            ForEach(AiCaptionConstants.SOURCE_LANG_OPTIONS, (option: AiCaptionLangOption) => {
              Button(option.label).fontSize(13)
                .fontColor(this.aiSourceLang === option.value ? Color.Black : Color.White)
                .backgroundColor(this.aiSourceLang === option.value ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.15)')
                .borderRadius(16).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => { this.onAiSourceLangChange(option.value); })
            }, (option: AiCaptionLangOption) => `src_${"$"}{option.value}`)
          }.width('100%').margin({ bottom: 10 })
          Text([char]0x76EE + [char]0x6807 + [char]0x8BED + [char]0x8A00).fontSize(13).fontColor('rgba(255, 255, 255, 0.6)').width('100%').margin({ bottom: 6 })
          Row({ space: 8 }) {
            ForEach(this.getTargetLangOptions(), (option: AiCaptionLangOption) => {
              Button(option.label).fontSize(13)
                .fontColor(this.aiTargetLang === option.value ? Color.Black : Color.White)
                .backgroundColor(this.aiTargetLang === option.value ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.15)')
                .borderRadius(16).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => { this.onAiTargetLangChange(option.value); })
            }, (option: AiCaptionLangOption) => `tgt_${"$"}{option.value}`)
          }.width('100%').margin({ bottom: 8 })
          Text('AI' + [char]0x5B57 + [char]0x5E55 + [char]0x901A + [char]0x8FC7 + [char]0x7CFB + [char]0x7EDF + [char]0x8BED + [char]0x97F3 + [char]0x8BC6 + [char]0x522B + [char]0x81EA + [char]0x52A8 + [char]0x751F + [char]0x6210 + [char]0x5B9E + [char]0x65F6 + [char]0x5B57 + [char]0x5E55 + '，' + [char]0x652F + [char]0x6301 + [char]0x4E2D + [char]0x82F1 + [char]0x6587 + [char]0x7FFB + [char]0x8BD1 + '。').fontSize(11).fontColor('rgba(255, 255, 255, 0.4)').width('100%')
        }
      }
      .width('85%').maxHeight('85%').backgroundColor('#1A1A1A').borderRadius(16)
      .padding({ top: 24, left: 20, right: 20, bottom: 28 })
      .onClick(() => { })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('rgba(0, 0, 0, 0.6)')
    .onClick(() => { this.avPlayerController.captionFont = this.captionFont; this.isShowCaptionConfig = false; })
  }
"@

# Replace the AiCaptionConfigDialog builder
$content = $content.Substring(0, $builder1_start) + $newBuilder + $content.Substring($builder1_end)
Write-Host "Replaced builder, new length: $($content.Length)"

# --- Now replace the CaptionFontComponent usage in build() ---
# Find "if (this.isShowCaptionConfig) {"
$cfgIdx = $content.IndexOf("if (this.isShowCaptionConfig)")
Write-Host "isShowCaptionConfig at: $cfgIdx"

# Find "if (this.isAiCaptionConfigShown)" (which is after the CaptionFontComponent block and before AiCaptionConfigDialog)
$aiShownIdx = $content.IndexOf("if (this.isAiCaptionConfigShown)", $cfgIdx)
Write-Host "isAiCaptionConfigShown at: $aiShownIdx"

# Find the end of the AiCaptionConfigDialog call in build()
$aiEndMarker = "this.AiCaptionConfigDialog()"
$aiCallIdx = $content.IndexOf($aiEndMarker, $aiShownIdx)
Write-Host "AiCaptionConfigDialog call at: $aiCallIdx"

# Find the next line after the AiCaptionConfigDialog() call
$afterAiCall = $content.IndexOf("}", $aiCallIdx)
$afterAiCall = $content.IndexOf("}", $afterAiCall + 1)
$afterAiCall = $content.IndexOf("}", $afterAiCall + 1)

# Find the end of the block (looking for the next "if (this.showMoreMenu)")
$moreIdx = $content.IndexOf("if (this.showMoreMenu)", $aiCallIdx)
Write-Host "showMoreMenu at: $moreIdx"

# Replace from isShowCaptionConfig to just before showMoreMenu
$newCallBlock = @"
      if (this.isShowCaptionConfig) {
        this.UnifiedCaptionDialog()
      }

"@

$content = $content.Substring(0, $cfgIdx) + $newCallBlock + $content.Substring($moreIdx)
Write-Host "Replaced call block, final length: $($content.Length)"

# Write the result
[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
Write-Host "Done! File written."
