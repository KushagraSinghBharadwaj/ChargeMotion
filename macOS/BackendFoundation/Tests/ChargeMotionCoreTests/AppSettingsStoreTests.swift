import XCTest
@testable import ChargeMotionCore

final class AppSettingsStoreTests: XCTestCase {
    func testMissingFileReturnsDefaultSettings() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let fileURL = directory.appendingPathComponent("settings.json")
        let store = AppSettingsStore(fileURL: fileURL)

        let settings = try await store.load()

        XCTAssertEqual(settings, AppSettings())
    }

    func testSettingsCanBeSavedAndLoaded() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let fileURL = directory.appendingPathComponent("settings.json")
        let store = AppSettingsStore(fileURL: fileURL)

        var settings = AppSettings()
        settings.pauseOnLowPowerMode = true
        settings.pauseOnBattery = true
        settings.allowAudio = true
        settings.audioMuted = false

        try await store.save(settings)

        let loadedSettings = try await store.load()
        XCTAssertEqual(loadedSettings, settings)

        try await store.deleteStoredSettings()
        try? FileManager.default.removeItem(at: directory)
    }

    func testSettingsFileIsCreated() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let fileURL = directory.appendingPathComponent("settings.json")
        let store = AppSettingsStore(fileURL: fileURL)

        try await store.save(AppSettings())

        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        XCTAssertTrue(exists)

        try? FileManager.default.removeItem(at: directory)
    }
}
