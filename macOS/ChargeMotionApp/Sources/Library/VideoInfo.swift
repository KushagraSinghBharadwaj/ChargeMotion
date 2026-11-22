import AppKit
import AVFoundation
import ChargeMotionCore
import Combine
import ImageIO
import UniformTypeIdentifiers

/// Read-only facts derived from a managed video with AVFoundation. Cached outside the media library.
struct VideoMetadata: Codable, Equatable, Sendable {
    var durationSeconds: Double?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var frameRate: Double?
    var hasAudio: Bool
    var isPlayable: Bool
    /// Catalog file size when derived; a mismatch invalidates the cache entry.
    var sourceFileSize: Int64

    var resolutionText: String? {
        guard let w = pixelWidth, let h = pixelHeight, w > 0, h > 0 else { return nil }
        return "\(w) × \(h)"
    }

    var aspectRatioText: String? {
        guard let w = pixelWidth, let h = pixelHeight, w > 0, h > 0 else { return nil }
        let ratio = Double(w) / Double(h)
        for (a, b) in [(16, 9), (16, 10), (4, 3), (3, 2), (21, 9), (1, 1), (9, 16), (3, 4)] {
            let t = Double(a) / Double(b)
            if abs(ratio - t) / t < 0.012 { return "\(a):\(b)" }
        }
        return String(format: "%.2f:1", ratio)
    }

    var frameRateText: String? {
        guard let f = frameRate else { return nil }
        return abs(f - f.rounded()) < 0.01 ? "\(Int(f.rounded())) fps" : String(format: "%.2f fps", f)
    }
}

struct VideoInfoResult: Sendable {
    let metadata: VideoMetadata
    let thumbnailJPEG: Data?
}

enum VideoInfoError: LocalizedError {
    case unreadable(String)
    var errorDescription: String? {
        if case .unreadable(let reason) = self { return "The video file couldn't be read. \(reason)" }
        return nil
    }
}

/// Derives metadata and a thumbnail and caches both in `~/Library/Caches/ChargeMotion/VideoInfo/`.
/// The cache is disposable; the videos and the media catalog are never touched.
actor VideoInfoService {
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("ChargeMotion/VideoInfo", isDirectory: true)
    }

    func info(for id: UUID, fileURL: URL, expectedFileSize: Int64) async throws -> VideoInfoResult {
        if let cached = loadCached(id, size: expectedFileSize),
           cached.thumbnailJPEG != nil || !cached.metadata.isPlayable { return cached }
        let derived = try await derive(fileURL, size: expectedFileSize)
        store(derived, id: id)
        return derived
    }

    func removeCache(for id: UUID) {
        try? FileManager.default.removeItem(at: metaURL(id))
        try? FileManager.default.removeItem(at: thumbURL(id))
    }

    func prune(keeping ids: Set<UUID>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            if let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !ids.contains(id) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func derive(_ url: URL, size: Int64) async throws -> VideoInfoResult {
        let asset = AVURLAsset(url: url)
        var meta = VideoMetadata(durationSeconds: nil, pixelWidth: nil, pixelHeight: nil, frameRate: nil,
                                 hasAudio: false, isPlayable: false, sourceFileSize: size)
        do {
            let duration = try await asset.load(.duration)
            meta.isPlayable = try await asset.load(.isPlayable)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 { meta.durationSeconds = seconds }
        } catch {
            throw VideoInfoError.unreadable(error.localizedDescription)
        }
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            if let natural = try? await track.load(.naturalSize),
               let transform = try? await track.load(.preferredTransform) {
                let shown = natural.applying(transform)   // apply rotation: portrait clips stay portrait
                meta.pixelWidth = Int(abs(shown.width).rounded())
                meta.pixelHeight = Int(abs(shown.height).rounded())
            }
            if let rate = try? await track.load(.nominalFrameRate), rate > 0 { meta.frameRate = Double(rate) }
        }
        meta.hasAudio = !((try? await asset.loadTracks(withMediaType: .audio)) ?? []).isEmpty

        var thumb: Data?
        if meta.isPlayable, meta.resolutionText != nil {
            thumb = await makeThumbnail(asset, duration: meta.durationSeconds)
        }
        return VideoInfoResult(metadata: meta, thumbnailJPEG: thumb)
    }

    private func makeThumbnail(_ asset: AVURLAsset, duration: Double?) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        var times: [CMTime] = []
        if let duration, duration > 0 {
            times.append(CMTime(seconds: min(max(duration * 0.1, 0.5), duration / 2), preferredTimescale: 600))
        }
        times.append(.zero)
        for time in times {
            if let result = try? await generator.image(at: time), let data = Self.jpeg(result.image) { return data }
        }
        return nil
    }

    private static func jpeg(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    private func metaURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }
    private func thumbURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).jpg") }

    private func loadCached(_ id: UUID, size: Int64) -> VideoInfoResult? {
        guard let data = try? Data(contentsOf: metaURL(id)),
              let meta = try? JSONDecoder().decode(VideoMetadata.self, from: data),
              meta.sourceFileSize == size else { return nil }
        return VideoInfoResult(metadata: meta, thumbnailJPEG: try? Data(contentsOf: thumbURL(id)))
    }

    private func store(_ result: VideoInfoResult, id: UUID) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(result.metadata).write(to: metaURL(id), options: .atomic)
            if let jpeg = result.thumbnailJPEG { try jpeg.write(to: thumbURL(id), options: .atomic) }
            else { try? FileManager.default.removeItem(at: thumbURL(id)) }
        } catch { /* The cache is disposable; the next launch regenerates it. */ }
    }
}

