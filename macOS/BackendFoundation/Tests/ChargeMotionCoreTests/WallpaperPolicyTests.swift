import XCTest
@testable import ChargeMotionCore

final class WallpaperPolicyTests: XCTestCase {
    func testChargingAndBatteryAssignmentsAreIndependent() {
        var settings = AppSettings()
        let charging = UUID()
        let battery = UUID()
        settings.chargingWallpaperID = charging
        settings.batteryWallpaperID = battery

        var conditions = SystemConditions()
        conditions.powerState = .externalPowerFullyCharged

        let chargingPlan = WallpaperPolicy.makePlan(
            settings: settings, conditions: conditions,
            chargingMediaID: charging, batteryMediaID: battery,
            manualMediaID: nil, fallbackRole: nil
        )
        XCTAssertEqual(chargingPlan.role, .charging)
        XCTAssertEqual(chargingPlan.mediaID, charging)

        conditions.powerState = .onBattery
        let batteryPlan = WallpaperPolicy.makePlan(
            settings: settings, conditions: conditions,
            chargingMediaID: charging, batteryMediaID: battery,
            manualMediaID: nil, fallbackRole: .charging
        )
        XCTAssertEqual(batteryPlan.role, .battery)
        XCTAssertEqual(batteryPlan.mediaID, battery)
    }

    func testUnknownPowerPreservesFallbackRole() {
        XCTAssertEqual(WallpaperPolicy.role(for: .unknown, fallback: .battery), .battery)
    }

    func testManualPauseBlocksPlayback() {
        var conditions = SystemConditions()
        conditions.powerState = .externalPowerCharging
        conditions.userPaused = true
        let id = UUID()
        let plan = WallpaperPolicy.makePlan(
            settings: AppSettings(), conditions: conditions,
            chargingMediaID: id, batteryMediaID: nil,
            manualMediaID: nil, fallbackRole: nil
        )
        XCTAssertFalse(plan.shouldPlay)
        XCTAssertTrue(plan.pauseReasons.contains(.userPaused))
    }
}
