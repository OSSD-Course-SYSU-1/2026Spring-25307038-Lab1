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

/**
 * AI Caption configuration constants and types.
 */
export class AiCaptionConstants {
  // Source language options
  static readonly SOURCE_LANG_ZH: string = 'zh';
  static readonly SOURCE_LANG_EN: string = 'en';

  // Target language options
  static readonly TARGET_LANG_ZH: string = 'zh';
  static readonly TARGET_LANG_EN: string = 'en';
  static readonly TARGET_LANG_ZH_EN: string = 'zh-en';

  // Source language display options
  static readonly SOURCE_LANG_OPTIONS: AiCaptionLangOption[] = [
    { label: '中文', value: 'zh' },
    { label: 'English', value: 'en' }
  ];

  // Target language options when source is English:
  static readonly TARGET_LANG_OPTIONS_EN: AiCaptionLangOption[] = [
    { label: '翻译为中文', value: 'zh' },
    { label: '不翻译(英文)', value: 'en' },
    { label: '中英双语', value: 'zh-en' }
  ];

  // Target language options when source is Chinese
  static readonly TARGET_LANG_OPTIONS_ZH: AiCaptionLangOption[] = [
    { label: '中文', value: 'zh' }
  ];

  // Caption display constants
  static readonly DEFAULT_CAPTION_FONT_SIZE: number = 18;
  static readonly DEFAULT_CAPTION_OPACITY: number = 0.8;
  static readonly MAX_CAPTION_LINES: number = 3;
}

export interface AiCaptionLangOption {
  label: string;
  value: string;
}

export interface AiCaptionConfig {
  isShown: boolean;
  sourceLanguage: string;  // 'zh' or 'en'
  targetLanguage: string;  // 'zh', 'en', or 'zh-en'
  initialOpacity: number;
}
