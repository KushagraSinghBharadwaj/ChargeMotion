# Backend limits and integration notes (Tasks 4 and 5)

No backend file was modified. Nothing here has been compiled or run on a Mac.

## Limits the UI states honestly
1. Scaling mode is saved but not applied to the wallpaper (window manager uses the default fill). Settings says so.
2. "Pause when displays sleep" is saved but nothing sets `SystemConditions.displaysAsleep`. Settings says so.
3. Audio settings apply only when the wallpaper video next loads.
4. `MediaAsset` has no duration, size in pixels or thumbnail. The frontend derives them with AVFoundation and caches them in `~/Library/Caches/ChargeMotion/VideoInfo/` (disposable).
5. No import progress: the UI shows the file name and count, and Cancel stops after the file being copied (the backend copy cannot be interrupted).
6. `DesktopWallpaperWindowManager` exposes only `activeDisplayIDs`; the Displays page shows that plus AppKit facts. No per-display video, and a display connected later may get no window until the video reloads.
7. The backend's supported-format list is private; `SupportedVideoFormats` mirrors MP4, MOV, M4V. Update both if the backend changes.
8. Manual override (`manualOverrideEnabled`) has no UI (not approved). Removing a video clears a dangling manual selection and turns override off.

## Assumed from BACKEND-API-REVIEW.md (source not re-read this session)
`VideoPlaybackController`: `load(url:muted:) throws`, `play()`, `pause()`, `stop()`, `setMuted(_:)`, `isPlaying`, `lastError`, `player` (an `AVPlayer` subclass, optional), conforming to `ObservableObject`, all public. `DesktopWallpaperWindowManager` is an `ObservableObject` with public `activeDisplayIDs: [UInt32]`. Preview volume sets `player.volume` directly. Fix any mismatch in the frontend, not the backend.

## Needs a Mac to verify
Whole-project build (backend never compiled); `Window` scene + `.commands`; looping preview seeking and time updates; thumbnail generation; NSOpenPanel and drag-and-drop import; remove-while-assigned flow; display list vs `activeDisplayIDs` after hot-plug; launch at login.
