import AVFoundation
import AVKit
import Combine
import SwiftUI
import ChargeMotionCore

/// Preview model with its OWN `VideoPlaybackController`, never the wallpaper one.
@MainActor
final class VideoPreviewModel: ObservableObject {
    let controller = VideoPlaybackController()
    @Published var currentTime: Double = 0
    @Published var isMuted = true
    @Published var volume: Double = 0.7
    @Published var loadError: String?

    private var timeObserver: Any?
    private weak var observedPlayer: AVPlayer?
    private var forward: AnyCancellable?

    init() {
        forward = controller.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func start(url: URL) {
        do {
            try controller.load(url: url, muted: true)
            controller.play()
            observeTime()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func togglePlay() { controller.isPlaying ? controller.pause() : controller.play() }

    func seek(to seconds: Double) {
        currentTime = seconds
        controller.player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        controller.setMuted(muted)
    }

    func setVolume(_ value: Double) {
        volume = value
        controller.player?.volume = Float(value)
    }

    private func observeTime() {
        guard let player = controller.player else { return }
        observedPlayer = player
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in
                if seconds.isFinite { self?.currentTime = seconds }
            }
        }
    }

    /// Stops playback and releases the player. Called when the sheet closes or disappears.
    func teardown() {
        if let timeObserver, let observedPlayer { observedPlayer.removeTimeObserver(timeObserver) }
        timeObserver = nil
        observedPlayer = nil
        controller.stop()
    }
}

private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}

struct VideoPreviewSheet: View {
    let asset: MediaAsset
    let ctx: ShellContext
    @StateObject private var model = VideoPreviewModel()
    @ObservedObject private var info: MediaInfoStore
    @Environment(\.dismiss) private var dismiss

    init(asset: MediaAsset, ctx: ShellContext) {
        self.asset = asset
        self.ctx = ctx
        _info = ObservedObject(wrappedValue: ctx.info)
    }

    private var metadata: VideoMetadata? { info.metadata(for: asset.id) }
    private var duration: Double { max(metadata?.durationSeconds ?? 0, 0.1) }

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.md) {
            HStack {
                Text(asset.displayName).cmText(.title).foregroundStyle(CMColor.textPrimary).lineLimit(1)
                Spacer()
                Button("Close") { close() }.buttonStyle(.cmSecondary).keyboardShortcut(.cancelAction)
            }

            ZStack {
                Rectangle().fill(Color.black)
                if let error = model.loadError ?? model.controller.lastError.map({ "\($0)" }) {
                    CMEmptyState(systemImage: "exclamationmark.triangle", title: "Can't play this video",
                                 message: error, tone: .danger)
                } else {
                    PlayerSurface(player: model.controller.player)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: CMRadius.tile, style: .continuous))

            controls

            HStack(alignment: .top, spacing: CMSpacing.xl) {
                VStack(alignment: .leading, spacing: CMSpacing.xs) {
                    CMInfoRow(label: "Format", value: asset.fileExtension.uppercased())
                    CMInfoRow(label: "File size", value: VideoFormatting.fileSize(asset.fileSize))
                    CMInfoRow(label: "Imported", value: VideoFormatting.date(asset.importedAt))
                }
                VStack(alignment: .leading, spacing: CMSpacing.xs) {
                    CMInfoRow(label: "Duration", value: VideoFormatting.duration(metadata?.durationSeconds))
                    CMInfoRow(label: "Resolution", value: metadata?.resolutionText ?? "Unavailable")
                    CMInfoRow(label: "Aspect ratio", value: metadata?.aspectRatioText ?? "Unavailable")
                    CMInfoRow(label: "Audio", value: metadata.map { $0.hasAudio ? "Has audio track" : "No audio track" } ?? "Unavailable")
                }
            }
        }
        .padding(CMSpacing.lg)
        .frame(minWidth: 680, idealWidth: 760, minHeight: 560)
        .background(CMBackground())
        .task {
            info.load(asset)
            do {
                let url = try await ctx.services.mediaLibrary.fileURL(for: asset.id)
                model.start(url: url)
            } catch {
                model.loadError = error.localizedDescription
            }
        }
        .onDisappear { model.teardown() }
    }

    private var controls: some View {
        HStack(spacing: CMSpacing.sm) {
            Button { model.togglePlay() } label: {
                Image(systemName: model.controller.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.cmIcon)
            .accessibilityLabel(model.controller.isPlaying ? "Pause" : "Play")
            .help(model.controller.isPlaying ? "Pause" : "Play")

            Text(VideoFormatting.duration(model.currentTime)).cmText(.mono).foregroundStyle(CMColor.textSecondary)
            Slider(value: Binding(get: { min(model.currentTime, duration) }, set: { model.seek(to: $0) }), in: 0...duration)
                .tint(CMColor.accent)
                .accessibilityLabel("Playback position")
            Text(VideoFormatting.duration(metadata?.durationSeconds)).cmText(.mono).foregroundStyle(CMColor.textSecondary)

            Button { model.setMuted(!model.isMuted) } label: {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.cmIcon)
            .accessibilityLabel(model.isMuted ? "Unmute" : "Mute")
            .help(model.isMuted ? "Unmute preview" : "Mute preview")
            .disabled(metadata?.hasAudio == false)

            Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...1)
                .frame(width: 90).tint(CMColor.accent)
                .accessibilityLabel("Volume")
                .disabled(metadata?.hasAudio == false)
        }
    }

    private func close() {
        model.teardown()
        dismiss()
    }
}
