# ikun播放器 — 基于 AVPlayer 的全功能视频播放应用

## 项目简介

ikun播放器是一款基于 HarmonyOS **AVPlayer** 系统播放器构建的全功能视频播放应用。在基础网络视频播放之上，深度集成了本地视频导入、B站链接解析、AI实时字幕、弹幕互动、收藏管理、响应式多设备适配等能力，旨在为开发者提供一个覆盖视频播放全场景的实践参考。

本示例指导开发者实现以下核心开发场景：

- 网络 / 本地 / B站 多源视频播放
- 基本播控（播放、暂停、停止、Seek）
- 网络视频边缓冲边播放（PlaybackStrategy）
- 视频收藏、搜索与持久化管理
- AI 实时语音识别字幕（CoreSpeechKit）
- SRT 字幕加载与字体样式自定义
- 弹幕系统
- 画中画（PiP）
- 响应式断点布局（手机 / 平板 / 折叠屏 / 2in1）
- 分享、倍速、清晰度切换、亮度与音量调节

---

## 功能特性

### 🎬 视频源支持

| 来源类型 | 说明 |
|---------|------|
| **网络视频** | 输入 HTTP/HTTPS 链接直接播放（MP4 / M3U8 等） |
| **本地视频** | 通过系统 PhotoPicker 从相册选择，支持批量导入（≤20个），去重 |
| **B站视频** | 自动识别 B站链接（`bilibili.com/video/BVxxx`），通过 B站 API 解析真实流地址，支持 HLS → DASH → Progressive 三级回退 |
| **内置资源** | RAW 目录下的 MP4 / M3U8 本地测试资源 |

### 🏠 首页

- **主页 Tab**：本地视频入口 + 网络视频入口卡片
- **收藏 Tab**：网格布局展示已收藏视频，点击直接播放，支持管理模式批量删除
- **搜索 Tab**：跨收藏 + 本地视频的全文搜索

### ⭐ 收藏系统

- 基于 `preferences` 的持久化存储
- 播放页一键收藏 / 取消收藏（带 Toast 反馈）
- 收藏管理页支持多选批量删除（含确认弹窗）

### 🤖 AI 实时字幕

- 基于 HarmonyOS **CoreSpeechKit** 语音识别引擎
- **流式模式**（网络视频）：通过 `AudioPipeline` 系统内录 → PCM → ASR 引擎实时转写
- **批处理模式**（本地文件）：提取音频 → 分块送入引擎 → 输出识别结果
- 支持中文识别，识别状态实时展示（连接中 / 聆听中 / 错误提示）

### 📝 SRT 字幕系统

- 内置中/英双语 SRT 字幕文件（`captions.srt` / `en_captions.srt`）
- **字幕样式自定义**：字体（系统默认 / 等宽）、字号（12–40）、颜色（预设 + RGB 色盘自定义）
- **字幕位置拖拽**：手势拖动改变字幕 Y 轴位置，位置自动持久化

### 💬 弹幕

- 弹幕动画组件，支持从右向左滚动
- 自动过滤超出屏幕的弹幕
- 可开关显示

### 📐 响应式一多适配

- 基于 `mediaquery` 的断点系统（SM / MD / LG / XL）
- 自适应栅格布局、字体大小、内边距
- 支持设备类型：**手机、平板、折叠屏、2in1**
- 监听折叠屏 `foldDisplayModeChange` 事件自动重算视频尺寸
- 2in1 窗口边缘拖拽调整大小（cursor 样式切换）

### 🖥️ 播放控制

- 播放 / 暂停 / 拖动进度条 Seek
- **倍速播放**：0.5X / 0.75X / 1.0X / 1.25X / 1.5X / 2.0X
- **清晰度切换**：M3U8 多码率自适应，显示可选清晰度列表（自动 / 流畅 / 标清 / 高清 / 超清）
- **音量控制**：全屏模式下滑块调节（0–100），静音切换
- **亮度调节**：左侧屏幕滑动手势调节
- **视频缩放**：适应 / 拉伸 / 填充 / 裁剪 四种模式

### 🖼️ 画中画 & 全屏

