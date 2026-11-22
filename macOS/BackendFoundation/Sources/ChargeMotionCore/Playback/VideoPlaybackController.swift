import AVFoundation
import Combine
import Foundation

/// Owns one looping AVFoundation playback pipeline.
///
/// Keep this controller alive for as long as the video should remain available.
/// A separate controller can be created for each display by the display manager.
@MainActor
public final class VideoPlaybackController: ObservableObject {
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentURL: URL?
    @Published public private(set) var lastError: String?

    /// Exposed read-only so a SwiftUI/AppKit frontend can attach an AVPlayerLayer.
    public private(set) var player: AVQueuePlayer?

    private var playerLooper: AVPlayerLooper?
    private let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public init() {}

    /// Loads a video and prepares gapless looping. Loading does not start playback.
    public func load(url: URL, muted: Bool = true) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw PlaybackError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlaybackError.fileDoesNotExist
        }

        stop()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = muted
        queuePlayer.actionAtItemEnd = .none

        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        self.player = queuePlayer
        self.playerLooper = looper
        self.currentURL = url
        self.lastError = nil
    }

    public func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func stop() {
        player?.pause()
        player?.removeAllItems()
        playerLooper = nil
        player = nil
        currentURL = nil
        isPlaying = false
    }

    public func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    public func setVolume(_ volume: Float) {
        player?.volume = min(1, max(0, volume))
    }

    /// Playback speed is clamped to a conservative range to avoid accidental extremes.
    public func setRate(_ rate: Float) {
        guard let player else { return }
        let safeRate = min(2.0, max(0.5, rate))
        if isPlaying {
            player.rate = safeRate
        } else {
            player.rate = safeRate
        }
    }
}
