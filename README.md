# Nosmai × ZEGOCLOUD Live

- **[`packages/nosmai_zegocloud_live`](packages/nosmai_zegocloud_live)**: Flutter plugin that livestreams the
  Nosmai-filtered camera through ZEGOCLOUD (ZEGO Express SDK). Apps using it write only Dart. Same API shape
  as `nosmai_zoom_live`. **Start with its README.**
- **This app** (repository root): the example. Host screen (preview, filters, Start/Stop Live, mic, camera
  switch, live stats) and viewer screen. No native code.

| | Version |
|---|---|
| ZEGO Express (Android) | `im.zego:express-video:3.21.0`, brought in by the plugin |
| Nosmai | `nosmai_effects_sdk 2.0.2` → `nosmai-sdk 3.0.7` |
| ZEGO Express (iOS) | `ZegoExpressEngine 3.21.0` pod, brought in by the plugin |
| Flutter | 3.29+. Android minSdk 24, OpenGL ES 3. iOS 15+ (bundle `com.vativeApps.NosmaiAR`, the id the iOS Nosmai key is bound to) |

## Pipeline: how the bridge is used

```
HOST
 Camera ─► Nosmai (beauty / filter / AR, GPU) ─► NosmaiCameraPreview (what you see)
                      │ processed texture, 720x1280 @ 30 fps
                      ▼
            NosmaiZegoVideoSource (bridge)
              GPU scale + RGBA→I420 · pacing · thermal cap (optional)
                      ▼
            ZEGO custom capture ─► hardware H.264 ─► ZEGOCLOUD room / stream

VIEWER
 ZEGOCLOUD room ─► newest working stream ─► hardware decode ─► NosmaiLiveViewerView
```

App code (Dart only): `NosmaiZegoCloudLive.initialize` → `NosmaiLiveBroadcaster.start()` /
`NosmaiLiveViewer.start()` → states `connecting → live → stopped`.
Send FPS equals preview FPS unless `adaptToThermalState` (default on in the plugin) caps it on a hot phone.

## Run the example

1. `cp config/local.example.json config/local.json` and fill in:
   - `ZEGO_APP_ID`, `ZEGO_APP_SIGN`: ZEGOCLOUD console → Projects Management → project → Project Information.
   - `NOSMAI_LICENSE_KEY`: bound to applicationId `com.nosmai.effect` (same key and id as the Zoom example,
     so the two apps replace each other on a phone).
   - `ZEGO_TOKEN` (optional): a Token04 for one user ID, only if the project uses token authentication.
   The ServerSecret never goes into the app. `config/local.json` is git-ignored.
2. Run on two arm64 phones:
   ```bash
   flutter run --dart-define-from-file=config/local.json
   ```
   Phone A: **Host** → **Start Live**. Phone B: **Viewer**, same room ID, a **different name** (the name is
   the ZEGOCLOUD user ID; two phones with the same ID sign each other out).

**Release APK**: `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define-from-file=config/local.json`
→ `app-arm64-v8a-release.apk` (~94 MB).

## Code map

| Path | Role |
|---|---|
| `packages/nosmai_zegocloud_live/lib/` | Dart API: `NosmaiZegoCloudLive`, `NosmaiLiveBroadcaster`, `NosmaiLiveViewer(View)`, config, stats, credential checks |
| `.../android/.../NosmaiZegoLivePlugin.kt` | Channels, permissions, keep-screen-on, remote video platform view (TextureView) |
| `.../android/.../ZegoSession.kt` | Engine, room login/logout, publish/play, mute, background, reconnect, end-of-live notice, stats |
| `.../android/.../NosmaiZegoVideoSource.kt` | ZEGO custom video capture fed by Nosmai: pacing, thermal cap, texture→I420 with I420 fallback |
| `.../android/.../I420Converter.kt`, `SharedGlContext.kt` | GPU RGBA→I420 and the ES3 share context Nosmai joins (shared with the Zoom bridge) |
| `lib/` | Example app: home, host and viewer screens, stats overlay |

## Verification status

- Plugin: `flutter analyze` clean, `flutter test` 27 tests pass. Example: analyze clean, 3 tests pass.
- Builds: debug APK and release arm64 APK with R8 (ZEGO and plugin classes kept), 94 MB.
- Two phones (OnePlus N200 Android 12, OnePlus CPH2515 Android 14), `tools/two_phone_test.sh HOST VIEWER`:
  login with AppSign, upright unmirrored video with Nosmai filters, viewer playback (720x1280, ~400 ms delay),
  host Stop -> viewer shows "broadcaster ended the live", Stop/Start repeat, viewer skips a dead leftover stream.
- Seen: with the thermal guard on, a warm CPH2515 capped sending at 15 fps (preview 30). Seen once: the N200 as
  host got `CAMERA_DISCONNECTED` right after a force-stop (Nosmai preview 0 fps); same phone worked earlier.
- Not yet checked: background, mic by ear, reconnect, long sessions, token authentication.