- 画中画（PiP）控制器，支持启动前选择缩放模式
- 手机：旋转传感器自动横竖屏切换
- PC / 平板：沉浸式窗口全屏切换（`setWindowLayoutFullScreen`）

### 🔗 分享

- 网络视频：分享链接（HYPERLINK 类型）
- 本地视频：分享视频文件（VIDEO 类型）

---

## 使用说明

1. 使用 DevEco Studio 打开项目，编译运行
2. **主页**展示本地视频和网络视频入口卡片
3. 点击 **本地视频** → 通过系统相册选择视频导入并播放
4. 点击 **网络视频** → 输入 HTTP/HTTPS 链接（支持普通 URL 或 B站 BV 号链接）→ 点击播放
5. 播放页底部控制栏提供完整播控，全屏模式下显示倍速、音量、清晰度等更多选项
6. 点击 **⭐收藏** 按钮保存视频，在首页收藏 Tab 查看和管理
7. 点击 **AI字幕** 按钮开启实时语音识别
8. 点击 **字幕设置** 调整字体样式或切换语言

> **注意**：本示例中 M3U8 测试资源非公网资源，用户可在以下位置修改为自备资源：
> - `entry/src/main/ets/model/VideoDataModel.ets:44`
> - `entry/src/main/resources/rawfile/test.m3u8`

---

## 工程目录

