import AVFoundation
import Foundation
import XCTest
@testable import ChargeMotionCore

@MainActor
final class VideoPlaybackControllerTests: XCTestCase {
    func testUnsupportedExtensionIsRejected() throws {
        let controller = VideoPlaybackController()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample.avi")

        XCTAssertThrowsError(try controller.load(url: url))
    }

    func testMissingVideoIsRejected() throws {
        let controller = VideoPlaybackController()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).mp4")

        XCTAssertThrowsError(try controller.load(url: url)) { error in
            XCTAssertEqual(error as? PlaybackError, .fileDoesNotExist)
        }
    }

    func testStopClearsPlaybackState() {
        let controller = VideoPlaybackController()
        controller.stop()

        XCTAssertFalse(controller.isPlaying)
        XCTAssertNil(controller.currentURL)
        XCTAssertNil(controller.player)
    }
}
