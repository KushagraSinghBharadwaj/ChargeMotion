# Wallpaper Coordinator

## Responsibility

`WallpaperCoordinator` is the orchestration layer between:

- `IOKitPowerMonitor` — current power state
- `AppSettings` and `WallpaperPolicy` — selected role and pause reasons
- `MediaLibraryStore` — resolves selected media IDs to managed file URLs
- `VideoPlaybackController` — owns the AVFoundation looping player
- `DesktopWallpaperWindowManager` — presents the player behind desktop icons

## Startup

Create a `MediaLibraryStore`, then inject it into `WallpaperCoordinator`.
Call `await coordinator.start()` and retain the coordinator for the lifetime of
the wallpaper feature.

The coordinator subscribes to power-state changes and reconciles the wallpaper
plan whenever the power state changes.

## Settings

Call `await coordinator.updateSettings(_:)` after the user changes settings.
The selected charging, battery, or manual media ID must already exist in the
media library. Missing selections produce a plan issue and hide the wallpaper.

## Runtime conditions

The frontend or a future system-environment monitor can call
`await coordinator.updateConditions(_:)` to update fullscreen, lock, sleep,
low-power, and manual-pause conditions.

## Multi-display behavior

The coordinator shares one AVPlayer across all connected display windows. This
keeps playback synchronized and avoids decoding duplicate copies of the same
video. The window manager creates one click-through window per screen.

## Persistence and system monitoring boundaries

This component receives `AppSettings` as a value. It does not persist settings.
The frontend/application layer must load and save settings and pass updates here.

Only power monitoring is wired in this batch. Fullscreen detection, lock state,
sleep/wake state, and Low Power Mode monitoring are not yet implemented.

## Validation

This code has not been compiled on macOS. Run `swift test` on a Mac with Xcode
command-line tools, then verify charging/battery switching and multiple displays.