```
ikun-avplayer/
├── AppScope/
│   ├── app.json5                                  // 应用级配置
│   └── resources/base/
│       ├── element/string.json
│       └── media/                                 // 应用图标资源
│
├── entry/src/main/
│   ├── module.json5                               // 模块配置（权限、Ability、设备类型）
│   ├── cpp/                                       // Native C++ 模块
│   │   ├── types/libentry/Index.d.ts              // NAPI 类型声明
│   │   └── types/libentry/oh-package.json5
│   │
│   ├── ets/                                       // ArkTS 主代码
│   │   ├── common/
│   │   │   ├── constants/
│   │   │   │   ├── BreakpointConstants.ets        // 断点常量（SM/MD/LG/XL、栅格、字体、内边距）
│   │   │   │   └── CommonConstants.ets            // 公共常量（AVPlayer状态、VideoDataType、Event ID）
│   │   │   └── utils/
│   │   │       ├── BreakpointSystem.ets           // 断点系统（mediaquery监听、自动同步AppStorage）
│   │   │       ├── GlobalContext.ets              // 全局上下文工具
│   │   │       ├── ImageUtil.ets                  // 图片工具
│   │   │       ├── ResourceUtil.ets               // 资源工具
│   │   │       └── TimeUtils.ets                  // 时间格式化工具（ms→HH:MM:SS）
│   │   │
│   │   ├── controller/
│   │   │   ├── AvPlayerController.ets             // AVPlayer 核心控制类（初始化、播控、B站API、字幕）
│   │   │   └── PipWindowController.ets            // 画中画控制类
│   │   │
│   │   ├── components/
│   │   │   ├── AiCaptionDisplay.ets               // AI字幕展示组件（识别文本/临时文本/状态提示）
│   │   │   ├── BulletCommentView.ets              // 弹幕视图组件（滚动动画）
│   │   │   ├── CaptionFontComponent.ets           // 字幕字体设置面板（语言/字体/大小/颜色/位置）
│   │   │   ├── ColorPickerDialog.ets              // RGB 色盘弹窗（字幕颜色自定义）
│   │   │   ├── ExitVideo.ets                      // 退出确认组件
│   │   │   ├── LanguageDialog.ets                 // 字幕语言切换弹窗
│   │   │   ├── ScaleDialog.ets                    // 画中画缩放模式设置弹窗
│   │   │   ├── SetBirghness.ets                   // 亮度调节组件（左侧手势滑动）
│   │   │   ├── SetVolume.ets                      // 音量调节组件
│   │   │   ├── SpeedDialog.ets                    // 播放倍速选择弹窗
│   │   │   └── VideoOperate.ets                   // 视频操作栏（播放/进度条/倍速/音量/清晰度/全屏）
│   │   │
│   │   ├── entryability/
│   │   │   └── EntryAbility.ets                   // 程序入口（注册断点系统）
│   │   │
│   │   ├── entrybackupability/
│   │   │   └── EntryBackupAbility.ets             // 备份扩展Ability
│   │   │
│   │   ├── model/
│   │   │   ├── AiCaptionConfig.ets                // AI字幕配置（语言选项、常量）
│   │   │   ├── BookmarkModel.ets                  // 收藏数据模型（BookmarkItem）
│   │   │   ├── BulletCommentModel.ets             // 弹幕数据模型
│   │   │   ├── SubtitleConfig.ets                 // 字幕配置（字体/颜色预设、常量）
│   │   │   ├── VideoData.ets                      // 视频数据结构定义
│   │   │   └── VideoDataModel.ets                 // 内置视频列表数据（示例资源URL）
│   │   │
│   │   ├── pages/
│   │   │   ├── BookmarkPage.ets                   // 收藏管理页（列表/管理模式/批量删除）
│   │   │   ├── BufferBarPlayer.ets                // 带缓冲条播放页（自定义进度Builder）
│   │   │   ├── Index.ets                          // 首页（三Tab：主页/收藏/搜索、本地视频导入、网络视频输入）
│   │   │   └── UrlPlayer.ets                      // URL播放页（装配 BasicVideoPlayer）
│   │   │
│   │   ├── services/
│   │   │   ├── BookmarkStore.ets                  // 收藏持久化存储（preferences 封装，CRUD操作）
│   │   │   ├── CoreSpeechProvider.ets             // CoreSpeechKit 语音识别引擎封装（批处理+流式）
│   │   │   └── VideoAudioCaptureService.ets       // 音视频采集服务（检测源类型→路由识别策略）
│   │   │
│   │   ├── utils/
│   │   │   └── AudioPipeline.ets                  // 音频管线（系统内录 + 下载解码 + PCM分块输出）
│   │   │
│   │   └── view/
│   │       ├── BasicVideoPlayer.ets               // 基础播放器视图（XComponent、全屏/横竖屏、手势、AI字幕、字幕、弹幕、收藏、分享）
│   │       └── VideoItem.ets                      // 首页视频列表项组件
│   │
│   └── resources/                                 // 资源目录
│       ├── base/
│       │   ├── element/
│       │   │   ├── color.json
│       │   │   ├── float.json
│       │   │   └── string.json                    // 中文字符串资源
│       │   ├── media/                             // 图标/图片资源（播放、暂停、全屏、音量、字幕等20+图标）
│       │   ├── profile/
│       │   │   ├── backup_config.json
│       │   │   └── main_pages.json                // 页面路由配置
│       │   └── rawfile/
│       │       ├── captions.srt                   // 中文字幕文件
│       │       ├── en_captions.srt                // 英文字幕文件
│       │       ├── HarmonyOS_Condensed.ttf        // 自定义字体
│       │       ├── test.m3u8                      // M3U8 测试资源
│       │       ├── test1.mp4                      // MP4 测试资源1
│       │       └── test2.mp4                      // MP4 测试资源2
│       ├── en_US/element/string.json              // 英文字符串资源
│       └── zh_CN/element/string.json              // 中文字符串资源
```

---

## 具体实现

### 1. 多源视频播放

通过 `VideoDataType` 枚举区分视频来源，`AvPlayerController.initAVPlayer()` 根据类型分发：

| VideoDataType | 实现方式 |
|--------------|---------|
| `RAW_FILE` | `resourceManager.getRawFd()` → `avPlayer.fdSrc` |
| `RAW_MP4_FILE` | `resourceManager.getRawFd()` → `fd://` URL → `avPlayer.url` |
| `RAW_M3U8_FILE` | `getRawFd()` → `createMediaSourceWithUrl(fdUrl)` → `avPlayer.setMediaSource()` + `PlaybackStrategy` |
| `URL` | 直接设置 `avPlayer.url` |
| `BILIBILI_URL` | B站 API 解析 → `createMediaSourceWithUrl(streamUrl, headers)` → `avPlayer.setMediaSource()` |

