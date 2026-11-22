import SwiftUI

/// 4-pt spacing scale.
enum CMSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner radii by role. Larger containers get larger radii; controls stay tighter.
enum CMRadius {
    static let control: CGFloat = 10
    static let tile: CGFloat = 14
    static let card: CGFloat = 20
    static let stage: CGFloat = 28
}

enum CMLayout {
    static let minWindowWidth: CGFloat = 980
    static let minWindowHeight: CGFloat = 640
    static let defaultWindowWidth: CGFloat = 1180
    static let defaultWindowHeight: CGFloat = 780
    static let sidebarWidth: CGFloat = 232
    static let contentMaxWidth: CGFloat = 1120
}

/// Appearance preference stored in UserDefaults. This is a UI preference owned by the
/// frontend; it is deliberately not added to the backend `AppSettings` model.
enum CMAppearancePreference: String, CaseIterable, Identifiable {
    case dark, light, system

    static let storageKey = "cm.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "Match system"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return ColorScheme.dark
        case .light: return ColorScheme.light
        case .system: return nil
        }
    }
}
