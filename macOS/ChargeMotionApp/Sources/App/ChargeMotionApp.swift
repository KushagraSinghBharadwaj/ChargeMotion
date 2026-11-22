import SwiftUI

/// Application entry point. A single `Window` (not `WindowGroup`) guarantees one shell, so
/// only one set of frontend models exists.
@main
struct ChargeMotionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage(CMAppearancePreference.storageKey)
    private var appearanceRaw: String = CMAppearancePreference.dark.rawValue

    private var appearance: CMAppearancePreference {
        CMAppearancePreference(rawValue: appearanceRaw) ?? .dark
    }

    var body: some Scene {
        Window("ChargeMotion", id: "main") {
            StartupGateView(environment: appDelegate.environment)
                .frame(minWidth: CMLayout.minWindowWidth, minHeight: CMLayout.minWindowHeight)
                .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: CMLayout.defaultWindowWidth, height: CMLayout.defaultWindowHeight)
        .commands { NavigationCommands() }
    }
}
