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
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { VideoData } from '../model/VideoData';
import { AVPlayerState, CommonConstants, VideoDataType } from '../common/constants/CommonConstants';
import { CaptionFont, SubtitleConstants } from '../model/SubtitleConfig';

const TAG = '[AvPlayerController]';
const CASE_ZERO = 0;
const CASE_ONE = 1;
const CASE_TWO = 2;
const CASE_THREE = 3;
const CASE_FOUR = 4;
const CASE_FIVE = 5;

class BilibiliViewData {
  cid: number = 0;
}

class BilibiliViewResponse {
  code: number = 0;
  message: string = '';
  data: BilibiliViewData = new BilibiliViewData();
}

class BilibiliDurlItem {
  url: string = '';
}

class BilibiliDashVideoItem {
  baseUrl: string = '';
  base_url: string = '';
}

class BilibiliDashData {
  video: BilibiliDashVideoItem[] = [];
}

class BilibiliPlayurlData {
  durl: BilibiliDurlItem[] = [];
  dash: BilibiliDashData = new BilibiliDashData();
}

class BilibiliPlayurlResponse {
  code: number = 0;
  message: string = '';
  data: BilibiliPlayurlData = new BilibiliPlayurlData();
}

@Observed
export class AvPlayerController {
  @Track surfaceID: string = '';
  @Track isPlaying: boolean = false;
  @Track isReady: boolean = false;
  @Track currentTime: number = 0;
  @Track currentBufferTime: number = 0;
  @Track isLoading: boolean = false;
  @Track duration: number = 0;
  @Track durationTime: number = 0;
  @Track currentCaption: string = '';
  @Track hasCaption: boolean = false;
  @Track captionFont: CaptionFont = SubtitleConstants.DEFAULT_CAPTION_FONT;
  @Track playbackError: boolean = false;
  @Track errorMessage: string = '';
  @Track availableBitrates: number[] = [];
  @Track currentBitrateIndex: number = 0;
  @Track showQualitySelector: boolean = false;
  @Track currentBitrateLabel: string = '自动';
  private avPlayer?: media.AVPlayer;
  private curSource?: VideoData;
  private context: common.UIAbilityContext | undefined = AppStorage.get('context');
  private seekTime?: number;
  private isMuted: boolean | undefined = undefined;
  private speedSelect: number = 2; // Default to 1.0X speed (index 2), matching UI default
  private windowScaleSelect: number = 0;
  private index: number = 0;

  // [Start online_url_2]
  // [Start online_url_1]
  // [Start cache_bar_1]
  // [Start set_source_1]
  // [Start set_source_2]
  // [Start set_strategy_1]
  // Create an AVPlayer instance
  public async initAVPlayer(source: VideoData, surfaceId: string) {
    // [StartExclude online_url_2]
    // [StartExclude online_url_1]
    // [StartExclude set_strategy_1]
    // [StartExclude cache_bar_1]
    // [StartExclude set_source_1]
    // [StartExclude set_source_2]
    if (!this.context) {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer failed context not set`);
      return
    }
    this.curSource = source;
    if (source.seekTime) {
      this.seekTime = source.seekTime;
    }
    if (source.isMuted) {
      this.isMuted = source.isMuted;
    }
    if (source.index) {
      this.index = source.index;
    }
    hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer == this.curSource : ${JSON.stringify(this.curSource)}`);
    if (!this.curSource) {
      return;
    }
    hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer == initCamera surfaceId == ${surfaceId}`);
    this.surfaceID = surfaceId;
    hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer == this.surfaceID surfaceId == ${this.surfaceID}`);