/// Observable per-video metadata and thumbnails. File locations always come from
/// `MediaLibraryStore.fileURL(for:)`.
@MainActor
final class MediaInfoStore: ObservableObject {
    struct Loaded { let metadata: VideoMetadata; let thumbnail: NSImage? }
    enum Entry { case loading, ready(Loaded), unavailable(String) }

    @Published private(set) var entries: [UUID: Entry] = [:]
    private let library: MediaLibraryStore
    private let service = VideoInfoService()
    private var inFlight: [UUID: Task<Void, Never>] = [:]

    init(library: MediaLibraryStore) { self.library = library }

    func metadata(for id: UUID) -> VideoMetadata? {
        if case .ready(let l) = entries[id] { return l.metadata }
        return nil
    }

    func load(_ asset: MediaAsset) {
        if case .ready = entries[asset.id] { return }
        guard inFlight[asset.id] == nil else { return }
        if entries[asset.id] == nil { entries[asset.id] = .loading }
        inFlight[asset.id] = Task { [self] in
            await perform(asset)
            inFlight[asset.id] = nil
        }
    }

    func retry(_ asset: MediaAsset) {
        guard inFlight[asset.id] == nil else { return }
        entries[asset.id] = nil
        load(asset)
    }

    private func perform(_ asset: MediaAsset) async {
        do {
            let url = try await library.fileURL(for: asset.id)
            let result = try await service.info(for: asset.id, fileURL: url, expectedFileSize: asset.fileSize)
            guard !Task.isCancelled else { return }
            entries[asset.id] = .ready(Loaded(metadata: result.metadata,
                                              thumbnail: result.thumbnailJPEG.flatMap { NSImage(data: $0) }))
        } catch {
            guard !Task.isCancelled else { return }
            entries[asset.id] = .unavailable(error.localizedDescription)
        }
    }

    func discard(_ id: UUID) async {
        let pending = inFlight[id]
        pending?.cancel()
        await pending?.value
        inFlight[id] = nil
        entries[id] = nil
        await service.removeCache(for: id)
    }

    func prune(keeping ids: Set<UUID>) {
        for id in Array(entries.keys) where !ids.contains(id) { entries[id] = nil }
        Task { [service] in await service.prune(keeping: ids) }
    }
}
