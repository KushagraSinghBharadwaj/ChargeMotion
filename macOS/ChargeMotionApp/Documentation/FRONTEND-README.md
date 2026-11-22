# ChargeMotion macOS frontend

Native SwiftUI app. Backend: local Swift package `../BackendFoundation` (`ChargeMotionCore`).
All frontend work lives in `macOS/ChargeMotionApp/`. The Windows app is untouched.

## Layout

```
ChargeMotionApp/
  project.yml                 XcodeGen spec (generates ChargeMotion.xcodeproj)
  Config/Info.plist           Real, committed Info.plist (build settings fill the $(...) values)
  Sources/
    App/                      @main entry, AppDelegate (lifecycle), StartupGateView
    Environment/              Composition root: AppEnvironment, AppServices, SettingsController,
                              LaunchAtLoginController, StartupFailure
    DesignSystem/             CMColor, CMTypography, CMLayout, CMMotion,
                              CMSurfaces, CMButtonStyles, CMComponents
    Preview/                  Temporary design-system screen + diagnostics (removed in Task 4)
  Resources/Assets.xcassets   AccentColor, AppIcon (icon artwork still to come)
  Documentation/              this file, API review, progress, handoff
```

## Requirements

- macOS 14 or later, Xcode 15 or later
- XcodeGen: `brew install xcodegen`

## Build (on a Mac)

```sh
cd macOS/ChargeMotionApp
xcodegen generate
open ChargeMotion.xcodeproj
```

Select the **ChargeMotion** scheme and **My Mac**, then Build (Cmd+B) and Run (Cmd+R).

If you prefer not to use XcodeGen: File > New > Project > macOS App (SwiftUI), name it ChargeMotion,
add `../BackendFoundation` via File > Add Package Dependencies > Add Local, link `ChargeMotionCore`,
and drag `Sources/` and `Resources/` in. Set the deployment target to macOS 14.

## Expected first-build behavior

- The backend has never been compiled. Compile errors in `BackendFoundation` are possible; send them
  to the frontend assistant instead of editing the backend.
- Warnings that `AppIcon` has no images are expected until the icon task.
- The window first shows "Starting ChargeMotion", then the design-system preview with a
  "Composition root diagnostics" card at the top. That card shows live values (coordinator running,
  real power state, battery level, wallpaper plan). The "Backend link check" card further down
  lists the six `PowerState` model cases and is not live.
- If `settings.json` is unreadable, a failure screen with Retry and Reset settings appears instead.
- Architecture and lifecycle: `COMPOSITION-ROOT.md`.

## Info.plist

`Config/Info.plist` is a real file referenced by `INFOPLIST_FILE` in `project.yml`
(`GENERATE_INFOPLIST_FILE: NO`). It is listed under sources with `buildPhase: none` so it appears in
Xcode but is never copied into the app bundle as a resource. XcodeGen's `info:` generator is not used.

## Decisions

- **App Sandbox is off** for first builds: the backend reads IOKit, lists on-screen windows and creates
  desktop-level windows. Revisit for distribution.
- **Bundle identifier** is `com.chargemotion.macos` (placeholder; change in `project.yml`).
- **Signing** is "Sign to Run Locally". Launch at login (`SMAppService`) may need a properly signed,
  installed build to validate.
- **Appearance** (dark, light, system; default dark) is a UI preference in UserDefaults, not an
  `AppSettings` field.
- **3D hero** (SceneKit vs RealityKit) is decided in the hero task after checking Apple's current guidance.

## Known limitations

Compiled and run nowhere yet. All native behavior requires validation on a Mac.
