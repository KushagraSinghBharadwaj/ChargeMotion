# macOS IOKit Power Monitor

## Purpose
`IOKitPowerMonitor` is the macOS-only adapter between Apple's IOKit Power Sources API and the platform-independent `ChargeMotionCore` power model.

## Behavior
- Reads power sources immediately when `start()` is called.
- Polls every five seconds by default.
- Publishes the raw `PowerSnapshot` and interpreted `PowerState`.
- Does not reload wallpapers itself; the application coordinator should observe `state` and ask the wallpaper policy/controller to recalculate.
- A failed IOKit query produces `.unknown`. The policy layer should preserve its last known wallpaper role instead of guessing.
- A Mac without an internal battery is interpreted as `.noBatteryDesktop`.

## API
```swift
let monitor = IOKitPowerMonitor()
monitor.start()

// Observe monitor.$state from the app's main actor / SwiftUI layer.
// monitor.refresh() can be called to force a read.
// monitor.stop() stops polling.
```

## Integration
This file belongs in the `ChargeMotionCore` Swift package target alongside `PowerState.swift` and `PowerSnapshotParser.swift`. It uses Combine and IOKit, and is intended for macOS 14+.

## Validation still required
This source has not been compiled in the Windows environment. On a Mac, run:
```sh
swift test
swift build
```
Then verify on a MacBook:
1. AC adapter disconnected -> `.onBattery`.
2. AC adapter connected and battery charging -> `.externalPowerCharging`.
3. AC adapter connected and fully charged -> `.externalPowerFullyCharged`.
4. AC adapter connected but not charging -> `.externalPowerNotCharging`.
5. IOKit query failure -> `.unknown`.
6. Desktop Mac without an internal battery -> `.noBatteryDesktop`.

The five-second polling interval is intentionally conservative for this first implementation. A later optimization can add IOKit power-change notifications while retaining polling as a recovery fallback.
