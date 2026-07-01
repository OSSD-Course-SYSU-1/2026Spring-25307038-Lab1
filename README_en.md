# Network Video Playback Using AVPlayer
## Overview    
This sample demonstrates how to use AVPlayer to implement network video playback in HarmonyOS, including the following scenarios:
- URL customization
- Basic playback control
- Video buffer bar
- Playback while buffering
## Effect
| Preset Video List                           | URL Customization                           | Video Playback                       | Playback with Buffer Bar                        |                         
|--------------------------------------|--------------------------------------|--------------------------------------|--------------------------------------|
| ![image](screenshots/device/pv1_en.png) | ![image](screenshots/device/pv2_en.png) | ![image](screenshots/device/pv3_en.png) | ![image](screenshots/device/pv4_en.png) |
## How to Use
1. Download, compile, and run the sample.
2. The home page displays a video list, where each item corresponds to a scenario. Tap an item to play the video.
3. Tap the button in the upper-right corner of the home page to customize a video URL and confirm playback.
4. Note that the M3U8 test resource used in this sample is not publicly available. You may replace it with your own test resource:
   - entry/src/main/ets/model/VideoDataModel.ets:44
   - entry/src/main/resources/rawfile/test.m3u8

## Project Directory
```
├──entry/src/main/ets                           // Entry module 
│  ├──common
│  │  ├──constants
│  │  │  └──CommonConstants.ets                 // Common constants 
│  │  └──utils
│  │     ├──BackgroundTaskManager.ets           // Background task utility 
│  │     ├──ImageUtil.ets                       // Image utility 
│  │     ├──Logger.ets                          // Log utility 
│  │     └──TimeUtils.ets                       // Time utility 
│  ├──components
│  │  ├──BulletCommentView.ets                  // Bullet comment component 
│  │  ├──ExitVideo.ets                          // Application exit component 
│  │  ├──LanguageDialog.ets                     // Dialog for language switch 
│  │  ├──ScaleDialog.ets                        // Dialog for setting the window scaling mode 
│  │  ├──SetBirghness.ets                       // Component for adjusting the brightness 
│  │  ├──SetVolumn.ets                          // Component for adjusting the volume 
│  │  ├──SpeedDialog.ets                        // Dialog for adjusting the playback speed 
│  │  └──VideoOperate.ets                       // Component for operating videos 
│  ├──controller
│  │  ├──AvPlayerController.ets                 // AVPlayer control class 
│  │  └──PipWindowController.ets                // PiP control class 
│  ├──entryability
│  │  └──EntryAbility.ets                       // Entry ability 
│  ├──entrybackupability
│  │  └──EntryBackupAbility.ets
│  ├──model
│  │  ├──BulletCommentModel.ets                 // Bullet comment data class 
│  │  ├──VideoData.ets                          // Video data class 
│  │  └──VideoDataModel.ets                     // Video data class implementation 
│  ├──pages
│  │  ├──BufferBarPlayer.ets                    // Playback page with a buffer bar 
│  │  ├──Index.ets                              // Home page with a playlist 
│  │  └──UrlPlayer.ets                          // URL playback page 
│  └──view
│     ├──BasicVideoPlayer.ets                   // Basic playback control 
│     └──VideoItem.ets                          // Video list on the home page 
└──entry/src/main/resources                     // Resources
```
## How to Implement
- URL customization
  - Set the url property of the AVPlayer to play videos.
- Basic playback control
  - Use the play(), pause(), and stop() methods of AVPlayer.
- Video buffer bar
  - Bind a bufferingUpdate event handler to AVPlayer. Add the estimated buffered playback duration to the current playback time, and bind the result to the value property of Slider.
- Playback while buffering
  - Use the setPlaybackStrategy() method of AVPlayer to configure related parameters.
## Required Permissions
In this sample, some images use network resources. Therefore, you need to apply for the system network permission. The configuration is as follows:

src/main/module.json5
```
{
  "module": {
    //...
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
        // ...
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO",
        // ...
      }
    ]
  }
}
```
## Constraints

1.This sample is only supported on Huawei phones running standard systems.

2.The HarmonyOS version must be HarmonyOS 5.1.0 Release or later.

3.The DevEco Studio version must be DevEco Studio 5.1.0 Release or later.

4.The HarmonyOS SDK version must be HarmonyOS 5.1.0 Release SDK or later.
