# ChargeMotion AVFoundation Playback Engine

## Scope

`VideoPlaybackController` owns one AVFoundation video pipeline. It is independent of
SwiftUI and can be used by a future AppKit desktop-window renderer.

## Features

- MP4, MOV, and M4V input validation
- AVQueuePlayer with a retained AVPlayerLooper for looping
- Muted-by-default playback
- Play, pause, stop, volume, and playback-rate controls
- One controller per display is supported by design

## Frontend integration

The frontend can observe `isPlaying`, `currentURL`, and `lastError`. It can attach
`controller.player` to an `AVPlayerLayer` hosted in an AppKit view. Do not create a
second player in the frontend.

The caller should obtain managed media URLs from `MediaLibraryStore.fileURL(for:)`
and pass the returned URL to `load(url:)`.

## Important limitations

This component does not create desktop-level windows, manage screens, detect fullscreen
apps, or decide which charging/battery video should be selected. Those are separate
components in the backend architecture.

## Validation

The XCTest file covers invalid extensions, missing files, and stop-state behavior.
This package has not been compiled on Windows. Run `swift test` on macOS with Xcode
command-line tools installed.
