import Foundation

public enum VideoScalingMode: String, Codable, CaseIterable, Sendable {
    case fill
    case fit
    case stretch
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var automaticSwitchingEnabled = true
    public var chargingWallpaperID: UUID?
    public var batteryWallpaperID: UUID?
    public var manualOverrideEnabled = false
    public var manualWallpaperID: UUID?

    public var pauseOnLowPowerMode = false
    public var pauseOnFullScreenApp = false
    public var pauseWhileScreenLocked = true
    public var pauseWhenDisplaysSleep = true
    public var pauseOnBattery = false

    public var scalingMode: VideoScalingMode = .fill
    public var allowAudio = false
    public var audioMuted = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case automaticSwitchingEnabled, chargingWallpaperID, batteryWallpaperID
        case manualOverrideEnabled, manualWallpaperID
        case pauseOnLowPowerMode, pauseOnFullScreenApp, pauseWhileScreenLocked
        case pauseWhenDisplaysSleep, pauseOnBattery, scalingMode, allowAudio, audioMuted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        automaticSwitchingEnabled = try c.decodeIfPresent(Bool.self, forKey: .automaticSwitchingEnabled) ?? defaults.automaticSwitchingEnabled
        chargingWallpaperID = try c.decodeIfPresent(UUID.self, forKey: .chargingWallpaperID)
        batteryWallpaperID = try c.decodeIfPresent(UUID.self, forKey: .batteryWallpaperID)
        manualOverrideEnabled = try c.decodeIfPresent(Bool.self, forKey: .manualOverrideEnabled) ?? defaults.manualOverrideEnabled
        manualWallpaperID = try c.decodeIfPresent(UUID.self, forKey: .manualWallpaperID)
        pauseOnLowPowerMode = try c.decodeIfPresent(Bool.self, forKey: .pauseOnLowPowerMode) ?? defaults.pauseOnLowPowerMode
        pauseOnFullScreenApp = try c.decodeIfPresent(Bool.self, forKey: .pauseOnFullScreenApp) ?? defaults.pauseOnFullScreenApp
        pauseWhileScreenLocked = try c.decodeIfPresent(Bool.self, forKey: .pauseWhileScreenLocked) ?? defaults.pauseWhileScreenLocked
        pauseWhenDisplaysSleep = try c.decodeIfPresent(Bool.self, forKey: .pauseWhenDisplaysSleep) ?? defaults.pauseWhenDisplaysSleep
        pauseOnBattery = try c.decodeIfPresent(Bool.self, forKey: .pauseOnBattery) ?? defaults.pauseOnBattery
        scalingMode = try c.decodeIfPresent(VideoScalingMode.self, forKey: .scalingMode) ?? defaults.scalingMode
        allowAudio = try c.decodeIfPresent(Bool.self, forKey: .allowAudio) ?? defaults.allowAudio
        audioMuted = try c.decodeIfPresent(Bool.self, forKey: .audioMuted) ?? defaults.audioMuted
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(automaticSwitchingEnabled, forKey: .automaticSwitchingEnabled)
        try c.encodeIfPresent(chargingWallpaperID, forKey: .chargingWallpaperID)
        try c.encodeIfPresent(batteryWallpaperID, forKey: .batteryWallpaperID)
        try c.encode(manualOverrideEnabled, forKey: .manualOverrideEnabled)
        try c.encodeIfPresent(manualWallpaperID, forKey: .manualWallpaperID)
        try c.encode(pauseOnLowPowerMode, forKey: .pauseOnLowPowerMode)
        try c.encode(pauseOnFullScreenApp, forKey: .pauseOnFullScreenApp)
        try c.encode(pauseWhileScreenLocked, forKey: .pauseWhileScreenLocked)
        try c.encode(pauseWhenDisplaysSleep, forKey: .pauseWhenDisplaysSleep)
        try c.encode(pauseOnBattery, forKey: .pauseOnBattery)
        try c.encode(scalingMode, forKey: .scalingMode)
        try c.encode(allowAudio, forKey: .allowAudio)
        try c.encode(audioMuted, forKey: .audioMuted)
    }
}
