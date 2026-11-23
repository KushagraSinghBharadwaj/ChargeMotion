import AppKit
import SceneKit
import SwiftUI

/// SceneKit view for the medallion. Input: hover = lean toward cursor, drag = spin/tilt (springs back
/// to face front), click = swing, double-click = flip to show the back.
public final class CreatorMedallionSCNView: SceneKitHostView {
    private var medallion: CreatorMedallionScene?
    private var dragMoved = false
    private var tracking: NSTrackingArea?

    public func attach(_ m: CreatorMedallionScene, quality: KoiRenderQuality) {
        medallion = m
        configure(quality: quality)
        scene = m.scene
        pointOfView = m.cameraNode
        delegate = m
        onLayoutSize = { [weak m] size in m?.updateViewport(size: size) }
        onResume = { [weak m] in m?.resetClock() }
        onAppearance = { [weak m] dark in m?.applyAppearance(isDark: dark) }
        onReduceMotion = { [weak m] on in m?.setReducedMotion(on) }
        setAccessibilityLabel("Creator medallion: Made by Kushagra Singh Bharadwaj")
        m.updateViewport(size: bounds.size)
    }

    public override func tearDown() {
        super.tearDown()
        medallion?.tearDown()
        medallion = nil
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    private func normalised(_ e: NSEvent) -> (Double, Double) {
        let p = convert(e.locationInWindow, from: nil)
        return (Double(p.x / max(1, bounds.width)) * 2 - 1, Double(p.y / max(1, bounds.height)) * 2 - 1)
    }

    public override func mouseEntered(with event: NSEvent) { let n = normalised(event); medallion?.hover(nx: n.0, ny: n.1) }
    public override func mouseMoved(with event: NSEvent) { let n = normalised(event); medallion?.hover(nx: n.0, ny: n.1) }
    public override func mouseExited(with event: NSEvent) { medallion?.endHover() }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { medallion?.flip(); return }
        dragMoved = false
        medallion?.beginDrag()
    }
    public override func mouseDragged(with event: NSEvent) {
        dragMoved = true
        medallion?.drag(dx: Double(event.deltaX), dy: Double(event.deltaY))
    }
    public override func mouseUp(with event: NSEvent) {
        medallion?.endDrag()
        if !dragMoved && event.clickCount == 1 { medallion?.tap(nx: normalised(event).0) }
    }
    public override func scrollWheel(with event: NSEvent) { nextResponder?.scrollWheel(with: event) }
}

/// SwiftUI entry point. Give it a portrait-ish frame (about 2:3.4); the camera refits for any size.
public struct CreatorMedallionView: NSViewRepresentable {
    public var isActive: Bool
    public var quality: KoiRenderQuality
    public var palette: KoiPalette

    public init(isActive: Bool = true, quality: KoiRenderQuality = .balanced, palette: KoiPalette = KoiPalette()) {
        self.isActive = isActive; self.quality = quality; self.palette = palette
    }

    public func makeNSView(context: Context) -> CreatorMedallionSCNView {
        let view = CreatorMedallionSCNView(frame: .zero)
        view.attach(CreatorMedallionScene(palette: palette, quality: quality), quality: quality)
        return view
    }

    public func updateNSView(_ view: CreatorMedallionSCNView, context: Context) { view.setActive(isActive) }

    public static func dismantleNSView(_ view: CreatorMedallionSCNView, coordinator: ()) { view.tearDown() }
}
