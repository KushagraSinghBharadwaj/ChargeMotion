# ChargeMotion macOS backend foundation

This is the first backend source batch for the native ChargeMotion macOS app.

## Included
- Pure power-state model and interpreter.
- Parser for IOKit power-source dictionaries.
- Backward-compatible settings model.
- Deterministic wallpaper selection and pause policy.
- Unit tests for power interpretation and switching policy.

## Platform
- macOS 14+
- Swift tools 5.9+
- Intel and Apple Silicon targets (actual compatibility must be verified on Mac).

## Build and test on a Mac
From this directory:

```sh
swift test
```

This foundation package intentionally has no UI and no AppKit/SwiftUI dependency. Later backend batches add the IOKit monitor, managed media library, AVFoundation playback, desktop windows, display management, and system event integration. Claude can build the frontend against these stable public models after the backend API is reviewed.

## Important
This source has not been compiled in this Windows environment. Run `swift test` on macOS before integrating it into the application.
