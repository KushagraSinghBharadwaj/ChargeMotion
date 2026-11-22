import AppKit
import AVFoundation

/// A borderless, click-through window intended to sit immediately below desktop icons.
@MainActor
final class DesktopWallpaperWindow: NSWindow {
    private var playerLayer: AVPlayerLayer?

    init(screen: NSScreen) {
        let desktopIconLevel = CGWindowLevelForKey(.desktopIconWindow)
        let wallpaperLevel = NSWindow.Level(rawValue: Int(desktopIconLevel) - 1)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        level = wallpaperLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        acceptsMouseMovedEvents = false

        let hostView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        hostView.wantsLayer = true
        hostView.layer = CALayer()
        hostView.layer?.backgroundColor = NSColor.black.cgColor
        contentView = hostView
    }

    func attach(player: AVPlayer, gravity: AVLayerVideoGravity = .resizeAspectFill) {
        guard let hostLayer = contentView?.layer else { return }

        playerLayer?.removeFromSuperlayer()

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = gravity
        layer.frame = hostLayer.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        hostLayer.addSublayer(layer)
        playerLayer = layer
    }

    func detachPlayer() {
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}
