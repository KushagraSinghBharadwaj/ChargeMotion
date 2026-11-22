# Playback Environment Monitor

PlaybackEnvironment monitors macOS conditions relevant to wallpaper playback.

## Monitored conditions

- Low Power Mode changes
- Screen lock and unlock notifications
- System sleep and wake
- Application activation and deactivation
- Fullscreen-like windows using a window-coverage heuristic

## Public API

- `snapshot`: Current environment state
- `shouldPausePlayback`: Whether environment policy requests a pause
- `refresh()`: Refreshes power and fullscreen information
- `stopMonitoring()`: Stops timers and removes notification observers

## Frontend integration

Retain one PlaybackEnvironment instance in the app composition root.

The coordinator should observe its published snapshot and combine
`shouldPausePlayback` with the user's playback settings.

Do not let this monitor directly control AVPlayer instances.

## Limitations

Fullscreen detection is heuristic. A maximized window may be detected,
and some native fullscreen or Stage Manager configurations may be missed.

Screen-lock notifications and window-list behavior must be verified
on the target macOS release.

This source has not yet been compiled or tested on macOS.
