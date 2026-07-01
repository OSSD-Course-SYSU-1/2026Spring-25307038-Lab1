/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */
import { promptAction, window } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { pointer } from '@kit.InputKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { CommonConstants, VideoDataType } from '../common/constants/CommonConstants';
import { BreakpointConstants } from '../common/constants/BreakpointConstants';
import { VideoData } from '../model/VideoData';
import { BookmarkStore } from '../services/BookmarkStore';
import { BookmarkItem } from '../model/BookmarkModel';
import { UrlPlayer } from './UrlPlayer';

const TAG = '[Index]';

interface LocalVideoItem {
  name: string;
  uri: string;
  size: string;
}

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @Provide('systemStatusAreaHeight') systemStatusAreaHeight: number = 0;
  @StorageProp(BreakpointConstants.CURRENT_BREAKPOINT) currentBreakpoint: string =
    BreakpointConstants.BREAKPOINT_SM;

  // Tab state
  @State currentTab: number = 0;

  // Home sub-page: null=home, 'localVideo'=本地视频页
  @State homeSubPage: string = '';

  // Favorites
  @State bookmarks: BookmarkItem[] = [];
  @State favBookmarkCount: number = 0;

  // Search
  @State searchKeyword: string = '';
  @State searchResults: BookmarkItem[] = [];

  // Local videos
  @State localVideos: LocalVideoItem[] = [];

  // Network video dialog
  @State showNetworkDialog: boolean = false;
  @State networkUrl: string = '';

  // Cursor resize
  @State windowWidthVp: number = 0;
  @State windowHeightVp: number = 0;
  private cursorController = this.getUIContext().getCursorController();
  private readonly EDGE_THRESHOLD: number = 8;

  private bookmarkStore: BookmarkStore = BookmarkStore.getInstance();
  private uiAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private windowClass = this.uiAbilityContext.windowStage.getMainWindowSync();

  aboutToAppear(): void {
    this.loadBookmarks();
    let area = this.windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    this.systemStatusAreaHeight = area.topRect.height;
    this.windowClass.on('avoidAreaChange', (opts) => {
      if (opts.type === window.AvoidAreaType.TYPE_SYSTEM) {
        this.systemStatusAreaHeight = opts.area.topRect.height;
      }
    });
    let sysBarProps: window.SystemBarProperties = {
      statusBarContentColor: Color.White.toString()
    };
    this.windowClass.setWindowSystemBarProperties(sysBarProps);

    let rect = this.windowClass.getWindowProperties().windowRect;
    this.windowWidthVp = this.getUIContext().px2vp(rect.width);
    this.windowHeightVp = this.getUIContext().px2vp(rect.height);
    this.windowClass.on('windowSizeChange', (size: window.Size) => {
      this.windowWidthVp = this.getUIContext().px2vp(size.width);
      this.windowHeightVp = this.getUIContext().px2vp(size.height);
    });
  }

  aboutToDisappear(): void {
    this.windowClass.off('avoidAreaChange');
    this.windowClass.off('windowSizeChange');
  }

  async loadBookmarks(): Promise<void> {
    try {
      await this.bookmarkStore.init(this.uiAbilityContext);
      this.bookmarks = this.bookmarkStore.getAll();
      this.favBookmarkCount = this.bookmarks.length;
    } catch (e) {
      console.error(`[Index] loadBookmarks失败: ${JSON.stringify(e)}`);
    }
  }

  onPageShow(): void {
    this.loadBookmarks();
  }

  playVideo(data: VideoData): void {
    this.pageStack.pushPathByName('UrlPlayer', data);
  }

  // ─── Builders ──────────────────────────────────────

  @Builder
  BannerBuilder() {
    Column() {
      Row() {
        if (this.homeSubPage === 'localVideo') {
          Row() {
            Text('←').fontColor(Color.White).fontSize(22).onClick(() => { this.homeSubPage = ''; });
            Text('本地视频').fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 18)).fontWeight(600).margin({ left: 12 });
          }.width('100%').padding({ left: 16 }).justifyContent(FlexAlign.Start)
        } else if (this.currentTab === 1) {
          Row() {
            Text('ikun播放器').fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 18)).fontWeight(600);
            Blank();
            Text(`${this.favBookmarkCount}个视频`).fontColor('#999999').fontSize(getFontSize(this.currentBreakpoint, 13));
          }.width('100%').padding({ left: 16, right: 16 });
        } else {
          Text('ikun播放器')
            .fontColor(Color.White)
            .fontSize(getFontSize(this.currentBreakpoint, 18))
            .fontWeight(600)
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ left: 16 });
        }
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.Center);
    }
    .width('100%')
    .backgroundColor('#1a1a1a')
    .padding({ top: `${this.systemStatusAreaHeight + 4}px`, bottom: 4 });
  }

  @Builder
  HomePageBuilder() {
    Column() {
      // 本地视频 入口卡片
      Row() {
        Text('📁').fontSize(28);
        Text('本地视频').fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 16)).margin({ left: 12 });
      }
      .width('100%')
      .height(56)
      .padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint) })
      .onClick(() => { this.homeSubPage = 'localVideo'; })

      Divider().color('#333333').width('100%');

      // 网络视频 入口卡片
      Row() {
        Text('🌐').fontSize(28);
        Text('网络视频').fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 16)).margin({ left: 12 });
      }
      .width('100%')
      .height(56)
      .padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint) })
      .onClick(() => { this.networkUrl = ''; this.showNetworkDialog = true; });

      Blank();
    }
    .layoutWeight(1)
    .backgroundColor('#1a1a1a')
    .padding({ top: 12 });
  }

  @Builder
  LocalVideoPageBuilder() {
    Column() {
      if (this.localVideos.length === 0) {
        Column() {
          Text('暂无本地视频').fontColor('#666666').fontSize(14).margin({ top: 40 });
          Text('点击下方按钮从相册导入').fontColor('#555555').fontSize(12).margin({ top: 8 });
          Button('从相册选择视频')
            .backgroundColor('#4ea1ff')
            .fontColor(Color.White)
            .margin({ top: 16 })
            .borderRadius(20)
            .onClick(() => { this.pickLocalVideos(); });
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        List({ space: getListSpace(this.currentBreakpoint) }) {
          ForEach(this.localVideos, (item: LocalVideoItem, idx: number) => {
            ListItem() {
              this.VideoListItemBuilder(item.name, item.uri, '', VideoDataType.RAW_FILE);
            }
          }, (item: LocalVideoItem, idx: number) => `${idx}_${item.uri}`);
        }
        .width('100%').layoutWeight(1).padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint) });
      }
    }
    .layoutWeight(1).backgroundColor('#1a1a1a').padding({ top: 12 });
  }

  @Builder
  VideoListItemBuilder(title: string, uri: string, thumbnail: string, vType: VideoDataType) {
    Row() {
      // 封面
      if (thumbnail && thumbnail.length > 0) {
        Image(thumbnail).height(72).width(108).objectFit(ImageFit.Cover).borderRadius(12);
      } else {
        Column() {
          Text('🎬').fontSize(32)
        }
        .width(108).height(72).borderRadius(12).backgroundColor('#2a2a2a')
        .justifyContent(FlexAlign.Center);
      }
      // 标题（封面下方→右侧）
      Column() {
        Text(title).fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 14))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%');
      }
      .margin({ left: 12 }).layoutWeight(1).alignItems(HorizontalAlign.Start);
    }
    .width('100%').height(72)
    .onClick(() => {
      let vd: VideoData = { name: title, type: vType, videoSrc: uri, description: '', caption: '', index: 0 };
      this.playVideo(vd);
    });
  }

  @Builder
  FavoritesPageBuilder() {
    Column() {
      if (this.bookmarks.length === 0) {
        Column() {
          Text('暂无收藏').fontColor('#666666').fontSize(14);
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        List({ space: getListSpace(this.currentBreakpoint) }) {
          ForEach(this.bookmarks, (item: BookmarkItem, idx: number) => {
            ListItem() {
              Column() {
                // 封面图
                if (item.thumbnailPath && item.thumbnailPath.length > 0) {
                  Image(item.thumbnailPath).width('100%').height(getCoverHeight(this.currentBreakpoint))
                    .objectFit(ImageFit.Cover).borderRadius({ topLeft: 12, topRight: 12 });
                } else {
                  Column() {
                    Text('🎬').fontSize(32)
                  }
                  .width('100%').height(getCoverHeight(this.currentBreakpoint)).borderRadius({ topLeft: 12, topRight: 12 })
                  .backgroundColor('#2a2a2a').justifyContent(FlexAlign.Center);
                }
                // 标题在封面下方
                Text(item.title).fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 13))
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 8 });
              }
              .width('100%').backgroundColor('#2a2a2a').borderRadius(12)
              .onClick(() => {
                let vd: VideoData = { name: item.title, type: item.videoType, videoSrc: item.url,
                  description: '', caption: '', index: 0 };
                this.playVideo(vd);
              });
            }
          }, (item: BookmarkItem, idx: number) => `fav_${idx}_${item.url}`);
        }
        .width('100%').layoutWeight(1)
        .padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint) });
      }
    }
    .layoutWeight(1).backgroundColor('#1a1a1a').padding({ top: 12 });
  }

  @Builder
  SearchPageBuilder() {
    Column() {
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索本地视频，网络视频', text: this.searchKeyword })
          .backgroundColor('#2a2a2a')
          .fontColor(Color.White)
          .placeholderColor('#666666')
          .height(40)
          .layoutWeight(1)
          .borderRadius(20)
          .onChange((val: string) => {
            this.searchKeyword = val;
            if (val.length === 0) { this.searchResults = []; }
          })
          .onSubmit(() => { this.doSearch(); });

        Button('搜索')
          .backgroundColor('#4ea1ff').fontColor(Color.White)
          .height(40).borderRadius(20).fontSize(14)
          .margin({ left: 8 })
          .onClick(() => { this.doSearch(); });
      }
      .width('100%').padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint), top: 12, bottom: 8 });

      if (this.searchResults.length === 0 && this.searchKeyword.length > 0) {
        Column() {
          Text('暂无搜索结果').fontColor('#666666').fontSize(14).margin({ top: 80 });
        }.width('100%').layoutWeight(1);
      } else if (this.searchResults.length > 0) {
        List({ space: getListSpace(this.currentBreakpoint) }) {
          ForEach(this.searchResults, (item: BookmarkItem, idx: number) => {
            ListItem() {
              Column() {
                if (item.thumbnailPath && item.thumbnailPath.length > 0) {
                  Image(item.thumbnailPath).width('100%').height(getCoverHeight(this.currentBreakpoint))
                    .objectFit(ImageFit.Cover).borderRadius({ topLeft: 12, topRight: 12 });
                } else {
                  Column() {
                    Text('🎬').fontSize(32)
                  }
                  .width('100%').height(getCoverHeight(this.currentBreakpoint)).borderRadius({ topLeft: 12, topRight: 12 })
                  .backgroundColor('#2a2a2a').justifyContent(FlexAlign.Center);
                }
                Text(item.title).fontColor(Color.White).fontSize(getFontSize(this.currentBreakpoint, 13))
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 8 });
              }
              .width('100%').backgroundColor('#2a2a2a').borderRadius(12)
              .onClick(() => {
                let vd: VideoData = { name: item.title, type: item.videoType, videoSrc: item.url,
                  description: '', caption: '', index: 0 };
                this.playVideo(vd);
              });
            }
          }, (item: BookmarkItem, idx: number) => `sr_${idx}_${item.url}`);
        }
        .width('100%').layoutWeight(1).padding({ left: getPadding(this.currentBreakpoint), right: getPadding(this.currentBreakpoint) });
      } else {
        Column() {
          Text('输入关键字搜索视频').fontColor('#555555').fontSize(14).margin({ top: 80 });
        }.width('100%').layoutWeight(1);
      }
    }
    .layoutWeight(1).backgroundColor('#1a1a1a').padding({ top: 12 });
  }

  doSearch(): void {
    let kw = this.searchKeyword.trim().toLowerCase();
    if (kw.length === 0) { this.searchResults = []; return; }
    this.searchResults = this.bookmarks.filter((item: BookmarkItem) => {
      return item.title.toLowerCase().includes(kw);
    });
    // Also search local videos
    for (let lv of this.localVideos) {
      if (lv.name.toLowerCase().includes(kw)) {
        let found = false;
        for (let sr of this.searchResults) {
          if (sr.url === lv.uri) { found = true; break; }
        }
        if (!found) {
          this.searchResults.push({
            url: lv.uri, title: lv.name, videoType: VideoDataType.RAW_FILE,
            thumbnailPath: '', addedTime: 0
          });
        }
      }
    }
    if (this.searchResults.length === 0) {
      promptAction.showToast({ message: '未搜索到内容', duration: 2000 });
    }
  }

  // ─── Network Video Dialog ──────────────────────────

  @Builder
  NetworkVideoDialog() {
    Column() {
      // Header: 返回 + 网络视频
      Row() {
        Text('←').fontColor(Color.White).fontSize(22)
          .onClick(() => { this.showNetworkDialog = false; });
        Text('网络视频').fontColor(Color.White).fontSize(18).fontWeight(600).margin({ left: 12 });
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 });

      // Input + 播放按钮
      Row() {
        TextInput({ placeholder: '请输入网页链接进行播放', text: this.networkUrl })
          .backgroundColor('#2a2a2a').fontColor(Color.White).placeholderColor('#666666')
          .height(44).layoutWeight(1).borderRadius(8)
          .onChange((val: string) => { this.networkUrl = val; });

        Button('播放')
          .backgroundColor('#4ea1ff').fontColor(Color.White)
          .height(44).borderRadius(8).fontSize(15)
          .margin({ left: 10 })
          .onClick(() => { this.playNetworkUrl(); });
      }
      .width('100%').padding({ left: 16, right: 16 });

      Blank();
    }
    .width('100%').height('100%').backgroundColor('#1a1a1a');
  }

  playNetworkUrl(): void {
    if (this.networkUrl.trim().length === 0) {
      this.showToast('请输入有效的链接');
      return;
    }
    let regex = new RegExp('^(http|https)', 'i');
    if (!regex.test(this.networkUrl.trim())) {
      this.showToast('该链接无法播放，请检查链接是否正确。');
      return;
    }
    this.showNetworkDialog = false;
    let lowerUrl = this.networkUrl.trim().toLowerCase();
    let videoType = VideoDataType.URL;
    if (lowerUrl.includes('bilibili.com/video/') ||
        lowerUrl.includes('b23.tv/') ||
        (lowerUrl.includes('bilibili.com') && (lowerUrl.includes('/bv') || lowerUrl.includes('/av')))) {
      videoType = VideoDataType.BILIBILI_URL;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `Bilibili URL detected: ${this.networkUrl}`);
    }
    let vd: VideoData = {
      name: '网络视频', type: videoType, videoSrc: this.networkUrl.trim(),
      description: '', caption: '', index: 0
    };
    this.playVideo(vd);
  }

  showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (e) {
      console.error('showToast failed');
    }
  }

  // ─── Local Video Picker ────────────────────────────

  async pickLocalVideos(): Promise<void> {
    try {
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      photoSelectOptions.maxSelectNumber = 20;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      let result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(photoSelectOptions);
      if (result.photoUris.length > 0) {
        let newVideos: LocalVideoItem[] = [];
        for (let uri of result.photoUris) {
          let name = uri.substring(uri.lastIndexOf('/') + 1);
          // Decode URI-encoded name
          try {
            name = decodeURIComponent(name);
          } catch (e) { /* keep original */ }
          // Prevent duplicates
          let dup = false;
          for (let v of this.localVideos) {
            if (v.uri === uri) { dup = true; break; }
          }
          if (!dup) { newVideos.push({ name: name, uri: uri, size: '' }); }
        }
        this.localVideos = this.localVideos.concat(newVideos);
      }
    } catch (e) {
      console.error('pickLocalVideos failed');
    }
  }

  // ─── Player Map ────────────────────────────────────

  @Builder
  PagesMap(name: string) {
    if (name === 'UrlPlayer') {
      UrlPlayer();
    }
  }

  // ─── Main Build ────────────────────────────────────

  build() {
    Navigation(this.pageStack) {
      Column() {
        // Banner
        this.BannerBuilder();

        // Page content
        if (this.showNetworkDialog) {
          this.NetworkVideoDialog();
        } else if (this.currentTab === 0) {
          if (this.homeSubPage === 'localVideo') {
            this.LocalVideoPageBuilder();
          } else {
            this.HomePageBuilder();
          }
        } else if (this.currentTab === 1) {
          this.FavoritesPageBuilder();
        } else {
          this.SearchPageBuilder();
        }

        // Bottom TabBar
        Row() {
          this.TabItemBuilder('主页', 0);
          this.TabItemBuilder('收藏', 1);
          this.TabItemBuilder('搜索', 2);
        }
        .width('100%')
        .height(getTabBarHeight(this.currentBreakpoint))
        .backgroundColor('#1a1a1a')
        .border({ width: { top: 0.5 }, color: '#333333' });
      }
      .width('100%').height('100%');
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.PagesMap)
    .hideTitleBar(true)
    .backgroundColor('#1a1a1a')
    .onMouse((event: MouseEvent) => {
      this.updateResizeCursor(event.x, event.y);
    });
  }

  @Builder
  TabItemBuilder(label: string, tabIdx: number) {
    Column() {
      if (tabIdx === 0) {
        Text('🏠').fontSize(getTabIconSize(this.currentBreakpoint));
      } else if (tabIdx === 1) {
        Text('⭐').fontSize(getTabIconSize(this.currentBreakpoint));
      } else {
        Text('🔍').fontSize(getTabIconSize(this.currentBreakpoint));
      }
      Text(label)
        .fontSize(getTabLabelSize(this.currentBreakpoint))
        .fontColor(this.currentTab === tabIdx ? '#4ea1ff' : '#888888')
        .margin({ top: 3 });
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .opacity(this.currentTab === tabIdx ? 1.0 : 0.55)
    .onClick(() => { this.currentTab = tabIdx; this.homeSubPage = ''; });
  }

  // ─── Cursor Resize ─────────────────────────────────

  private updateResizeCursor(mouseX: number, mouseY: number): void {
    let nearLeft = mouseX <= this.EDGE_THRESHOLD;
    let nearRight = mouseX >= this.windowWidthVp - this.EDGE_THRESHOLD;
    let nearTop = mouseY <= this.EDGE_THRESHOLD;
    let nearBottom = mouseY >= this.windowHeightVp - this.EDGE_THRESHOLD;
    if (nearTop && nearLeft) {
      this.cursorController.setCursor(pointer.PointerStyle.NORTH_WEST_SOUTH_EAST);
    } else if (nearTop && nearRight) {
      this.cursorController.setCursor(pointer.PointerStyle.NORTH_EAST_SOUTH_WEST);
    } else if (nearBottom && nearLeft) {
      this.cursorController.setCursor(pointer.PointerStyle.NORTH_EAST_SOUTH_WEST);
    } else if (nearBottom && nearRight) {
      this.cursorController.setCursor(pointer.PointerStyle.NORTH_WEST_SOUTH_EAST);
    } else if (nearLeft || nearRight) {
      this.cursorController.setCursor(pointer.PointerStyle.WEST_EAST);
    } else if (nearTop || nearBottom) {
      this.cursorController.setCursor(pointer.PointerStyle.NORTH_SOUTH);
    } else {
      this.cursorController.restoreDefault();
    }
  }
}

// ─── Responsive Helpers ────────────────────────────

function getFontSize(bp: string, base: number): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return base + 4; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return base + 2; }
  return base;
}

function getPadding(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 32; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 24; }
  return 16;
}

function getListSpace(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 14; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 12; }
  return 10;
}

function getCoverHeight(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 200; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 160; }
  return 130;
}

function getTabBarHeight(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 80; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 72; }
  return 64;
}

function getTabIconSize(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 34; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 30; }
  return 26;
}

function getTabLabelSize(bp: string): number {
  if (bp === BreakpointConstants.BREAKPOINT_LG || bp === BreakpointConstants.BREAKPOINT_XL) { return 15; }
  if (bp === BreakpointConstants.BREAKPOINT_MD) { return 14; }
  return 12;
}
