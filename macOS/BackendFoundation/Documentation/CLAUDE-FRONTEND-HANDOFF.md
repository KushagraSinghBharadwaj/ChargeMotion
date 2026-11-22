# ChargeMotion macOS — Frontend Integration Handoff

## Project architecture

ChargeMotion macOS is a native macOS application.
The backend is the Swift package `ChargeMotionCore`.
Minimum deployment target: macOS 14.
Supported processor targets: Intel and Apple Silicon, subject to Mac validation.

The frontend should be implemented separately using SwiftUI and AppKit.
Do not rewrite the backend or modify the Windows application.

## Backend responsibilities

- Power monitoring: IOKit power source monitoring.
- Power interpretation: charging, battery, fully charged, external power and unknown states.
- Wallpaper policy: selects charging or battery media and determines pause reasons.
- Media library: imports, lists, renames and removes managed video files.
- Playback: AVFoundation video playback and looping.
- Desktop windows: desktop-level windows and display management.
- Coordination: connects power, settings, media, playback and desktop windows.
- Environment monitoring: Low Power Mode, screen lock, sleep/wake and fullscreen detection.
- Settings persistence: JSON settings storage.
- Launch at login: optional macOS ServiceManagement integration.

## Important product behavior

1. Charging and battery wallpapers are independently configurable.
2. Switching should follow the detected power state automatically.
3. Fully charged on external power uses the charging wallpaper role.
4. Unknown power state must not cause an unsafe wallpaper switch.
5. Manual pause and configured power-saving conditions must be respected.
6. Hiding or stopping desktop windows reveals the original macOS wallpaper.
7. Do not implement account login/logout.
8. Launch at login is optional and is not account authentication.
9. Do not promise animated lock-screen wallpaper.
10. Do not change the existing Windows application.

## Frontend integration

Use the public types and APIs in `ChargeMotionCore` rather than duplicating backend logic.

The frontend should provide:
- Charging wallpaper selection.
- Battery wallpaper selection.
- Video library import and management.
- Playback and manual pause controls.
- Automatic switching setting.
- Playback and power-saving preferences.
- Launch at login preference.
- Clear permission, import and playback error states.
- Multi-display status where practical.

The frontend must load persisted settings at application startup and save changes through `AppSettingsStore`.

The app composition root should create and retain the media library, settings store, power monitor, playback environment, playback controller, desktop window manager and wallpaper coordinator. Avoid creating duplicate monitoring instances.

Start the coordinator when the application is ready. Stop it when the application is shutting down.

## Integration requirements

- Keep all macOS frontend files under `macOS/`.
- Keep backend source under `macOS/BackendFoundation/`.
- Do not copy backend implementation into the frontend.
- Do not modify Windows source files.
- Build and test with Xcode on macOS.
- Resolve Swift compiler errors before adding visual effects.
- Verify charging transitions, battery transitions, video looping, sleep/wake, screen lock and multiple displays on real hardware.

## Validation status

The backend source has been authored on Windows.
It has not yet been compiled or tested with the Swift compiler.
A successful PowerShell simulation is not proof of native macOS behavior.
Mac compilation, unit tests and hardware validation are still required.