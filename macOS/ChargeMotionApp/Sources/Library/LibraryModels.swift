import Foundation
import UniformTypeIdentifiers
import ChargeMotionCore

/// The wallpaper slots a video can be assigned to; maps onto the existing
/// `AppSettings.chargingWallpaperID` and `batteryWallpaperID`. No new settings are introduced.
enum WallpaperAssignmentRole: String, CaseIterable, Identifiable {
    case charging, battery
    var id: String { rawValue }
    var title: String { self == .charging ? "Charging" : "Battery" }
    var systemImage: String { self == .charging ? "bolt.fill" : "battery.50" }
    var sidebarItem: SidebarItem { self == .charging ? .chargingWallpaper : .batteryWallpaper }
    var backendRole: WallpaperRole { self == .charging ? .charging : .battery }

    func assignedID(in s: AppSettings) -> UUID? { self == .charging ? s.chargingWallpaperID : s.batteryWallpaperID }
    func apply(_ id: UUID?, to s: inout AppSettings) {
        if self == .charging { s.chargingWallpaperID = id } else { s.batteryWallpaperID = id }
    }
}

extension WallpaperRole {
    var displayTitle: String {
        switch self {
        case .charging: return "Charging"
        case .battery: return "Battery"
        case .manual: return "Manual"
        }
    }
}

/// The backend keeps its format list private, so this mirrors it for the open panel and for
/// early messages. The backend still validates every import.
enum SupportedVideoFormats {
    static let fileExtensions = ["mp4", "mov", "m4v"]
    static let readableList = "MP4, MOV or M4V"
    static var contentTypes: [UTType] { fileExtensions.compactMap { UTType(filenameExtension: $0) } }
    static func isSupported(_ url: URL) -> Bool { fileExtensions.contains(url.pathExtension.lowercased()) }
}

enum VideoFormatting {
    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "--:--" }
        let t = Int(seconds.rounded())
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    static func fileSize(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    static func date(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }
}
