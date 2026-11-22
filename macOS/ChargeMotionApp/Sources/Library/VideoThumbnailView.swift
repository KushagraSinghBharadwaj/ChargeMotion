import SwiftUI
import ChargeMotionCore

/// A video thumbnail with loading, no-frame and unreadable states. Triggers its own load.
struct VideoThumbnailView: View {
    let asset: MediaAsset
    @ObservedObject var info: MediaInfoStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CMRadius.tile, style: .continuous)
        ZStack {
            Rectangle().fill(CMColor.graphite)
            content
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(shape)
        .overlay(shape.strokeBorder(CMColor.edgeHighlight.opacity(0.10), lineWidth: 1))
        .task(id: asset.id) { info.load(asset) }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch info.entries[asset.id] {
        case .ready(let loaded):
            if let image = loaded.thumbnail {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                placeholder(loaded.metadata.isPlayable ? "film" : "exclamationmark.triangle",
                            loaded.metadata.isPlayable ? "No preview frame" : "Can't be played")
            }
        case .unavailable:
            placeholder("exclamationmark.triangle", "Preview unavailable")
        case .loading, .none:
            ProgressView().controlSize(.small).tint(CMColor.accent)
        }
    }

    private func placeholder(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium))
            Text(text).cmText(.caption)
        }
        .foregroundStyle(CMColor.textTertiary)
    }
}
