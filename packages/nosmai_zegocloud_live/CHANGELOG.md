## 1.0.0 (unreleased)

- First version, Android: ZEGOCLOUD (ZEGO Express 3.21.0) counterpart of `nosmai_zoom_live`, same API
  shape (`NosmaiLiveBroadcaster`, `NosmaiLiveViewer`, `NosmaiLiveViewerView`, states, stats, errors).
- Credentials are AppID + AppSign, or AppID + Token04; room, user and stream IDs are checked against
  ZEGOCLOUD's rules before logging in, and a Token04's expiry is read locally.
- Nosmai frames reach ZEGO through custom video capture: GPU scale + RGBA→I420 of Nosmai's shared texture,
  with an automatic fallback to Nosmai's I420 frames; even frame pacing; thermal FPS cap. Portrait frames
  go out upright with no rotation flag (ZEGO does not crop them).
- `endSessionOnStop` tells viewers through a room custom command; they report `endedByHost`.
- Every event carries its session ID, so a late event of an earlier session cannot end a newer live.
- End of live is signalled twice (room command and the stream's extra info), so a viewer also learns of it when
  the command is lost; the viewer prefers the newest stream that plays and skips dead leftovers.
- `renewToken()` on broadcaster and viewer, `tokenExpiresAt` set when ZEGOCLOUD warns of expiry.
- The ZEGO engine is released 30 s after a live ends (nothing stays running when idle).
- Viewer renders through ZEGO into a `TextureView` (no hybrid composition) and needs no permissions.
