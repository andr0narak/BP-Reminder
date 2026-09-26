# FaceCam Browser (iOS)

iPhone app with a built-in web browser that records the **front camera** (plus mic) while you browse. Recordings are saved to Photos.

## Why not record while using Chrome itself?

iOS does not allow a third-party app to use the camera while another app (Chrome) is in the foreground. The capture session is cut off as soon as the app goes to the background. The only exception is an Apple entitlement for video-calling apps, and Apple won't approve it for this use. So the browser is built into the app. Chrome on iOS uses the same WebKit engine, so pages render the same.

## Features

- Full-screen WKWebView browser with an address/search bar, back/forward, reload, and swipe navigation
- A front-camera bubble you can drag around, with a red border while recording. You can hide it, and recording keeps going.
- One-tap record/stop with a timer. Output is HEVC `.mov`, portrait, mirrored to match the selfie preview.
- Page audio keeps playing while the mic records (`.mixWithOthers`)
- Recording stops and saves automatically if you leave the app

## Build

Requires a Mac with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd FaceCamBrowser
xcodegen generate
open FaceCamBrowser.xcodeproj
```

In Xcode, set your Team under Signing & Capabilities, change the bundle ID if needed, and run it on a real iPhone. The simulator has no camera.

A free Apple ID can sideload the app, but the install expires after 7 days. A paid developer account ($99/yr) removes that limit.

## Notes

- The mic also picks up page audio coming out of the speaker. Wear headphones if you want a clean voice track.
- Only the camera is recorded, not the screen. To capture both, run iOS Screen Recording (Control Center) at the same time, then combine the two clips in an editor. Or keep the bubble visible and screen-record only.
- iOS always shows the green camera indicator while the camera is running.
