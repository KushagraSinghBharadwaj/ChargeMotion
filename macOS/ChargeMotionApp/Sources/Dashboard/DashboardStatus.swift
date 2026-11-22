import SwiftUI
import ServiceManagement
import ChargeMotionCore

// Presentation logic only: real backend values mapped to words, icons and tones.

struct PowerPresentation {
    let label: String
    let detail: String
    let systemImage: String
    let tone: CMTone
}

extension PowerState {
    var presentation: PowerPresentation {
        switch self {
        case .onBattery: return PowerPresentation(label: "On Battery", detail: title, systemImage: "battery.50", tone: .info)
        case .externalPowerCharging: return PowerPresentation(label: "Charging", detail: title, systemImage: "bolt.fill", tone: .accent)
        case .externalPowerFullyCharged: return PowerPresentation(label: "Fully Charged", detail: title, systemImage: "battery.100", tone: .accent)
        case .externalPowerNotCharging: return PowerPresentation(label: "Plugged In", detail: title, systemImage: "powerplug.fill", tone: .accent)
        case .noBatteryDesktop: return PowerPresentation(label: "Desktop Power", detail: title, systemImage: "desktopcomputer", tone: .accent)
        case .unknown: return PowerPresentation(label: "Unknown", detail: title, systemImage: "questionmark.circle", tone: .warning)
        }
    }
}

extension PauseReason {
    var userFacingTitle: String {
        switch self {
        case .userPaused: return "Paused by you"
        case .systemAsleep: return "Mac is asleep"
        case .sessionInactive: return "Session is inactive"
        case .screenLocked: return "Screen is locked"
        case .displaysAsleep: return "Displays are asleep"
        case .lowPowerMode: return "Low Power Mode is on"
        case .fullScreenApp: return "A full-screen app is in front"
        case .onBattery: return "Paused on battery (setting)"
        }
    }
}

struct PlaybackSummary {
    let title: String
    let detail: String?
    let systemImage: String
    let tone: CMTone

    /// A plan with no role means "no wallpaper active", not an error.
    static func make(running: Bool, plan: WallpaperPlan?, error: String?, isPlaying: Bool, automatic: Bool) -> PlaybackSummary {
        guard running else { return .init(title: "Stopped", detail: "The wallpaper engine isn't running.", systemImage: "stop.circle", tone: .warning) }
        guard let plan else { return .init(title: "Starting", detail: nil, systemImage: "hourglass", tone: .neutral) }
        if plan.role == nil {
            return .init(title: "No wallpaper active",
                         detail: automatic ? "Waiting for a readable power state." : "Automatic switching is off and no wallpaper has been chosen yet.",
                         systemImage: "moon.zzz", tone: .neutral)
        }
        if let issue = plan.issue { return .init(title: "Needs a video", detail: issue, systemImage: "exclamationmark.triangle.fill", tone: .warning) }
        if let error { return .init(title: "Playback failed", detail: error, systemImage: "xmark.octagon.fill", tone: .danger) }
        if !plan.pauseReasons.isEmpty {
            return .init(title: "Paused", detail: plan.pauseReasons.map(\.userFacingTitle).joined(separator: " · "), systemImage: "pause.circle.fill", tone: .warning)
        }
        return isPlaying ? .init(title: "Playing", detail: nil, systemImage: "play.circle.fill", tone: .accent)
                         : .init(title: "Starting playback", detail: nil, systemImage: "hourglass", tone: .neutral)
    }
}

struct DashboardWarning: Identifiable {
    let id: String
    let tone: CMTone
    let systemImage: String
    let title: String
    let message: String
    let target: SidebarItem?
}

enum DashboardWarningBuilder {
    static func make(
        powerState: PowerState, readSucceeded: Bool, plan: WallpaperPlan?, coordinatorError: String?,
        assetCount: Int, catalogLoaded: Bool, saveError: String?, loginStatus: SMAppService.Status,
        connectedIDs: [UInt32], activeIDs: [UInt32]
    ) -> [DashboardWarning] {
        var out: [DashboardWarning] = []
        if catalogLoaded && assetCount == 0 {
            out.append(.init(id: "no-videos", tone: .info, systemImage: "film.stack", title: "No videos imported",
                             message: "Import a video to use as your charging or battery wallpaper.", target: .videoLibrary))
        }
        if let issue = plan?.issue {
            out.append(.init(id: "plan-issue", tone: .warning, systemImage: "film.stack", title: "Wallpaper needs a video",
                             message: issue, target: .videoLibrary))
        }
        if let coordinatorError, plan?.issue == nil {
            out.append(.init(id: "playback-error", tone: .danger, systemImage: "xmark.octagon.fill",
                             title: "The wallpaper couldn't be played", message: coordinatorError, target: .videoLibrary))
        }
        if powerState == .unknown {
            out.append(.init(id: "power-unknown", tone: .warning, systemImage: "questionmark.circle", title: "Power state unavailable",
                             message: (readSucceeded ? "The power source reported a state ChargeMotion can't interpret." : "ChargeMotion couldn't read this Mac's power sources.") + " The last known wallpaper stays active.",
                             target: nil))
        }
        if let plan, plan.mediaID != nil, plan.issue == nil {
            let reasons = plan.pauseReasons.filter { $0 != .userPaused }
            if !reasons.isEmpty {
                out.append(.init(id: "paused", tone: .info, systemImage: "pause.circle.fill", title: "Playback is paused",
                                 message: reasons.map(\.userFacingTitle).joined(separator: " · "), target: .settings))
            }
        }
        if let saveError {
            out.append(.init(id: "save", tone: .danger, systemImage: "externaldrive.badge.exclamationmark", title: "Settings couldn't be saved",
                             message: "Your latest change is applied for now but may be lost when you quit. \(saveError)", target: nil))
        }
        if loginStatus == .requiresApproval {
            out.append(.init(id: "login", tone: .info, systemImage: "person.badge.key", title: "Launch at login needs approval",
                             message: "Approve ChargeMotion in System Settings > General > Login Items.", target: .settings))
        }
        if let plan, plan.mediaID != nil, plan.issue == nil, coordinatorError == nil {
            let missing = connectedIDs.filter { !activeIDs.contains($0) }
            if !missing.isEmpty {
                out.append(.init(id: "windows", tone: .info, systemImage: "display.trianglebadge.exclamationmark",
                                 title: "No wallpaper window reported on \(missing.count) display\(missing.count == 1 ? "" : "s")",
                                 message: "The window manager lists no wallpaper window for them.", target: .displays))
            }
        }
        return out
    }
}
