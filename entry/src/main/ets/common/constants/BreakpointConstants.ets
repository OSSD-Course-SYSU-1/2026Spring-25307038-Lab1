/*

 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

/**
 * 斷點常量定義。
 * 遵循 HarmonyOS 一多開發標準斷點系統。
 */
export class BreakpointConstants {
  /** 小屏斷點 (手機豎屏) */
  static readonly BREAKPOINT_SM: string = 'sm';
  /** 中屏斷點 (摺疊屏展開態 / 小平板) */
  static readonly BREAKPOINT_MD: string = 'md';
  /** 大屏斷點 (平板橫屏 / PC / 三摺疊 G 態) */
  static readonly BREAKPOINT_LG: string = 'lg';
  /** 超大屏斷點 (2in1 / 大屏顯示器) */
  static readonly BREAKPOINT_XL: string = 'xl';

  /** 當前斷點 AppStorage Key */
  static readonly CURRENT_BREAKPOINT: string = 'currentBreakpoint';
  /** 當前高度斷點 AppStorage Key */
  static readonly CURRENT_HEIGHT_BP: string = 'currentHeightBreakpoint';

  /** sm 範圍：320vp <= width < 600vp */
  static readonly RANGE_SM: string = '(320vp<=width<600vp)';
  /** md 範圍：600vp <= width < 840vp */
  static readonly RANGE_MD: string = '(600vp<=width<840vp)';
  /** lg 範圍：840vp <= width < 1440vp */
  static readonly RANGE_LG: string = '(840vp<=width<1440vp)';
  /** xl 範圍：1440vp <= width */
  static readonly RANGE_XL: string = '(1440vp<=width)';

  /** 柵格列數 */
  static readonly COLUMN_SM: number = 4;
  static readonly COLUMN_MD: number = 8;
  static readonly COLUMN_LG: number = 12;
  static readonly COLUMN_XL: number = 12;

  /** 柵格間距 */
  static readonly GUTTER_X: number = 12;

  /** 響應式字體大小 */
  static readonly FONT_SIZE_SM: number = 14;
  static readonly FONT_SIZE_MD: number = 16;
  static readonly FONT_SIZE_LG: number = 18;
  static readonly FONT_SIZE_XL: number = 20;

  /** 響應式內邊距 */
  static readonly PADDING_SM: number = 16;
  static readonly PADDING_MD: number = 24;
  static readonly PADDING_LG: number = 32;
  static readonly PADDING_XL: number = 40;
}
