# CLAUDE_PROGRESS — nosmai_zegocloud_bridge

Goal: a ZEGOCLOUD package built like the Zoom one (`../nosmai_zoom_bridge`, plugin `nosmai_zoom_live`).
Android first, then iOS.

## Done
- [x] 2026-11-16: Plugin `packages/nosmai_zegocloud_live` (Kotlin, ZEGO Express 3.21.0 from storage.zego.im/maven),
      same Dart API shape as nosmai_zoom_live. Custom video capture (RAW_DATA, I420) fed by Nosmai via the
      shared-GL texture path (I420Converter/SharedGlContext copied from the Zoom bridge) with I420 fallback.
      Portrait frames sent upright, no rotation (ZEGO does not crop like Zoom).
- [x] Example app (applicationId com.nosmai.effect, same Nosmai key as Zoom example). config/local.json has
      AppID 117962517 + AppSign (git-ignored).
- [x] Plugin 24 tests, example 3 tests, analyze clean. Debug + release (R8) arm64 APKs build.

- [x] 2026-11-17: iOS plugin code (ObjC, packages/nosmai_zegocloud_live/ios): ZegoExpressEngine 3.21.0 pod (same as
      Android), Nosmai setLiveStreamFrameCallback -> sendCustomVideoCapturePixelBuffer (BGRA/NV12 as is, no
      conversion; pacing + thermal cap), UiKitView viewer, permissions, stats. Same channel protocol as Android.
      Example ios/ Runner (bundle com.vativeApps.NosmaiAR, the id the iOS Nosmai key is bound to), NOSMAI_IOS_LICENSE_KEY
      in config/local.json. Dart initialize accepts iOS. Debug (no-codesign) and signed release builds OK;
      Fixed: `sending`/boolean stats were boxed as int (`@(a && b)`), so Dart never saw `on == true` and the host
      stayed 'connecting'. Always box BOOL expressions with numberWithBool.
- [x] 2026-11-17: iOS two-phone run (iPhone XR host, iPhone X iOS 16.7 viewer, debug builds, AUTO_ROLE=host|viewer
      dart-define drives the example and prints `[NosmaiZegoAuto]` ticks): login, publish 720x1280@30 ~1.9 Mbps,
      rtt 5-10 ms, 0 loss/0 dropped, viewer found the stream and showed hasVideo=true 720x1280. Stop/Start repeat OK.
      Host-side filter sweep (~85 cloud filters, 10 s each, XR thermal 'serious' from the start):
      * Fresh app: 29-30 fps, CPU 60-100%. First load of a cloud filter stalls the stream (3-17 s, preview 0-7 fps,
        encode sometimes 0); cached reloads take 0.2-0.5 s.
      * After ~45 filters in one session CPU climbs to 200-270% and preview/send drops to 12-25 fps even for light
        filters; memory plateaus ~1.1-1.2 GB. `clearAll` restored 30 fps and fast applies; it degraded again after ~10 more.
        Looks like Nosmai effect state accumulating (not ZEGO: network/loss/dropped stayed fine). Debug build, not re-run in release.
      * 'Film Frame' (fx-and-filters_film_frame_4489) failed to download 3x, Nosmai Error 1003.

## Remaining
- [ ] Two-phone test: login, orientation/mirroring (flipVertical=false assumed from the Zoom texture path),
      colours, viewer playback, end-of-live custom command, background, mic, reconnect.
- [ ] iOS still to confirm by eye/ear: upright/unmirrored video and colours on the viewer, mic, end-of-live on the viewer, background, reconnect; viewer fps/latency (iOS 16 device logs stalled); filter sweep in a release build.
- [ ] Report to Nosmai: slowdown after many filter changes (`clearAll` fixes), first-load stall, Film Frame Error 1003.
- [ ] Token04 server/tool if token auth is wanted (ServerSecret stays on the server).

## Notes
- Disk was full (226 MB free) during the first release build; only own build output was deleted.
- Flutter: `~/fvm/default/bin/flutter`.