    // [EndExclude set_source_2]
    // [EndExclude set_source_1]
    // [EndExclude cache_bar_1]
    // [EndExclude online_url_1]
    // [EndExclude set_strategy_1]
    // [EndExclude online_url_2]
    try {
      // [StartExclude set_source_2]
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'initPlayer videoPlay avPlayerDemo');
      // Creates the avPlayer instance object.
      this.avPlayer = await media.createAVPlayer();
      // [StartExclude online_url_1]
      // Creates a callback function for state machine changes.
      this.setAVPlayerCallback();
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'initPlayer videoPlay setAVPlayerCallback');

      if (!this.context) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, `initPlayer failed context not set`);
        return
      }
      // [EndExclude set_source_2]
      switch (this.curSource.type) {
        // [StartExclude online_url_2]
        // [StartExclude set_strategy_1]
        // [StartExclude cache_bar_1]
        // [StartExclude set_source_1]
        // [StartExclude set_source_2]
        case VideoDataType.RAW_FILE:
          let fileDescriptor = await this.context.resourceManager.getRawFd(this.curSource.videoSrc);
          this.avPlayer.fdSrc = fileDescriptor;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `initPlayer videoPlay src = ${JSON.stringify(this.avPlayer.fdSrc)}`);
          break;
        // [EndExclude online_url_2]
        // [EndExclude set_strategy_1]
        // [EndExclude cache_bar_1]
        // Set online video source by url
        case VideoDataType.URL:
          this.avPlayer.url = this.curSource.videoSrc;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `initPlayer videoPlay url = ${JSON.stringify(this.avPlayer.url)}`);
          break;
        // Set Bilibili video source with custom headers
        case VideoDataType.BILIBILI_URL:
          await this.setBilibiliVideoSource();
          break;
        // [StartExclude set_strategy_1]
        // [StartExclude cache_bar_1]
        // [EndExclude set_source_1]
        // [EndExclude set_source_2]
        // Set the mediaSource by url with playbackStrategy
        case VideoDataType.RAW_M3U8_FILE:
          let m3u8Fd = await this.context.resourceManager.getRawFd(this.curSource.videoSrc);
          let fdUrl = 'fd://' + m3u8Fd.fd + '?offset=' + m3u8Fd.offset + '&size=' + m3u8Fd.length;
          // create mediaSource by the URL instead of an assigned URL
          let mediaSource = media.createMediaSourceWithUrl(fdUrl);
          mediaSource.setMimeType(media.AVMimeTypes.APPLICATION_M3U8);
          // [StartExclude set_source_1]
          // create PlaybackStrategy
          let playbackStrategy: media.PlaybackStrategy = { preferredBufferDuration: 20, showFirstFrameOnPrepare: true };
          await this.avPlayer.setMediaSource(mediaSource, playbackStrategy);
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer videoPlay fdUrl = ${JSON.stringify(fdUrl)}`);
          break;
        // [StartExclude set_source_2]
        // Set local video source by url
        case VideoDataType.RAW_MP4_FILE:
          let mp4Fd = await this.context.resourceManager.getRawFd(this.curSource.videoSrc);
          let mp4FdUrl = 'fd://' + mp4Fd.fd;
          this.avPlayer.url = mp4FdUrl;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer videoPlay fdUrl = ${JSON.stringify(mp4FdUrl)}`);
          break;

        default:
          hilog.error(CommonConstants.LOG_DOMAIN, TAG, `initPlayer failed VideoDataType is invalid`);
          break;
        // [EndExclude set_strategy_1]
        // [EndExclude cache_bar_1]
        // [EndExclude set_source_1]
        // [EndExclude set_source_2]
      }
      await this.setCaption();
      // [EndExclude online_url_1]
    } catch (err) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG,
        `initPlayer initPlayer, code is ${err.code}, message is ${err.message}`);
      this.playbackError = true;
      this.errorMessage = '该链接无法播放';
      emitter.emit(CommonConstants.AVPLAYER_ERROR, {
        data: { message: '该链接无法播放' }
      });
    }

  }
  // [End online_url_1]
  // [End online_url_2]
  // [End set_strategy_1]
  // [End cache_bar_1]
  // [End set_source_1]
  // [End set_source_2]

  private async setBilibiliVideoSource() {
    hilog.info(CommonConstants.LOG_DOMAIN, TAG, '[BiliSrc] ===== setBilibiliVideoSource START =====');

    if (!this.avPlayer) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliSrc] ❌ avPlayer is null');
      return;
    }

    if (!this.curSource) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliSrc] ❌ curSource is null');
      return;
    }

    if (!this.curSource.videoSrc) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliSrc] ❌ videoSrc is null or empty');
      return;
    }

    try {
      const bilibiliUrl = this.curSource.videoSrc;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliSrc] Input URL: ${bilibiliUrl}`);
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliSrc] Video type enum: ${this.curSource.type}`);

      // Extract BV号 from Bilibili URL
      let bvId = this.extractBvId(bilibiliUrl);
      if (!bvId) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `[BiliSrc] ❌ Cannot extract BV id from URL, falling back to direct URL`);
        this.avPlayer.url = bilibiliUrl;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliSrc] Set avPlayer.url directly`);
        return;
      }

      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliSrc] ✅ Extracted BV=${bvId}`);

      // Try to get video stream URL from Bilibili API
      let videoStreamUrl = await this.getBilibiliVideoStreamUrl(bvId);

      if (videoStreamUrl) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `[BiliSrc] ✅ Got stream URL, creating media source with Referer header...`);
        // Create media source with Bilibili headers - CDN requires Referer to serve video
        let mediaSource = media.createMediaSourceWithUrl(videoStreamUrl, {
          'Referer': 'https://www.bilibili.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        });

        let playbackStrategy: media.PlaybackStrategy = {
          preferredBufferDuration: 20,
          showFirstFrameOnPrepare: true
        };
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `[BiliSrc] Calling avPlayer.setMediaSource()...`);
        await this.avPlayer.setMediaSource(mediaSource, playbackStrategy);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, '[BiliSrc] ✅ setMediaSource succeeded');
      } else {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          '[BiliSrc] ❌ Failed to get Bilibili video stream URL');
        this.playbackError = true;
        this.errorMessage = '该链接无法播放';
        emitter.emit(CommonConstants.AVPLAYER_ERROR, {
          data: { message: '该链接无法播放' }
        });
      }
    } catch (err) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG,
        `[BiliSrc] ❌ Exception: code=${err.code}, message=${err.message}`);
      this.playbackError = true;
      this.errorMessage = '该链接无法播放';
      emitter.emit(CommonConstants.AVPLAYER_ERROR, {
        data: { message: '该链接无法播放' }
      });
    }
  }

  private extractBvId(url: string): string | null {
    try {
      // Match BV id in Bilibili URL
      // Example: https://www.bilibili.com/video/BV1ewdhBmEux/
      const bvRegex = /\/video\/(BV[a-zA-Z0-9]+)/i;
      const match = url.match(bvRegex);
      if (match && match[1]) {
        return match[1];
      }
      
      // Also support short URL format
      const shortRegex = /\/video\/(av\d+)/i;
      const shortMatch = url.match(shortRegex);
      if (shortMatch && shortMatch[1]) {
        return shortMatch[1];
      }
      
      return null;
    } catch (err) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, `extractBvId error: ${err.message}`);
      return null;
    }
  }

  private async getBilibiliVideoStreamUrl(bvId: string): Promise<string | null> {
    try {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ========== STEP 1: Get cid for BV=${bvId} ==========`);

      // Step 1: Get video info (cid) from Bilibili API
      const viewUrl: string = `https://api.bilibili.com/x/web-interface/view?bvid=${bvId}`;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] Calling view API...`);
      const viewResponse: string | null = await this.fetchWithHeaders(viewUrl);
      if (!viewResponse) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ❌ view API returned no response');
        return null;
      }
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ✅ view API responded');

      const viewDataObj: Object = JSON.parse(viewResponse);
      const viewData: BilibiliViewResponse = viewDataObj as BilibiliViewResponse;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `[BiliAPI] viewData.code=${viewData.code}, message=${viewData.message}`);
      if (viewData.code !== 0) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `[BiliAPI] ❌ view API error: code=${viewData.code}, message=${viewData.message}`);
        return null;
      }

      const cid: number | undefined = viewData?.data?.cid;
      if (!cid) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ❌ Cannot extract cid from view API response');
        return null;
      }
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ✅ Got cid=${cid}`);

      // Step 2: Get playurl - try HLS format first (fnval=4048, fMP4/M3U8, combined audio+video)
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ========== STEP 2: Get playurl (fnval=4048, HLS) ==========`);
      const hlsUrl: string = `https://api.bilibili.com/x/player/playurl?bvid=${bvId}&cid=${cid}&qn=80&fnval=4048&fnver=0&fourk=1`;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] Calling playurl API (fnval=4048)...`);
      const hlsResponse: string | null = await this.fetchWithHeaders(hlsUrl);

      if (hlsResponse) {
        const hlsDataObj: Object = JSON.parse(hlsResponse);
        const hlsData: BilibiliPlayurlResponse = hlsDataObj as BilibiliPlayurlResponse;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] playurl(fnval=4048) code=${hlsData.code}, message=${hlsData.message}`);
        if (hlsData.code === 0) {
          // HLS returns a single M3U8 URL with combined audio+video via durl
          const durl: BilibiliDurlItem[] | undefined = hlsData?.data?.durl;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] HLS durl count=${durl ? durl.length : 'undefined'}`);
          if (durl && durl.length > 0 && durl[0].url) {
            hilog.info(CommonConstants.LOG_DOMAIN, TAG,
              `[BiliAPI] ✅ Got HLS M3U8 URL: ${durl[0].url.substring(0, 100)}...`);
            return durl[0].url;
          }
        } else {
          hilog.warn(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] ⚠️ playurl(fnval=4048) failed: code=${hlsData.code}, msg=${hlsData.message}`);
        }
      } else {
        hilog.warn(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ⚠️ playurl(fnval=4048) no response');
      }

      // Step 3: Fallback - try DASH format (fnval=16, MP4 segments)
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ========== STEP 3: Get playurl (fnval=16, DASH) ==========`);
      const dashUrl: string = `https://api.bilibili.com/x/player/playurl?bvid=${bvId}&cid=${cid}&qn=80&fnval=16&fnver=0&fourk=1`;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] Calling playurl API (fnval=16)...`);
      const dashResponse: string | null = await this.fetchWithHeaders(dashUrl);

      if (dashResponse) {
        const dashDataObj: Object = JSON.parse(dashResponse);
        const dashData: BilibiliPlayurlResponse = dashDataObj as BilibiliPlayurlResponse;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] playurl(fnval=16) code=${dashData.code}, message=${dashData.message}`);
        if (dashData.code === 0) {
          const dash: BilibiliDashData | undefined = dashData?.data?.dash;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] dash.video count=${dash?.video ? dash.video.length : 'undefined'}`);
          if (dash && dash.video && dash.video.length > 0) {
            const firstVideo: BilibiliDashVideoItem = dash.video[0];
            const dashVideoUrl: string = firstVideo.baseUrl || firstVideo.base_url;
            if (dashVideoUrl) {
              hilog.info(CommonConstants.LOG_DOMAIN, TAG,
                `[BiliAPI] ⚠️ Got DASH video-only URL (no audio in DASH): ${dashVideoUrl.substring(0, 100)}...`);
              // DASH returns video-only streams — skip and fall through to progressive for audio
              hilog.warn(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ⚠️ DASH has no audio — falling back to progressive');
            } else {
              hilog.warn(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ⚠️ dash.video[0] has no URL — falling back to progressive');
            }
          } else {
            hilog.warn(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ⚠️ No video streams in dash — falling back to progressive');
          }
        } else {
          hilog.warn(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] ⚠️ playurl(fnval=16) failed: code=${dashData.code}, msg=${dashData.message}`);
        }
      } else {
        hilog.warn(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ⚠️ playurl(fnval=16) no response — falling back to progressive');
      }

      // Step 4: Last resort - progressive format (fnval=1, combined av, may be FLV)
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ========== STEP 3: Get playurl (fnval=1, progressive) ==========`);
      const playUrl: string = `https://api.bilibili.com/x/player/playurl?bvid=${bvId}&cid=${cid}&qn=80&fnval=1&fnver=0&fourk=1`;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] Calling playurl API (fnval=1)...`);
      const playResponse: string | null = await this.fetchWithHeaders(playUrl);

      if (playResponse) {
        const playDataObj: Object = JSON.parse(playResponse);
        const playData: BilibiliPlayurlResponse = playDataObj as BilibiliPlayurlResponse;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] playurl(fnval=1) code=${playData.code}, message=${playData.message}`);
        if (playData.code === 0) {
          const durl: BilibiliDurlItem[] | undefined = playData?.data?.durl;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] durl count=${durl ? durl.length : 'undefined'}`);
          if (durl && durl.length > 0 && durl[0].url) {
            hilog.info(CommonConstants.LOG_DOMAIN, TAG,
              `[BiliAPI] ✅ Got progressive URL: ${durl[0].url.substring(0, 100)}...`);
            return durl[0].url;
          } else {
            hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ❌ durl was empty/null');
          }
        } else {
          hilog.error(CommonConstants.LOG_DOMAIN, TAG,
            `[BiliAPI] ❌ playurl(fnval=1) failed: code=${playData.code}, msg=${playData.message}`);
        }
      } else {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ❌ playurl(fnval=1) no response');
      }

      hilog.error(CommonConstants.LOG_DOMAIN, TAG, '[BiliAPI] ❌❌❌ Failed to get any video stream URL');
      return null;
    } catch (err) {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, `[BiliAPI] ❌ Exception: ${err.message}`);
      return null;
    }
  }

  private async fetchWithHeaders(url: string): Promise<string | null> {
    return new Promise<string | null>((resolve) => {
      const httpRequest = http.createHttp();
      const shortUrl: string = url.substring(0, 80) + '...';
      hilog.debug(CommonConstants.LOG_DOMAIN, TAG, `[HTTP] >>> GET ${shortUrl}`);

      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://www.bilibili.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        connectTimeout: 15000,
        readTimeout: 15000
      }, (err, data) => {
        if (!err && data) {
          hilog.debug(CommonConstants.LOG_DOMAIN, TAG,
            `[HTTP] responseCode=${data.responseCode}, resultType=${typeof data.result}`);

          if (data.responseCode !== 200) {
            hilog.error(CommonConstants.LOG_DOMAIN, TAG,
              `[HTTP] Non-200 response: code=${data.responseCode}`);
            resolve(null);
          } else if (typeof data.result === 'string') {
            // Some result might be ArrayBuffer for 302 redirects
            const preview: string = (data.result as string).substring(0, 200);
            hilog.debug(CommonConstants.LOG_DOMAIN, TAG, `[HTTP] Body preview: ${preview}`);
            resolve(data.result as string);
          } else if (data.result instanceof ArrayBuffer) {
            hilog.error(CommonConstants.LOG_DOMAIN, TAG,
              `[HTTP] Got ArrayBuffer instead of string (possible redirect), length=${data.result.byteLength}`);
            resolve(null);
          } else {
            hilog.error(CommonConstants.LOG_DOMAIN, TAG,
              `[HTTP] Unexpected result type: ${typeof data.result}`);
            resolve(null);
          }
        } else {
          hilog.error(CommonConstants.LOG_DOMAIN, TAG,
            `[HTTP] FAILED: ${err ? `code=${err.code} msg=${err.message}` : 'no data'}`);
          resolve(null);
        }
        httpRequest.destroy();
      });
    });
  }

  private async setCaption(){
    // [Start AddCaption]
    this.hasCaption = false;
    if (this.curSource?.caption && this.context?.resourceManager && this.avPlayer) {
      try {
        let fileDescriptorSub = await this.context.resourceManager.getRawFd(this.curSource.caption);
        this.avPlayer.addSubtitleFromFd(fileDescriptorSub.fd, fileDescriptorSub.offset, fileDescriptorSub.length);
        this.hasCaption = true;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'initPlayer videoPlay addSubtitleFromFd');
      } catch (err) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `setCaption addSubtitleFromFd failed, code is ${err.code}, message is ${err.message}`);
        this.hasCaption = false;
      }
    }
    // [Start AddCaption]
  }
  // [Start cache_bar_2]
  // [Start cache_bar_3]
  private setAVPlayerCallback() {
    // [StartExclude cache_bar_2]
    // [StartExclude cache_bar_3]
    if (!this.avPlayer) {
      return;
    }
    this.avPlayer!.on('error', (err: BusinessError) => {
      hilog.error(CommonConstants.LOG_DOMAIN, TAG, `AVPlayer error, code is ${err.code}, message is ${err.message}`);
      this.playbackError = true;
      this.errorMessage = '该链接无法播放';
      emitter.emit(CommonConstants.AVPLAYER_ERROR, {
        data: { message: '该链接无法播放' }
      });
      this.avPlayer!.reset();
    });
    // Listening function for reporting time
    this.avPlayer!.on('startRenderFrame', () => {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `AVPlayer start render frame`);
      AppStorage.setOrCreate('StartRender', true);
    });
    this.avPlayer!.on('durationUpdate', (time: number) => {
      this.duration = time;
      hilog.info(CommonConstants.LOG_DOMAIN, TAG, `AVPlayer duration update: ${time}`);
      AppStorage.setOrCreate('DurationTime', time);
    });
    // [EndExclude cache_bar_2]
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.currentTime = time;
      AppStorage.setOrCreate('CurrentTime', time);
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `setAVPlayerCallback timeUpdate success,and new time is = ${this.currentTime}`);
    });
    // [StartExclude cache_bar_2]

    // The error callback function is triggered when an error occurs during avPlayer operations,
    // at which point the reset interface is called to initiate the reset process
    this.avPlayer.on('error', (err: BusinessError) => {
      if (!this.avPlayer) {
        return;
      }
      hilog.error(CommonConstants.LOG_DOMAIN, TAG,
        `Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      this.playbackError = true;
      this.errorMessage = '该链接无法播放';
      emitter.emit(CommonConstants.AVPLAYER_ERROR, {
        data: { message: '该链接无法播放' }
      });
      this.avPlayer.reset(); // resets the resources and triggers the idle state
    })

    // Subtitles mount callback functions
    this.avPlayer.on('subtitleUpdate', (info: media.SubtitleInfo) => {
      if (!!info) {
        let text = (!info.text) ? '' : info.text;
        let startTime = (!info.startTime) ? 0 : info.startTime;
        let duration = (!info.duration) ? 0 : info.duration;
        this.currentCaption = text;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          'subtitleUpdate info:' + ` text:${text},startTime:${startTime},duration:${duration}`);
      } else {
        this.currentCaption = '';
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, 'subtitleUpdate info is null');
      }
    });
    // [EndExclude cache_bar_3]
    // Listen to the streaming media buffer status and the estimated playback duration of the buffered data
    this.avPlayer.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `BufferedProgressBar bufferingUpdate, infoType is ${infoType}, value is ${value}.`);
      // [StartExclude cache_bar_3]
      if (infoType === media.BufferingInfoType.BUFFERING_START) {
        this.isLoading = true;
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        this.isLoading = false;
      }

      if (this.durationTime === 0) {
        return;
      }
      // [EndExclude cache_bar_3]
      if (infoType === media.BufferingInfoType.CACHED_DURATION && this.avPlayer) {
        this.currentBufferTime = Math.max(this.currentBufferTime, this.currentTime + value);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `currentBufferTime: ${this.currentBufferTime}`)
      }
    });

    // [StartExclude cache_bar_3]
    // Listen for available bitrates from the video source
    this.avPlayer.on('availableBitrates', (bitrates: Array<number>) => {
      this.availableBitrates = bitrates;
      this.showQualitySelector = bitrates.length > 0;
    });

    // Listen for bitrate switch completion
    this.avPlayer.on('bitrateDone', (bitrate: number) => {
      const index: number = this.availableBitrates.indexOf(bitrate);
      if (index !== -1) {
        this.currentBitrateIndex = index;
        this.currentBitrateLabel = this.getBitrateLabel(bitrate);
      }
    });

    // [Start RegisterCaptionCallBack]
    this.avPlayer.on('subtitleUpdate', (info: media.SubtitleInfo) => {
      if (!!info) {
        let text = (!info.text) ? '' : info.text;
        let startTime = (!info.startTime) ? 0 : info.startTime;
        let duration = (!info.duration) ? 0 : info.duration;
        this.currentCaption = text; //update current caption content
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `subtitleUpdate info: text:${text},startTime:${startTime},duration:${duration}`);
      } else {
        this.currentCaption = '';
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, 'subtitleUpdate info is null');
      }
    });
    // [End RegisterCaptionCallBack]

    this.setInterruptCallback()
    this.setStateChangeCallback();
    this.setOutputDeviceChangeCallback();
    // [EndExclude cache_bar_2]
    // [EndExclude cache_bar_3]
  }
  // [End cache_bar_2]
  // [End cache_bar_3]

  private setInterruptCallback() {
    if (!this.avPlayer) {
      return;
    }
    this.avPlayer.on('audioInterrupt', async (interruptEvent: audio.InterruptEvent) => {
      // When an audio interruption event occurs, the `audioRenderer` receives the `interruptEvent` callback. Here,
      // handle it based on its content:
      // 1. Optional: Read the type of `interruptEvent.forceType` to determine if the system has already enforced
      // the corresponding action.
      //    Note: Under the default focus strategy, `INTERRUPT_HINT_RESUME` is of type `INTERRUPT_SHARE`, while all
      //    other hint types are of `INTERRUPT_FORCE`.Therefore, checking `forceType` may not be necessary.
      // 2. Required: Read the type of `interruptEvent.hintType` and perform the corresponding handling.
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        // For the INTERRUPT_FORCE type: Audio-related processing has been performed by the system, and the
        // application needs to update its own state and make the corresponding adjustments.
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            // This branch indicates that the system has paused the audio stream (temporarily lost focus).
            // To maintain consistency in state, the application should switch to the audio paused state.
            // Temporarily lost focus: After other audio streams release the audio focus, this audio stream
            // will receive a corresponding resume audio interruption event, at which point it can resume
            // playback on its own.
            this.updateIsPlay(false);
            break;
          case audio.InterruptHint.INTERRUPT_HINT_STOP:
            // This branch indicates that the system has stopped the audio stream (permanently lost focus).
            // To maintain consistency in state, the application should switch to the audio paused state.
            // Permanently lost focus: No further audio interruption events will be received. To resume
            // playback, user intervention is required.
            this.updateIsPlay(false);
            break;
          case audio.InterruptHint.INTERRUPT_HINT_DUCK:
            // This branch indicates that the system has reduced the audio volume (default to 20% of the normal volume).
            // To maintain consistency in state, the application should switch to the reduced volume playback state.
            // If the application does not accept reduced volume playback, it can choose an alternative handling method
            // here, such as pausing playback.
            break;
          case audio.InterruptHint.INTERRUPT_HINT_UNDUCK:
            // This branch indicates that the system has restored the audio volume to normal. To maintain
            // consistency in state, the application should switch to the normal volume playback state.
            break;
          default:
            break;
        }
      } else if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
        // For the INTERRUPT_SHARE type: The application can choose to perform related actions or ignore the
        // audio interruption event.
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_RESUME:
            // This branch indicates that the audio stream, which was paused due to temporary loss of focus,
            // can now resume playing. It is recommended that the application resumes playback and switches
            // to the audio playback state.
            // If the application does not want to resume playback at this point, it can ignore this audio
            // interruption event and take no action.
            // Resume playback by explicitly calling `start()` here, and record the result of the `start()`
            // call in a flag variable `started`.
            this.videoPlay();
            break;
          default:
            break;
        }
      }
    })
  }

  private setStateChangeCallback() {
    if (!this.avPlayer) {
      return;
    }
    // [Start set_strategy_2]
    // Callback function for state machine changes
    this.avPlayer.on('stateChange', async (state) => {
      if (!this.avPlayer) {
        return;
      }
      switch (state) {
        // [StartExclude set_strategy_2]
        case 'idle': // This state machine is triggered after the reset interface is successfully invoked.
          this.avPlayer.release();
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayer state idle called.');
          break;
        // [EndExclude set_strategy_2]
        case 'initialized': // This status is reported after the playback source is set on the AVPlayer.
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayerState initialized called.');
          // Set the display screen. This parameter is not required when the resource to be played is audio-only.
          this.avPlayer.surfaceId = this.surfaceID;
          hilog.info(CommonConstants.LOG_DOMAIN, TAG,
            `setAVPlayerCallback this.avPlayer.surfaceId = ${this.avPlayer.surfaceId}`);
          await this.avPlayer.setPlaybackStrategy({
            preferredBufferDurationForPlaying: 0.3,
            preferredBufferDuration: 20,
            showFirstFrameOnPrepare: true
          });
          this.avPlayer.prepare();
          break;
        // [StartExclude set_strategy_2]
        case 'prepared': // This state machine is reported after the prepare interface is successfully invoked.
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayer state prepared called.');
          this.isReady = true;
          this.durationTime = this.avPlayer.duration;
          this.currentTime = this.avPlayer.currentTime;
          this.avPlayer.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
          if (this.seekTime) {
            this.avPlayer!.seek(this.seekTime!, media.SeekMode.SEEK_CLOSEST);
          }
          let eventData: emitter.EventData = {
            data: {
              'percent': this.avPlayer.width / this.avPlayer.height
            }
          };
          emitter.emit(CommonConstants.AVPLAYER_PREPARED, eventData);
          if (this.isMuted) {
            await this.avPlayer!.setMediaMuted(media.MediaType.MEDIA_TYPE_AUD, this.isMuted!)
          }

          this.setWindowScale();

          if (this.index === 0) {
            this.avPlayer.play(); // Invoke the playback interface to start playback.
          }

          this.setVideoSpeed();

          break;
        case 'playing': // After the play interface is successfully invoked, the state machine is reported.
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayer state playing called.');
          this.isPlaying = true;
          let eventDataTrue: emitter.EventData = {
            data: {
              'flag': true
            }
          };
          let innerEventTrue: emitter.InnerEvent = {
            eventId: 2,
            priority: emitter.EventPriority.HIGH
          };
          emitter.emit(innerEventTrue, eventDataTrue);
          break;
        case 'completed': // This state machine is triggered to report when the playback ends.
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayer state completed called.');
          this.currentTime = 0;
          this.avPlayer.seek(0)
          await this.avPlayer.play()
          let eventDataFalse: emitter.EventData = {
            data: {
              'flag': false
            }
          };
          let innerEvent: emitter.InnerEvent = {
            eventId: 1,
            priority: emitter.EventPriority.HIGH
          };
          emitter.emit(innerEvent, eventDataFalse);
          break;
        default:
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'setAVPlayerCallback AVPlayer state unknown called.');
          break;
        // [EndExclude set_strategy_2]
      }
    });
    // [End set_strategy_2]
  }

  private setWindowScale() {
    switch (this.windowScaleSelect) {
      case CASE_ZERO:
        this.videoScaleFit();
        break;
      case CASE_ONE:
        this.videoScaleFitCrop();
        break;
      default:
        break;
    }
  }

  private setVideoSpeed() {
    // Sync speed from AppStorage on every play to avoid stale defaults
    let savedIndex = AppStorage.get<number>('speedIndex');
    if (savedIndex !== undefined) {
      this.speedSelect = savedIndex;
    }
    switch (this.speedSelect) {
      case CASE_ZERO:
        this.videoSpeedZeroPointFive();
        break;
      case CASE_ONE:
        this.videoSpeedZeroPointSeventyFive();
        break;
      case CASE_TWO:
        this.videoSpeedOne();
        break;
      case CASE_THREE:
        this.videoSpeedOnePointTwentyFive();
        break;
      case CASE_FOUR:
        this.videoSpeedOnePointSeventyFive();
        break;
      case CASE_FIVE:
        this.videoSpeedTwo();
        break;
      default:
        break;
    }
  }

  // [End mode_volume]

  private setOutputDeviceChangeCallback() {
    if (!this.avPlayer) {
      return;
    }
    this.avPlayer.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `Device break: ${data.changeReason}`);
        this.videoPause();
      } else if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_NEW_DEVICE_AVAILABLE) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `Device connect: ${data.changeReason}`);
      }
    });
  }

  private updateIsPlay(isPlay: boolean) {
    this.isPlaying = isPlay;
  }

  videoPlay(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.play();
        this.isPlaying = true;
      } catch (err) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `videoPlay failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  videoPause(): void {
    if (this.avPlayer) {
      try {
        this.updateIsPlay(false);
        this.avPlayer.pause();
        this.isPlaying = false;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoPause');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoPause failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // Toggle play/pause state
  videoStop(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.stop();
        this.isPlaying = false;
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoPause');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoPause failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [Start video_muted_fun]
  /**
   * Video muted
   * @param isMuted
   * @returns
   */
  async videoMuted(isMuted: boolean): Promise<void> {
    if (this.avPlayer) {
      try {
        this.isMuted = isMuted;
        await this.avPlayer!.setMediaMuted(media.MediaType.MEDIA_TYPE_AUD, isMuted)
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoMuted');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoMuted failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [End video_muted_fun]

  /**
   * Set player volume (0-100 scale mapped to 0.0-1.0).
   * Only effective when player is in prepared/playing/paused/completed state.
   */
  async setPlayerVolume(volumePercent: number): Promise<void> {
    if (this.avPlayer) {
      try {
        let vol = Math.max(0, Math.min(100, volumePercent)) / 100;
        await this.avPlayer.setVolume(vol);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `setPlayerVolume: ${volumePercent}% -> ${vol}`);
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `setPlayerVolume failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  getVideoState(): AVPlayerState {
    let status: AVPlayerState = AVPlayerState.UNDEFINED;
    if (this.avPlayer !== undefined) {
      switch (this.avPlayer!.state) {
        case 'idle':
          status = AVPlayerState.IDLE;
          break;
        case 'initialized':
          status = AVPlayerState.INITIALIZED;
          break;
        case 'prepared':
          status = AVPlayerState.PREPARED;
          break;
        case 'playing':
          status = AVPlayerState.PLAYING;
          break;
        case 'paused':
          status = AVPlayerState.PAUSED;
          break;
        case 'completed':
          status = AVPlayerState.COMPLETED;
          break;
        case 'stopped':
          status = AVPlayerState.STOPPED;
          break;
        case 'released':
          status = AVPlayerState.RELEASED;
          break;
        case 'error':
          status = AVPlayerState.ERROR;
          break;
        default:
          status = AVPlayerState.UNDEFINED;
          break;
      }
    }
    return status;
  }

  // [Start video_speed_fun]

  videoSpeedZeroPointFive(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_0_50_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoSpeed_0_50');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_0_50 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  videoSpeedZeroPointSeventyFive(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_0_75_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoSpeed_0_75');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_0_75 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [Start video_speed_1.0X_fun]
  videoSpeedOne(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_00_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoSpeed_1_00');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_1_00 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [End video_speed_1.0X_fun]

  videoSpeedOnePointTwentyFive(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_25_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoSpeed_1_25');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_1_25 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  videoSpeedOnePointSeventyFive(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_75_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoSpeed_1_75');
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_1_75 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [Start video_speed_2.0X_fun]
  videoSpeedTwo(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_2_00_X);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `videoSpeed_2_0`);
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoSpeed_2_0 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [End video_speed_2.0X_fun]

  // [End video_speed_fun]

  videoSeek(seekTime: number): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.seek(seekTime, media.SeekMode.SEEK_CLOSEST);
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `videoSeek== ${seekTime}`);
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `videoSeek failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  async videoReset(): Promise<void> {
    if (!this.avPlayer) {
      return;
    }
    try {
      await this.avPlayer.reset();
    } catch (err) {
      hilog.info(CommonConstants.LOG_DOMAIN, TAG,
        `avPlayer.reset failed, code is ${err.code}, message is ${err.message}`);
    }
  }

  async videoRelease(): Promise<void> {
    if (!this.avPlayer) {
      return;
    }
    this.avPlayer.release((err) => {
      if (err) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG, `videoRelease release filed,error message is = ${err.message}`);
      } else {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'videoRelease release success');
      }
    });
  }

  getDurationTime(): number {
    return this.durationTime;
  }

  getCurrentTime(): number {
    return this.currentTime;
  }

  // [Start window_scale_fun]
  /**
   * Set window scale mode
   */
  videoScaleFit(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `videoScaleType_0`);
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoScaleType_0 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  videoScaleFitCrop(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP
        hilog.info(CommonConstants.LOG_DOMAIN, TAG, `videoScaleType_1`);
      } catch (err) {
        hilog.info(CommonConstants.LOG_DOMAIN, TAG,
          `videoScaleType_1 failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  // [End window_scale_fun]

  public setIsPlaying(isPlayer: boolean) {
    this.isPlaying = isPlayer;
  }

  async languageChange(languageSelect: number = 0): Promise<void> {
    if (this.avPlayer) {
      try {
        if (this.curSource && this.curSource.caption) {
          if (!this.context) {
            hilog.info(CommonConstants.LOG_DOMAIN, TAG, `initPlayer failed context not set`);
            return
          }
          this.curSource.caption = languageSelect === 0 ? 'captions.srt' : 'en_captions.srt'

          if (languageSelect === 0) {
            this.curSource.caption = 'captions.srt';
          } else if (languageSelect === 1) {
            this.curSource.caption = 'en_captions.srt';
          }
          this.curSource.seekTime = this.avPlayer.currentTime;
          await this.avPlayer.reset();
          this.initAVPlayer(this.curSource, this.surfaceID);
          hilog.info(CommonConstants.LOG_DOMAIN, TAG, 'language change');
        }
      } catch (err) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `languageChange failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  setBitrate(bitrate: number): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.setBitrate(bitrate);
      } catch (err) {
        hilog.error(CommonConstants.LOG_DOMAIN, TAG,
          `setBitrate failed, code is ${err.code}, message is ${err.message}`);
      }
    }
  }

  private getBitrateLabel(bitrate: number): string {
    if (bitrate <= 0) return '鑷姩';
    if (bitrate <= 400000) return '娴佺晠';
    if (bitrate <= 800000) return '鏍囨竻';
    if (bitrate <= 2000000) return '楂樻竻';
    return '瓒呮竻';
  }

  clearPlaybackError(): void {
    this.playbackError = false;
    this.errorMessage = '';
  }
}