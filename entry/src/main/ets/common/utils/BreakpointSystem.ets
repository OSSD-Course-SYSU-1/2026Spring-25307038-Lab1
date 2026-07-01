/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { mediaquery } from '@kit.ArkUI';
import { BreakpointConstants } from '../constants/BreakpointConstants';

/**
 * 斷點系統工具類。
 * 使用媒體查詢監聽窗口寬度變化，自動識別當前斷點並同步到 AppStorage。
 */
export class BreakpointSystem {
  private static instance: BreakpointSystem;
  private currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  private smListener?: mediaquery.MediaQueryListener;
  private mdListener?: mediaquery.MediaQueryListener;
  private lgListener?: mediaquery.MediaQueryListener;
  private xlListener?: mediaquery.MediaQueryListener;

  public static getInstance(): BreakpointSystem {
    if (!BreakpointSystem.instance) {
      BreakpointSystem.instance = new BreakpointSystem();
    }
    return BreakpointSystem.instance;
  }

  /**
   * 更新當前斷點並同步到 AppStorage
   */
  private updateCurrentBreakpoint(breakpoint: string): void {
    if (this.currentBreakpoint !== breakpoint) {
      this.currentBreakpoint = breakpoint;
      AppStorage.setOrCreate<string>(BreakpointConstants.CURRENT_BREAKPOINT, this.currentBreakpoint);
    }
  }

  /** sm 斷點回調 */
  private isBreakpointSM = (mediaQueryResult: mediaquery.MediaQueryResult): void => {
    if (mediaQueryResult.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_SM);
    }
  };

  /** md 斷點回調 */
  private isBreakpointMD = (mediaQueryResult: mediaquery.MediaQueryResult): void => {
    if (mediaQueryResult.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_MD);
    }
  };

  /** lg 斷點回調 */
  private isBreakpointLG = (mediaQueryResult: mediaquery.MediaQueryResult): void => {
    if (mediaQueryResult.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_LG);
    }
  };

  /** xl 斷點回調 */
  private isBreakpointXL = (mediaQueryResult: mediaquery.MediaQueryResult): void => {
    if (mediaQueryResult.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_XL);
    }
  };

  /**
   * 註冊媒體查詢監聽器
   */
  public register(): void {
    try {
      this.smListener = mediaquery.matchMediaSync(BreakpointConstants.RANGE_SM);
      this.smListener.on('change', this.isBreakpointSM);

      this.mdListener = mediaquery.matchMediaSync(BreakpointConstants.RANGE_MD);
      this.mdListener.on('change', this.isBreakpointMD);

      this.lgListener = mediaquery.matchMediaSync(BreakpointConstants.RANGE_LG);
      this.lgListener.on('change', this.isBreakpointLG);

      this.xlListener = mediaquery.matchMediaSync(BreakpointConstants.RANGE_XL);
      this.xlListener.on('change', this.isBreakpointXL);

      // 初始化當前斷點
      this.initBreakpoint();
      console.info('[BreakpointSystem] 斷點監聽已註冊');
    } catch (err) {
      console.error(`[BreakpointSystem] 註冊失敗: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 初始化時計算當前斷點
   */
  private initBreakpoint(): void {
    if (this.xlListener?.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_XL);
    } else if (this.lgListener?.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_LG);
    } else if (this.mdListener?.matches) {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_MD);
    } else {
      this.updateCurrentBreakpoint(BreakpointConstants.BREAKPOINT_SM);
    }
  }

  /**
   * 解除媒體查詢監聽器
   */
  public unregister(): void {
    this.smListener?.off('change', this.isBreakpointSM);
    this.mdListener?.off('change', this.isBreakpointMD);
    this.lgListener?.off('change', this.isBreakpointLG);
    this.xlListener?.off('change', this.isBreakpointXL);
    console.info('[BreakpointSystem] 斷點監聽已解除');
  }
}
