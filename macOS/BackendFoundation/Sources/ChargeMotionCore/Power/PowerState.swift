import Foundation

/// Raw operating-system facts. nil means that the value could not be determined.
public struct PowerSnapshot: Equatable, Sendable {
    public var readSucceeded: Bool
    public var hasInternalBattery: Bool
    public var isOnExternalPower: Bool?
    public var isCharging: Bool?
    public var isCharged: Bool?
    public var batteryPercent: Int?

    public init(
        readSucceeded: Bool = true,
        hasInternalBattery: Bool = false,
        isOnExternalPower: Bool? = nil,
        isCharging: Bool? = nil,
        isCharged: Bool? = nil,
        batteryPercent: Int? = nil
    ) {
        self.readSucceeded = readSucceeded
        self.hasInternalBattery = hasInternalBattery
        self.isOnExternalPower = isOnExternalPower
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.batteryPercent = batteryPercent.map { min(100, max(0, $0)) }
    }

    public static let unreadable = PowerSnapshot(readSucceeded: false)
}

public enum PowerState: String, Codable, CaseIterable, Sendable {
    case onBattery
    case externalPowerCharging
    case externalPowerFullyCharged
    case externalPowerNotCharging
    case noBatteryDesktop
    case unknown

    public var isExternalPowerConnected: Bool? {
        switch self {
        case .onBattery: false
        case .externalPowerCharging, .externalPowerFullyCharged,
             .externalPowerNotCharging, .noBatteryDesktop: true
        case .unknown: nil
        }
    }

    public var title: String {
        switch self {
        case .onBattery: "Running on battery"
        case .externalPowerCharging: "Connected to power - Charging"
        case .externalPowerFullyCharged: "Connected to power - Fully charged"
        case .externalPowerNotCharging: "Connected to power - Not charging"
        case .noBatteryDesktop: "Desktop Mac - External power"
        case .unknown: "Power state unavailable"
        }
    }
}

/// Pure interpretation logic, deliberately separated from IOKit for testability.
public enum PowerStateInterpreter {
    public static func interpret(_ snapshot: PowerSnapshot) -> PowerState {
        guard snapshot.readSucceeded else { return .unknown }
        guard snapshot.hasInternalBattery else { return .noBatteryDesktop }
        guard let external = snapshot.isOnExternalPower else { return .unknown }
        guard external else { return .onBattery }

        if snapshot.isCharged == true ||
            ((snapshot.batteryPercent ?? 0) >= 100 && snapshot.isCharging != true) {
            return .externalPowerFullyCharged
        }

        if snapshot.isCharging == true {
            return .externalPowerCharging
        }

        if snapshot.isCharging == false {
            return .externalPowerNotCharging
        }

        return .unknown
    }
}
