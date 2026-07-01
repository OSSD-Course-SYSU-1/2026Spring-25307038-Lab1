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

import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CommonConstants } from '../common/constants/CommonConstants';

const TAG = 'SubtitleConfig';

export interface CaptionFont {
  family: ResourceStr;
  size: number;
  color: ResourceColor;
}

export class SubtitleConstants {
  static readonly CAPTION_FONT_FAMILY: ResourceStr[] = ['Sans', 'Condensed'];
  static readonly CAPTION_FONT_COLOR: ResourceColor[] = [
    Color.White,
    Color.Yellow,
    '#63B959',
    '#4ECDC4',
    '#FF6B6B',
    '#FF8C42',
    '#7B68EE',
    '#FF69B4',
    '#00CED1',
    Color.Orange,
    Color.Gray,
    Color.Black,
  ];
  static readonly CUSTOM_COLOR_IDENTIFIER: string = '__custom__';
  static readonly CAPTION_FONT_SIZE_MIN: number = 12;
  static readonly CAPTION_FONT_SIZE_MAX: number = 28;

  static readonly DEFAULT_CAPTION_FONT: CaptionFont = {
    family: 'Sans',
    size: 16,
    color: Color.White
  };
}

export function registerMyFont(uiContext: UIContext): void {
  try {
    uiContext.getFont().registerFont({
      familyName: $r('app.string.subtitle_font_condensed'),
      familySrc: $rawfile('HarmonyOS_Condensed.ttf')
    });
  } catch (err) {
    let error = err as BusinessError;
    hilog.error(CommonConstants.LOG_DOMAIN, TAG,
      `registerFont failed. code: ${error.code}, message: ${error.message}`);
  }
}
