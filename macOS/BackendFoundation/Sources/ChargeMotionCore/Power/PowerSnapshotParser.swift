import Foundation

/// Parses dictionaries returned by IOPSCopyPowerSourcesList/IOPSGetPowerSourceDescription.
/// String keys match the public constants in IOKit/ps/IOPSKeys.h.
public enum PowerSnapshotParser {
    public static func parse(
        descriptions: [[String: Any]],
        providingSource: String?
    ) -> PowerSnapshot {
        let battery = descriptions.first {
            ($0["Type"] as? String) == "InternalBattery" &&
            (($0["Is Present"] as? Bool) ?? true)
        }

        guard let battery else {
            // A successful query with no internal battery describes a desktop Mac.
            return PowerSnapshot(hasInternalBattery: false, isOnExternalPower: true)
        }

        let source = (battery["Power Source State"] as? String) ?? providingSource
        let external: Bool?
        switch source {
        case "AC Power", "UPS Power": external = true
        case "Battery Power": external = false
        default: external = nil
        }

        let current = (battery["Current Capacity"] as? NSNumber)?.doubleValue
        let maximum = (battery["Max Capacity"] as? NSNumber)?.doubleValue
        let percent: Int?
        if let current, let maximum, maximum > 0 {
            percent = min(100, max(0, Int((current / maximum * 100).rounded())))
        } else {
            percent = nil
        }

        return PowerSnapshot(
            hasInternalBattery: true,
            isOnExternalPower: external,
            isCharging: battery["Is Charging"] as? Bool,
            isCharged: battery["Is Charged"] as? Bool,
            batteryPercent: percent
        )
    }
}
