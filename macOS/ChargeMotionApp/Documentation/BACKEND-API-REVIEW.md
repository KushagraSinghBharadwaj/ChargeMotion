# ChargeMotionCore API review (for the frontend)

Source: `chargemotion-backend-dump.txt` (package `ChargeMotionCore`, macOS 14+, tools 5.9).
The backend has **not been compiled**. Nothing below is verified on a Mac.

## Public surface the frontend uses

| Area | Type | Observable / key API |
|---|---|---|
| Power | `IOKitPowerMonitor` (@MainActor, ObservableObject) | `@Published snapshot: PowerSnapshot`, `state: PowerState`; `start()`, `stop()`, `refresh()` |
| Power model | `PowerState`, `PowerSnapshot` | `state.title`, `state.isExternalPowerConnected`; `snapshot.batteryPercent`, `isCharging`, `isCharged`, `hasInternalBattery` |
| Policy | `WallpaperPolicy`, `WallpaperPlan`, `SystemConditions`, `PauseReason` | plan has `role`, `mediaID`, `pauseReasons`, `issue`, `shouldPlay` |
| Settings | `AppSettings` (Codable struct), `AppSettingsStore` (actor) | `load() throws`, `save(_:) throws`, `settingsFileURL()` |
| Login item | `LaunchAtLoginManager` (@MainActor) | `status: SMAppService.Status`, `setEnabled(_:) throws` |
| Media | `MediaLibraryStore` (actor), `MediaAsset`, `MediaLibraryError` | `listAssets()`, `importFile(from:displayName:)`, `fileURL(for:)`, `renameAsset(_:to:)`, `removeAsset(_:)`; `init` throws |
| Playback | `VideoPlaybackController` (@MainActor) | `@Published isPlaying, currentURL, lastError`; `player: AVQueuePlayer?`; `load(url:muted:)`, `play/pause/stop`, `setMuted`, `setVolume`, `setRate` |
| Environment | `PlaybackEnvironment` (@MainActor) | `@Published snapshot: PlaybackEnvironmentSnapshot`, `shouldPausePlayback`, `refresh()`, `stopMonitoring()` |
| Desktop | `DesktopWallpaperWindowManager` (@MainActor) | `@Published activeDisplayIDs: [UInt32]` |
| Orchestration | `WallpaperCoordinator` (@MainActor) | `@Published settings, conditions, currentPlan, lastError, isRunning`; `start()`, `stop()`, `updateSettings(_:)`, `setUserPaused(_:)`, `refreshPowerState()`, `reconcile()` |

## Composition rule

`WallpaperCoordinator` keeps its collaborators `private`, but its `init` accepts all of them.
The app composition root therefore creates **one** instance of each and injects them, keeping
its own references to the monitor, environment, playback controller and window manager for UI
observation. Never use the coordinator's default arguments (they would create duplicate monitors).

## Integration requirements and gaps (frontend-visible, not fixed here)

1. **Scaling mode has no runtime effect.** `AppSettings.scalingMode` persists, but the window
   manager attaches players with the default `.resizeAspectFill`; `attach(player:gravity:)` is
   `internal`. The Settings screen can save the value; wallpaper will not honor it until the backend
   passes it through.
2. **"Pause when displays sleep" has no runtime effect.** Nothing sets `SystemConditions.displaysAsleep`
   (or `sessionInactive`). `systemAsleep` is set from `PlaybackEnvironment`.
3. **Audio setting changes apply only on media reload.** The coordinator passes `muted` to
   `load(url:muted:)` only when the active media changes or the player is nil. Toggling
   `allowAudio` / `audioMuted` while a video plays will not update the running player.
4. **No media metadata.** `MediaAsset` has name, extension, size and import date only. Duration,
   dimensions and thumbnails must be derived read-only from the managed file with AVFoundation, cached
   by the frontend outside the media library. No second media store.
5. **No import progress.** `importFile` is a single awaited copy. The UI shows indeterminate progress.
6. **Preview needs its own player.** The coordinator's player drives the desktop wallpaper. Previews
   use a separate `VideoPlaybackController` instance (existing backend class), muted by default,
   released when the preview closes.
7. **A plan can have no role.** With automatic switching off and no remembered role, `role == nil`,
   `mediaID == nil`, `issue == nil`, and the coordinator hides the wallpaper. UI must treat this as
   "no wallpaper active", not an error.
8. **Launch-at-login status** is `SMAppService.Status`; the app must `import ServiceManagement` to
   show `.requiresApproval` and similar states.
9. **Startup can fail.** `MediaLibraryStore.init` and `AppSettingsStore.load()` throw. The
   composition root exposes a failure state that drives the backend-initialization error screen.
10. **Manual override exists** (`manualOverrideEnabled`, `manualWallpaperID`, `setUserPaused`). It is not
    in the brief's screen list; Task 4 exposes pause, and manual "play now" only if you approve.

## Suspected compile risks (unverified, report only)

- `DesktopWallpaperWindow.init(screen:)` calls `super.init(contentRect:styleMask:backing:defer:screen:)`.
  I believe AppKit imports that initializer as a convenience initializer, which a subclass designated
  initializer cannot call. If Xcode reports this, the minimal fix is to call the designated
  `init(contentRect:styleMask:backing:defer:)` and set the screen frame afterwards. Not changed.
- `IOKitPowerMonitor.deinit` and `DesktopWallpaperWindowManager.deinit` touch main-actor state from a
  nonisolated `deinit`. Expect warnings in Swift 5 mode.

No backend file was modified.

## Task 3 cross-check

Every backend member used by the composition root was re-checked against the dump: `AppSettingsStore`
(`init()`, `load`, `save`, `deleteStoredSettings`, `settingsFileURL`), `MediaLibraryStore()` (throws),
the four service initializers, `WallpaperCoordinator.init` labels and order, `start()`, `stop()`,
`updateSettings(_:)`, `isRunning`, `currentPlan`, `PlaybackEnvironment.stopMonitoring()`,
`LaunchAtLoginManager.status` and `setEnabled(_:)`. All exist and are `public`. This is a check against
the dump, not against a compiler. Gap 9 (startup can fail) is now handled by `AppEnvironment`.
