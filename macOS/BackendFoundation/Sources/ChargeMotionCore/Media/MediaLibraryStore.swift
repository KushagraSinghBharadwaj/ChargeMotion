import Foundation

/// Copies imported videos into app-managed storage so playback does not depend
/// on the original file remaining at its previous location.
///
/// The store is an actor because import, removal, and catalog writes must be serialized.
public actor MediaLibraryStore {
    private let fileManager: FileManager
    private let libraryDirectory: URL
    private let catalogURL: URL
    private var assets: [MediaAsset]
    private let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public init(
        applicationSupportDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        let supportDirectory: URL
        if let applicationSupportDirectory {
            supportDirectory = applicationSupportDirectory
        } else {
            guard let defaultDirectory = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            supportDirectory = defaultDirectory
        }

        let appDirectory = supportDirectory.appendingPathComponent(
            "ChargeMotion",
            isDirectory: true
        )
        let libraryDirectory = appDirectory.appendingPathComponent(
            "Media",
            isDirectory: true
        )

        self.libraryDirectory = libraryDirectory
        self.catalogURL = appDirectory.appendingPathComponent("media-library.json")
        self.assets = []

        try fileManager.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )
        self.assets = try Self.loadCatalog(at: catalogURL)
        self.assets = self.assets.filter { asset in
            fileManager.fileExists(
                atPath: libraryDirectory.appendingPathComponent(asset.filename).path
            )
        }
    }

    /// Returns the current catalog. Missing media files are omitted.
    public func listAssets() -> [MediaAsset] {
        assets.sorted { $0.importedAt > $1.importedAt }
    }

    /// Imports and copies one MP4, MOV, or M4V file into managed storage.
    /// The caller should pass a URL obtained from NSOpenPanel or another user selection.
    public func importFile(from sourceURL: URL, displayName: String? = nil) throws -> MediaAsset {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw MediaLibraryError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw MediaLibraryError.sourceIsNotAFile
        }

        let sourcePath = sourceURL.standardizedFileURL.path
        let libraryPath = libraryDirectory.standardizedFileURL.path
        guard !sourcePath.hasPrefix(libraryPath + "/") else {
            throw MediaLibraryError.fileAlreadyManaged
        }

        let id = UUID()
        let filename = "\(id.uuidString).\(fileExtension)"
        let destinationURL = libraryDirectory.appendingPathComponent(filename)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        do {
            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let asset = MediaAsset(
                id: id,
                filename: filename,
                displayName: (displayName?.isEmpty == false
                    ? displayName!
                    : sourceURL.deletingPathExtension().lastPathComponent),
                fileExtension: fileExtension,
                fileSize: fileSize
            )
            assets.append(asset)
            try saveCatalog()
            return asset
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    /// Resolves an asset ID to its local managed file URL.
    public func fileURL(for assetID: UUID) throws -> URL {
        guard let asset = assets.first(where: { $0.id == assetID }) else {
            throw MediaLibraryError.assetNotFound(assetID)
        }
        let url = libraryDirectory.appendingPathComponent(asset.filename).standardizedFileURL
        guard url.deletingLastPathComponent().path == libraryDirectory.standardizedFileURL.path else {
            throw MediaLibraryError.unsafeLibraryPath
        }
        guard fileManager.fileExists(atPath: url.path) else {
            throw MediaLibraryError.assetNotFound(assetID)
        }
        return url
    }

    /// Changes the user-facing name without changing the managed filename.
    public func renameAsset(_ assetID: UUID, to newDisplayName: String) throws {
        let trimmedName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = assets.firstIndex(where: { $0.id == assetID }) else {
            throw MediaLibraryError.assetNotFound(assetID)
        }

        let oldAsset = assets[index]
        assets[index].displayName = trimmedName
        do {
            try saveCatalog()
        } catch {
            assets[index] = oldAsset
            throw error
        }
    }

    /// Removes a managed video and its catalog entry.
    public func removeAsset(_ assetID: UUID) throws {
        guard let index = assets.firstIndex(where: { $0.id == assetID }) else {
            throw MediaLibraryError.assetNotFound(assetID)
        }

        let asset = assets[index]
        let url = libraryDirectory
            .appendingPathComponent(asset.filename)
            .standardizedFileURL

        guard url.deletingLastPathComponent().path == libraryDirectory.standardizedFileURL.path else {
            throw MediaLibraryError.unsafeLibraryPath
        }

        // Update the catalog first so a save failure never destroys the media file.
        assets.remove(at: index)

        do {
            try saveCatalog()
        } catch {
            assets.insert(asset, at: index)
            throw error
        }

        // A failed file deletion leaves an unreferenced file, not a broken catalog.
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
    private func saveCatalog() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assets)
        try data.write(to: catalogURL, options: .atomic)
    }

    private static func loadCatalog(at url: URL) throws -> [MediaAsset] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MediaAsset].self, from: data)
    }
}
