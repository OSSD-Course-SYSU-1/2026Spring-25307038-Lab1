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

import { common } from '@kit.AbilityKit';
import { BookmarkStore } from '../services/BookmarkStore';
import { BookmarkItem } from '../model/BookmarkModel';
import { VideoData } from '../model/VideoData';

@Component
export struct BookmarkPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State bookmarks: BookmarkItem[] = [];
  @State isManaging: boolean = false;
  @State selectedUrls: string[] = [];
  @State showDeleteConfirm: boolean = false;
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';
  private bookmarkStore: BookmarkStore = BookmarkStore.getInstance();
  private uiAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadBookmarks();
  }

  async loadBookmarks(): Promise<void> {
    try {
      await this.bookmarkStore.init(this.uiAbilityContext);
      this.bookmarks = this.bookmarkStore.getAll();
    } catch (e) {
      console.error(`[BookmarkPage] loadBookmarks失败: ${JSON.stringify(e)}`);
    }
  }

  playBookmark(item: BookmarkItem): void {
    if (this.isManaging) {
      return;
    }
    let videoData: VideoData = {
      name: item.title,
      type: item.videoType,
      videoSrc: item.url,
      description: '',
      caption: '',
      index: 0
    };
    this.pageStack.pushPathByName('UrlPlayer', videoData);
  }

  toggleSelect(url: string): void {
    const idx = this.selectedUrls.indexOf(url);
    if (idx >= 0) {
      const newUrls: string[] = [];
      for (let i = 0; i < this.selectedUrls.length; i++) {
        if (i !== idx) {
          newUrls.push(this.selectedUrls[i]);
        }
      }
      this.selectedUrls = newUrls;
    } else {
      const newUrls: string[] = [];
      for (let i = 0; i < this.selectedUrls.length; i++) {
        newUrls.push(this.selectedUrls[i]);
      }
      newUrls.push(url);
      this.selectedUrls = newUrls;
    }
  }

  isSelected(url: string): boolean {
    for (let i = 0; i < this.selectedUrls.length; i++) {
      if (this.selectedUrls[i] === url) {
        return true;
      }
    }
    return false;
  }

  enterManage(): void {
    this.isManaging = true;
    this.selectedUrls = [];
  }

  exitManage(): void {
    this.isManaging = false;
    this.selectedUrls = [];
    this.showDeleteConfirm = false;
  }

  async batchDelete(): Promise<void> {
    const urlsToDelete: string[] = [];
    for (let i = 0; i < this.selectedUrls.length; i++) {
      urlsToDelete.push(this.selectedUrls[i]);
    }
    for (let i = 0; i < urlsToDelete.length; i++) {
      await this.bookmarkStore.remove(urlsToDelete[i]);
    }
    this.selectedUrls = [];
    await this.loadBookmarks();
    if (this.bookmarks.length === 0) {
      this.isManaging = false;
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // Top bar
          Row() {
            Row() {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
                .onClick(() => {
                  this.pageStack.pop();
                })

              Text('返回')
                .fontColor(Color.White)
                .fontSize(18)
                .fontWeight(600)
                .margin({ left: 8 })
            }

            Blank()

            Text(`${this.bookmarks.length}个视频`)
              .fontColor(Color.White)
              .fontSize(18)
              .fontWeight(600)

            Blank()

            Text(this.isManaging ? '完成' : '管理')
              .fontColor(Color.White)
              .fontSize(this.isManaging ? 20 : 16)
              .padding({ left: 12, right: 4, top: 6, bottom: 6 })
              .onClick(() => {
                if (this.isManaging) {
                  this.exitManage();
                } else {
                  this.enterManage();
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 36, bottom: 12 })

          // Content
          if (this.bookmarks.length === 0) {
            Column() {
              Text('暂无收藏')
                .fontColor('#666666')
                .fontSize(16)
                .margin({ top: 100 })
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            List({ space: 10 }) {
              ForEach(this.bookmarks, (item: BookmarkItem, idx: number) => {
                ListItem() {
                  Row() {
                    // Cover
                    if (item.thumbnailPath && item.thumbnailPath.length > 0) {
                      Image(item.thumbnailPath)
                        .height('100%')
                        .width(120)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(16)
                    } else {
                      Image($r('app.media.arrow_up_circle_fill'))
                        .height('100%')
                        .width(120)
                        .objectFit(ImageFit.Fill)
                        .borderRadius(16)
                    }

                    Column() {
                      Text(item.title)
                        .fontColor(Color.White)
                        .fontSize(16)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')

                      Text(item.url)
                        .fontColor('#999999')
                        .fontSize(12)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .margin({ top: 4 })
                    }
                    .margin({ left: 10 })
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    // Custom checkbox in management mode
                    if (this.isManaging) {
                      Row() {
                        if (this.isSelected(item.url)) {
                          Text('✓')
                            .fontColor(Color.White)
                            .fontSize(14)
                            .fontWeight(700)
                        }
                      }
                      .width(22)
                      .height(22)
                      .borderRadius(4)
                      .border({ width: 2, color: this.isSelected(item.url) ? '#ff4444' : '#666666' })
                      .backgroundColor(this.isSelected(item.url) ? '#ff4444' : 'transparent')
                      .justifyContent(FlexAlign.Center)
                      .margin({ left: 8 })
                    }
                  }
                  .height(80)
                  .width('100%')
                  .padding({ right: this.isManaging ? 8 : 0 })
                  .onClick(() => {
                    if (this.isManaging) {
                      this.toggleSelect(item.url);
                    } else {
                      this.playBookmark(item);
                    }
                  })
                }
              }, (item: BookmarkItem, idx: number) => `bm_${idx}_${item.url}`)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ bottom: this.isManaging ? 60 : 0 })
          }
        }
        .width('100%')
        .height('100%')

        // Batch delete button
        if (this.isManaging) {
          Button(this.selectedUrls.length > 0 ? `删除(${this.selectedUrls.length})` : '删除')
            .backgroundColor('#ff4444')
            .fontColor(Color.White)
            .fontSize(18)
            .borderRadius(24)
            .padding({ left: 24, right: 24, top: 10, bottom: 10 })
            .margin({ right: 20, bottom: 20 })
            .opacity(this.selectedUrls.length > 0 ? 1.0 : 0.4)
            .enabled(this.selectedUrls.length > 0)
            .onClick(() => {
              if (this.selectedUrls.length > 0) {
                this.showDeleteConfirm = true;
              }
            })
        }

        // Delete confirmation dialog overlay - centered
        if (this.showDeleteConfirm) {
          Stack({ alignContent: Alignment.Center }) {
            // Semi-transparent backdrop
            Column() {}
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.6)')
            .onClick(() => {
              this.showDeleteConfirm = false;
            })

            // Dialog card
            Column() {
              Text(`确定删除所选中的${this.selectedUrls.length}个视频吗`)
                .fontColor('#cccccc')
                .fontSize(16)
                .padding({ top: 24, bottom: 20, left: 20, right: 20 })

              Divider()
                .color('#333333')
                .width('100%')

              Row() {
                Button('我再想想')
                  .backgroundColor(Color.White)
                  .fontColor('#333333')
                  .fontSize(16)
                  .layoutWeight(1)
                  .height(44)
                  .type(ButtonType.Normal)
                  .borderRadius(0)
                  .onClick(() => {
                    this.showDeleteConfirm = false;
                  })

                Divider()
                  .vertical(true)
                  .color('#333333')
                  .height(44)

                Button('确定')
                  .backgroundColor('#ff4444')
                  .fontColor(Color.White)
                  .fontSize(16)
                  .layoutWeight(1)
                  .height(44)
                  .type(ButtonType.Normal)
                  .borderRadius(0)
                  .onClick(() => {
                    this.showDeleteConfirm = false;
                    this.batchDelete();
                  })
              }
              .width('100%')
            }
            .width(this.currentBreakpoint === 'sm' ? '85%' :
                   (this.currentBreakpoint === 'md' ? '28%' : '20%'))
            .backgroundColor('#2a2a2a')
            .borderRadius(12)
          }
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor('#1a1a1a')
  }
}