### 2. B站视频解析

```
用户输入 B站链接 → extractBvId() 提取 BV号
→ API: x/web-interface/view → 获取 cid
→ API: x/player/playurl?fnval=4048 → HLS (M3U8, 音视频合一)
  ↓ 失败
→ API: x/player/playurl?fnval=16 → DASH (仅视频, 跳过)
  ↓ 失败
→ API: x/player/playurl?fnval=1 → Progressive (FLV/MP4)
→ createMediaSourceWithUrl() + Referer/UA 请求头
```

### 3. 基本播控

通过 AVPlayer 的 `play()` / `pause()` / `stop()` / `seek()` 方法实现，进度条绑定 `currentTime` 和 `durationTime`。

### 4. 网络视频边缓冲边播放

通过 `media.PlaybackStrategy` 配置 `preferredBufferDuration` 和 `showFirstFrameOnPrepare`，结合 `setMediaSource()` 使用。

### 5. AI 实时字幕

```
VideoAudioCaptureService.detectSourceType()
├── 本地文件 → CoreSpeechProvider 批处理模式（文件→PCM→分块writeAudio→finish）
└── 网络视频 → CoreSpeechProvider 流式模式（startListening→AudioPipeline内录→writeAudioChunk→finishStreaming）

AudioPipeline:
├── PLAYBACK_CAPTURE: AudioCapturer(SOURCE_TYPE_PLAYBACK_CAPTURE) → PCM 16kHz→回调
└── DOWNLOAD_DECODE: HTTP下载 → Native C++ OH_AudioCodec解码 → PCM→回调

CoreSpeechProvider (基于 @kit.CoreSpeechKit):
→ createEngine() → setListener() → startListening() → writeAudio() → finish()
→ 结果回调: onResult(text, isFinal)
```

### 6. SRT 字幕

- 读取 rawfile 中的 `.srt` 文件，解析时间轴和文本
- `AVPlayer` 的 `on('subtitleUpdate')` 回调驱动字幕切换
- 语言切换通过 `languageChange()` 加载不同 SRT 文件
- 字体样式通过 `CaptionFont` 数据模型配置（字体族、大小、颜色）

### 7. 弹幕

`BulletCommentView` 通过 `setInterval(16ms)` 驱动弹幕位移动画，超出屏幕左侧后自动移除。支持用户弹幕高亮样式。

### 8. 收藏系统

`BookmarkStore` 基于 `preferences` 实现 JSON 序列化存储：
- `toggle()` 一键收藏/取消
- `getAll()` 按时间倒序排列
- 支持管理模式下多选批量删除

### 9. 响应式一多适配

`BreakpointSystem` 使用 `mediaquery.matchMediaSync()` 监听窗口宽度：
- **SM** (<600vp)：手机竖屏，4列栅格
- **MD** (600–840vp)：折叠屏展开/小平板，8列栅格
- **LG** (840–1440vp)：平板横屏/PC，12列栅格
- **XL** (≥1440vp)：2in1/大屏显示器，12列栅格

断点变化自动同步 `AppStorage`，组件通过 `@StorageProp('currentBreakpoint')` 响应式调整布局。

### 10. 画中画

`PipWindowController` 封装 `media.createAVPiPController()`，支持启动前选择缩放模式。

---

## 约束与限制

1. 本示例支持以下设备类型：华为手机、平板、2in1。
2. HarmonyOS 系统：**HarmonyOS 5.1.0 Release** 及以上。
3. DevEco Studio 版本：**DevEco Studio 5.1.0 Release** 及以上。
4. HarmonyOS SDK 版本：**HarmonyOS 5.1.0 Release SDK** 及以上。
5. AI 字幕功能依赖 `@kit.CoreSpeechKit` 系统能力，需真机或模拟器支持。
6. B站视频播放依赖 B站公开 API，可能受反爬策略影响导致解析失败（会自动回退直接URL播放）。
7. 音频内录（`SOURCE_TYPE_PLAYBACK_CAPTURE`）需 API 10+ 系统支持，低版本将回退到下载解码模式。

---

## 开源协议

本项目基于 Apache License 2.0 开源。
