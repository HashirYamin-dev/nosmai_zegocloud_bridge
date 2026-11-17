# nosmai_zegocloud_live

Livestream the Nosmai-filtered camera (beauty, filters, AR effects, backgrounds, cloud filters) through
**ZEGOCLOUD** (ZEGO Express SDK) from Flutter. Apps write only Dart. It has the same API shape as
`nosmai_zoom_live` and `nosmai_tencent_live`.

**Platforms:** Android (minSdk 24, OpenGL ES 3). iOS is not supported yet.

```
Camera ─► Nosmai (filters/AR, GPU) ─► processed GL texture
   ─► GPU scale + RGBA→I420 (shared GL context, dedicated thread)
   ─► ZEGO custom video capture (sendCustomVideoCaptureRawData) ─► room ─► viewers
Fallback: Nosmai I420 frame callback ─► one copy ─► ZEGO
```

## Setup

```yaml
dependencies:
  nosmai_zegocloud_live:
    path: packages/nosmai_zegocloud_live
```

The plugin brings ZEGO Express (`im.zego:express-video:3.21.0` from `https://storage.zego.im/maven`), the
permissions it needs and the R8 keep rules. Set `minSdk` to at least 24 in the app.

## Credentials

From the ZEGOCLOUD console, open **Projects Management → your project → Project Information**:

| Console field | Where it goes |
|---|---|
| AppID | `NosmaiLiveCredentials.appId` |
| AppSign | `NosmaiLiveCredentials.appSign` (AppSign authentication) |
| ServerSecret | **Your server only.** It signs Token04 tokens; pass them as `NosmaiLiveCredentials.token` |

AppSign authentication is the simplest setup and is meant to ship in the app. For production, ZEGOCLOUD
recommends token authentication: the app gets a short-lived Token04 for its user ID from your server.

## Use

```dart
await NosmaiZegoCloudLive.initialize(androidLicenseKey: nosmaiKey); // before NosmaiCameraPreview

// Host: show NosmaiCameraPreview, apply effects with NosmaiZegoCloudLive.effects, then:
final live = NosmaiLiveBroadcaster(
  credentials: NosmaiLiveCredentials(appId: appId, appSign: appSign, userId: 'host_42', userName: 'Ana'),
  session: const NosmaiLiveSession('room-1'),          // stream ID defaults to "room-1_host_42"
  video: NosmaiLiveVideoConfig.hd,                      // 720x1280 @ 30 fps, 1800 kbps
);
await live.start();
// ...
await live.stop(); // tells viewers the live ended (endSessionOnStop: true)

// Viewer (no Nosmai license needed):
final viewer = NosmaiLiveViewer(
  credentials: NosmaiLiveCredentials(appId: appId, appSign: appSign, userId: 'viewer_7'),
  session: const NosmaiLiveSession('room-1'),          // or streamId: to watch one stream
);
await viewer.start();
// build: NosmaiLiveViewerView(viewer: viewer)
```

Both are `ChangeNotifier`s with `state` (`connecting`, `waitingForHost`, `live`, `reconnecting`, `paused`,
`stopped`, `failed`), `error`, `warning` and `stats` (refreshed every second).

### ZEGOCLOUD rules the plugin checks before logging in

- **User ID**: unique per person across the AppID. A second login with the same ID signs the first out
  (reported as `failed` with "signed in elsewhere"). No spaces; up to 63 bytes.
- **Room ID**: up to 127 bytes of letters, digits and ``~!@#$%^&*()_+=-`;',.<>\``.
- **Stream ID**: unique across the AppID; letters, digits, `-`, `_`.
- **AppSign**: 64 hexadecimal characters. **Token**: Token04, not expired.

Errors use stable codes: `invalid_config`, `invalid_credentials`, `permission_denied`, `not_initialized`,
`already_active`, or `zego_<code>` for other ZEGOCLOUD errors.

## How it maps to ZEGO Express

| Plugin | ZEGO Express |
|---|---|
| `start()` (host) | `createEngine` (BROADCAST scenario) → `enableCustomVideoCapture(RAW_DATA)` → `setVideoConfig` → `enableTrafficControl` → `loginRoom` → `startPublishingStream` |
| frames | `IZegoCustomVideoCaptureHandler.onStart/onStop` gate Nosmai output; I420 via `sendCustomVideoCaptureRawData` |
| `state == live` (host) | custom capture started **and** `onPublisherStateUpdate(PUBLISHING)` |
| `start()` (viewer) | `loginRoom` → `onRoomStreamUpdate` → `startPlayingStream` into a `TextureView` |
| `state == live` (viewer) | `PLAYING` + `onPlayerRenderVideoFirstFrame` + remote camera not muted |
| `stop()` with `endSessionOnStop` | room custom command to viewers, then `stopPublishingStream` + `logoutRoom` |
| `reconnecting` | `onRoomStateChanged(RECONNECTING/RECONNECTED)` |
| `prioritizeFrameRate` | traffic control `ADAPTIVE_RESOLUTION` (else `ADAPTIVE_FPS \| ADAPTIVE_RESOLUTION`) |
| background / video mute | `mutePublishStreamVideo` (+ Nosmai frames skipped), `mutePlayStreamVideo/Audio` |
