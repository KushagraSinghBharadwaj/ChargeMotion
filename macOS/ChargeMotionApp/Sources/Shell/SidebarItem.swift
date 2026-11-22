import SwiftUI

/// Every top-level page. Declaration order is the sidebar order and the Go-menu shortcut order.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard, videoLibrary, displays, chargingWallpaper, batteryWallpaper, settings, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .videoLibrary: return "Video Library"
        case .displays: return "Displays"
        case .chargingWallpaper: return "Charging Wallpaper"
        case .batteryWallpaper: return "Battery Wallpaper"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return "Live power status, the active wallpaper and anything that needs attention."
        case .videoLibrary: return "Import videos, preview them and choose which one plays on each power state."
        case .displays: return "Connected displays and where ChargeMotion is showing wallpaper."
        case .chargingWallpaper: return "The video that plays while your Mac is connected to power."
        case .batteryWallpaper: return "The video that plays while your Mac is running on battery."
        case .settings: return "Playback, power saving and startup preferences."
        case .about: return "About ChargeMotion."
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .videoLibrary: return "film.stack"
        case .displays: return "display.2"
        case .chargingWallpaper: return "bolt.fill"
        case .batteryWallpaper: return "battery.50"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    /// Pages that show the Import Video toolbar button.
    var offersImport: Bool {
        switch self {
        case .dashboard, .videoLibrary, .chargingWallpaper, .batteryWallpaper: return true
        default: return false
        }
    }
}
