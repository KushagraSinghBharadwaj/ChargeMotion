import Foundation
import XCTest
@testable import ChargeMotionCore

final class MediaLibraryStoreTests: XCTestCase {
    func testNewLibraryStartsEmpty() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MediaLibraryStore(applicationSupportDirectory: directory)
        let assets = await store.listAssets()
        XCTAssertTrue(assets.isEmpty)
    }

    func testUnsupportedFormatIsRejected() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MediaLibraryStore(applicationSupportDirectory: directory)
        let source = directory.appendingPathComponent("notes.txt")
        try Data("not a video".utf8).write(to: source)

        do {
            _ = try await store.importFile(from: source)
            XCTFail("Expected unsupported format error")
        } catch let error as MediaLibraryError {
            guard case .unsupportedFormat = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testImportCopiesVideoAndPersistsCatalog() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MediaLibraryStore(applicationSupportDirectory: directory)
        let source = directory.appendingPathComponent("demo.mp4")
        try Data([0, 1, 2, 3, 4]).write(to: source)

        let imported = try await store.importFile(from: source)
        let managedURL = try await store.fileURL(for: imported.id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertEqual(imported.fileSize, 5)
        let storedAssets = await store.listAssets()
        XCTAssertEqual(storedAssets.count, 1)

        let reopenedStore = try MediaLibraryStore(applicationSupportDirectory: directory)
        let reopenedAssets = await reopenedStore.listAssets()
        XCTAssertEqual(reopenedAssets.count, 1)
    }

    func testRenameAndRemoveAsset() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MediaLibraryStore(applicationSupportDirectory: directory)
        let source = directory.appendingPathComponent("demo.mov")
        try Data([1, 2, 3]).write(to: source)

        let imported = try await store.importFile(from: source)
        try await store.renameAsset(imported.id, to: "My Wallpaper")
        let renamedAssets = await store.listAssets()
        XCTAssertEqual(renamedAssets.first?.displayName, "My Wallpaper")

        try await store.removeAsset(imported.id)
        let remainingAssets = await store.listAssets()
        XCTAssertTrue(remainingAssets.isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ChargeMotionTests-\(UUID().uuidString)", isDirectory: true)
    }
}
