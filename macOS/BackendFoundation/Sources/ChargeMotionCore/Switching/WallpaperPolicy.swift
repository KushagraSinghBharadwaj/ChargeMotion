import Foundation

public enum WallpaperRole: String, Codable, Sendable {
    case charging
    case battery
    case manual
}

public enum PauseReason: String, Codable, CaseIterable, Sendable {
    case userPaused
    case systemAsleep
    case sessionInactive
    case screenLocked
    case displaysAsleep
    case lowPowerMode
    case fullScreenApp
    case onBattery
}

public struct SystemConditions: Equatable, Sendable {
    public var powerState: PowerState = .unknown
    public var lowPowerModeEnabled = false
    public var fullScreenAppActive = false
    public var screenLocked = false
    public var displaysAsleep = false
    public var systemAsleep = false
    public var sessionInactive = false
    public var userPaused = false

    public init() {}
}

public struct WallpaperPlan: Equatable, Sendable {
    public let role: WallpaperRole?
    public let mediaID: UUID?
    public let pauseReasons: [PauseReason]
    public let issue: String?

    public var shouldPlay: Bool {
        mediaID != nil && issue == nil && pauseReasons.isEmpty
    }
}

public enum WallpaperPolicy {
    /// Unknown power state preserves the last known role rather than unexpectedly switching.
    public static func role(for state: PowerState, fallback: WallpaperRole?) -> WallpaperRole? {
        switch state {
        case .onBattery: .battery
        case .externalPowerCharging, .externalPowerFullyCharged,
             .externalPowerNotCharging, .noBatteryDesktop: .charging
        case .unknown: fallback
        }
    }

    public static func makePlan(
        settings: AppSettings,
        conditions: SystemConditions,
        chargingMediaID: UUID?,
        batteryMediaID: UUID?,
        manualMediaID: UUID?,
        fallbackRole: WallpaperRole?
    ) -> WallpaperPlan {
        var role: WallpaperRole?
        var mediaID: UUID?

        if settings.manualOverrideEnabled {
            role = .manual
            mediaID = settings.manualWallpaperID ?? manualMediaID
        } else if settings.automaticSwitchingEnabled {
            role = self.role(for: conditions.powerState, fallback: fallbackRole)
            switch role {
            case .charging: mediaID = chargingMediaID
            case .battery: mediaID = batteryMediaID
            default: mediaID = nil
            }
        } else {
            role = fallbackRole
            switch role {
            case .charging: mediaID = chargingMediaID
            case .battery: mediaID = batteryMediaID
            default: mediaID = nil
            }
        }

        let reasons = pauseReasons(settings: settings, conditions: conditions)
        let issue: String?
        if role == .manual && mediaID == nil {
            issue = "Manual override is enabled but no video is selected."
        } else if role == .charging && mediaID == nil {
            issue = "No charging wallpaper has been assigned."
        } else if role == .battery && mediaID == nil {
            issue = "No battery wallpaper has been assigned."
        } else {
            issue = nil
        }

        return WallpaperPlan(role: role, mediaID: mediaID, pauseReasons: reasons, issue: issue)
    }

    public static func pauseReasons(
        settings: AppSettings,
        conditions: SystemConditions
    ) -> [PauseReason] {
        var result: [PauseReason] = []
        if conditions.userPaused { result.append(.userPaused) }
        if conditions.systemAsleep { result.append(.systemAsleep) }
        if conditions.sessionInactive { result.append(.sessionInactive) }
        if settings.pauseWhileScreenLocked && conditions.screenLocked { result.append(.screenLocked) }
        if settings.pauseWhenDisplaysSleep && conditions.displaysAsleep { result.append(.displaysAsleep) }
        if settings.pauseOnLowPowerMode && conditions.lowPowerModeEnabled { result.append(.lowPowerMode) }
        if settings.pauseOnFullScreenApp && conditions.fullScreenAppActive { result.append(.fullScreenApp) }
        if settings.pauseOnBattery && conditions.powerState == .onBattery { result.append(.onBattery) }
        return result
    }
}
