import XCTest
@testable import ChargeMotionCore

final class PowerStateTests: XCTestCase {
    func testBatteryPowerWinsEvenWhenBatteryIsFull() {
        let snapshot = PowerSnapshot(
            hasInternalBattery: true,
            isOnExternalPower: false,
            isCharging: false,
            isCharged: true,
            batteryPercent: 100
        )
        XCTAssertEqual(PowerStateInterpreter.interpret(snapshot), .onBattery)
    }

    func testConnectedAndCharging() {
        let snapshot = PowerSnapshot(
            hasInternalBattery: true,
            isOnExternalPower: true,
            isCharging: true,
            batteryPercent: 73
        )
        XCTAssertEqual(PowerStateInterpreter.interpret(snapshot), .externalPowerCharging)
    }

    func testConnectedAndFull() {
        let snapshot = PowerSnapshot(
            hasInternalBattery: true,
            isOnExternalPower: true,
            isCharging: false,
            isCharged: true,
            batteryPercent: 100
        )
        XCTAssertEqual(PowerStateInterpreter.interpret(snapshot), .externalPowerFullyCharged)
    }

    func testDesktopMacUsesExternalPowerRole() {
        XCTAssertEqual(
            PowerStateInterpreter.interpret(PowerSnapshot(hasInternalBattery: false)),
            .noBatteryDesktop
        )
    }

    func testUnreadableStateDoesNotGuess() {
        XCTAssertEqual(PowerStateInterpreter.interpret(.unreadable), .unknown)
    }
}
