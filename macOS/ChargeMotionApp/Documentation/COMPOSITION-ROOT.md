# Composition root and application lifecycle (Task 3)

Status: written, **not compiled**. Needs Xcode verification (see the end of this file).

## Ownership

```
ChargeMotionApp (App)
  @NSApplicationDelegateAdaptor -> AppDelegate
                                     └─ environment: AppEnvironment      (one per process)
                                          └─ phase: .running(AppServices)
                                                      ├─ settingsStore        AppSettingsStore
                                                      ├─ mediaLibrary         MediaLibraryStore
                                                      ├─ powerMonitor         IOKitPowerMonitor
                                                      ├─ playbackEnvironment  PlaybackEnvironment
                                                      ├─ playbackController   VideoPlaybackController  (wallpaper pipeline)
                                                      ├─ windowManager        DesktopWallpaperWindowManager
                                                      ├─ coordinator          WallpaperCoordinator
                                                      ├─ settings             SettingsController      (frontend)
                                                      └─ launchAtLogin        LaunchAtLoginController (frontend)
```

`AppDelegate` owns the `AppEnvironment` so it exists before any window and is reachable from both
the lifecycle callbacks and the SwiftUI scene. The scene only observes it.

## Phases

| Phase | Meaning | UI (StartupGateView) |
|---|---|---|
| `notStarted` | Nothing created yet | Progress |
| `starting` | Loading settings, creating services, starting the coordinator | Progress |
| `running(AppServices)` | Every service exists and the coordinator has started | Main content |
| `failed(StartupFailure)` | A startup step threw; no services were created | Failure screen |
| `shuttingDown` / `stopped` | Quit in progress / finished | Progress |

An `AppServices` value only exists inside `.running`, so no view can read power state from a
monitor that has not started.

## Startup sequence (`AppEnvironment.performStart`)

1. `AppSettingsStore.load()`. Throws -> `.failed(.settingsUnreadable)`.
2. `MediaLibraryStore()`. Throws -> `.failed(.mediaLibraryUnavailable)`.
3. Create one each of `IOKitPowerMonitor`, `PlaybackEnvironment`, `VideoPlaybackController`,
   `DesktopWallpaperWindowManager`, then `WallpaperCoordinator(mediaLibrary:settings:powerMonitor:playbackController:windowManager:playbackEnvironment:)`.
   Every collaborator is passed explicitly, so the coordinator's default arguments never run.
4. `await coordinator.start()`: starts the power monitor (immediate read) and applies the first plan.
5. Build `SettingsController` and `LaunchAtLoginController`, then publish `.running`.

Services are created only after both throwing steps succeed, so a failed start leaves no timers,
observers or windows behind. `PlaybackEnvironment` begins observing as soon as it is created; this
is why creation happens at step 3 and not in `init`.

## Shutdown sequence (`AppEnvironment.shutdown`)

Triggered by `applicationShouldTerminate`, which returns `.terminateLater` and replies when done.

1. Wait for any start in progress.
2. `SettingsController.flush()`: wait for queued apply/save work.
3. `WallpaperCoordinator.stop()`: stops power monitoring, cancels subscriptions, stops playback and
   hides all wallpaper windows (revealing the original macOS wallpaper).
4. `PlaybackEnvironment.stopMonitoring()`: removes observers and the fullscreen timer.
5. Phase `.stopped`; `AppServices` is released.

Closing the last window does **not** quit the app (`applicationShouldTerminateAfterLastWindowClosed`
is false), so the wallpaper keeps playing. Quit from the menu or Dock.

## Settings flow

`SettingsController.update { $0.field = value }`:

1. Mutates a copy; returns if nothing changed.
2. Publishes the new value immediately (UI stays responsive).
3. Queues, on a serial chain: `coordinator.updateSettings(_:)`, then `AppSettingsStore.save(_:)`.

The chain guarantees changes reach the coordinator and disk in order. A failed save sets
`lastSaveError` (cleared by the next success); the in-memory and coordinator state stay applied.
Settings are never held in the app before they are loaded: `SettingsController` is created from the
loaded value.

## Failure states

| Failure | Cause | Actions |
|---|---|---|
| `settingsUnreadable` | `AppSettingsStore.load()` threw (corrupt JSON or unreadable file) | Retry, Reset settings |
| `settingsResetFailed` | Deleting the settings file threw | Retry |
| `mediaLibraryUnavailable` | `MediaLibraryStore()` threw (folder or catalog unreadable) | Retry |

Reset deletes the settings file through `AppSettingsStore.deleteStoredSettings()` only after the
person chooses it. It does not touch the media library. The media catalog has no reset action.

## Launch at login

`LaunchAtLoginController` wraps `LaunchAtLoginManager` and publishes `SMAppService.Status`, because
registering is not the same as being approved. Not stored in `AppSettings`.

## Not in this task

Dashboard and screens, import UI, preview player, display management, 3D hero, and removal of
dangling wallpaper IDs after a video is deleted (Task 5 will update settings when removing media).

## Needs Xcode verification

- The whole project compiles, including the never-compiled backend.
- `NSApplicationDelegateAdaptor` with a `@MainActor` delegate that owns a `@MainActor` environment.
- `Task { [self] ... }` and `Task { [environment] ... }` compile without isolation errors in Swift 5 mode.
- Quit performs `.terminateLater` and then terminates (no hang).
- With a valid `settings.json`, the diagnostics card shows live power state; with a corrupt file, the failure
  screen appears and Reset recovers.
- `SMAppService` status reads without crashing for an ad-hoc signed build.
