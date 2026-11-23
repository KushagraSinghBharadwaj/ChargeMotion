import AppKit
import SceneKit
import SwiftUI

/// SceneKit view for the koi. Input:
///  - drag: orbit (inertia), pinch: zoom, ⌥/⌘ + scroll: zoom (plain scroll still scrolls the page)
///  - double-click or two-finger double-tap (smart magnify): reset camera, single click: tail-beat burst
///  - keyboard (when focused): arrows orbit, + / − zoom, 0 reset
public final class MechanicalKoiSCNView: SceneKitHostView {
    private var koiScene: MechanicalKoiScene?
    private var dragMoved = false

    public override var acceptsFirstResponder: Bool { true }

    public func attach(_ koi: MechanicalKoiScene, quality: KoiRenderQuality) {
        koiScene = koi
        configure(quality: quality)
        scene = koi.scene
        pointOfView = koi.cameraNode
        delegate = koi
        onLayoutSize = { [weak koi] size in koi?.updateViewport(size: size) }
        onResume = { [weak koi] in koi?.resetClock() }
        onAppearance = { [weak koi] dark in koi?.applyAppearance(isDark: dark) }
        onReduceMotion = { [weak koi] on in koi?.setReducedMotion(on) }
        setAccessibilityLabel("Interactive 3D mechanical koi. Drag to orbit, pinch to zoom.")
        koi.updateViewport(size: bounds.size)
    }

    public func resetCamera() { koiScene?.interaction.resetView() }

    public override func tearDown() {
        super.tearDown()
        koiScene?.tearDown()
        koiScene = nil
    }

    // MARK: Mouse / trackpad

    public override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { koiScene?.interaction.resetView(); return }
        dragMoved = false
        koiScene?.interaction.beginDrag()
        NSCursor.closedHand.set()
    }
    public override func mouseDragged(with event: NSEvent) {
        dragMoved = true
        koiScene?.interaction.drag(dx: Double(event.deltaX), dy: Double(event.deltaY))
    }
    public override func mouseUp(with event: NSEvent) {
        koiScene?.interaction.endDrag()
        if !dragMoved && event.clickCount == 1 { koiScene?.interaction.pulse() }
        window?.invalidateCursorRects(for: self)
    }
    public override func magnify(with event: NSEvent) {
        koiScene?.interaction.zoom(multiplyBy: 1 + Double(event.magnification))
    }
    public override func smartMagnify(with event: NSEvent) { koiScene?.interaction.resetView() }
    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) {
            koiScene?.interaction.zoom(multiplyBy: exp(Double(event.scrollingDeltaY) * 0.01))
        } else {
            nextResponder?.scrollWheel(with: event)          // don't hijack page scrolling
        }
    }
    public override func keyDown(with event: NSEvent) {
        guard let i = koiScene?.interaction else { return super.keyDown(with: event) }
        switch event.charactersIgnoringModifiers {
        case .some(String(UnicodeScalar(NSLeftArrowFunctionKey)!)): i.nudge(yaw: 0.15, pitch: 0)
        case .some(String(UnicodeScalar(NSRightArrowFunctionKey)!)): i.nudge(yaw: -0.15, pitch: 0)
        case .some(String(UnicodeScalar(NSUpArrowFunctionKey)!)): i.nudge(yaw: 0, pitch: -0.1)
        case .some(String(UnicodeScalar(NSDownArrowFunctionKey)!)): i.nudge(yaw: 0, pitch: 0.1)
        case "+", "=": i.zoom(multiplyBy: 1.15)
        case "-": i.zoom(multiplyBy: 1 / 1.15)
        case "0": i.resetView()
        default: super.keyDown(with: event)
        }
    }
}

/// Lets SwiftUI buttons talk to the AppKit view (e.g. a "Reset view" button).
public final class MechanicalKoiHandle: ObservableObject {
    weak var view: MechanicalKoiSCNView?
    public init() {}
    public func resetView() { view?.resetCamera() }
}

/// SwiftUI entry point. Drop it anywhere and give it a frame.
public struct MechanicalKoiView: NSViewRepresentable {
    public var isActive: Bool
    public var quality: KoiRenderQuality
    public var palette: KoiPalette
    public var handle: MechanicalKoiHandle?

    public init(isActive: Bool = true, quality: KoiRenderQuality = .balanced,
                palette: KoiPalette = KoiPalette(), handle: MechanicalKoiHandle? = nil) {
        self.isActive = isActive; self.quality = quality; self.palette = palette; self.handle = handle
    }

    public func makeNSView(context: Context) -> MechanicalKoiSCNView {
        let view = MechanicalKoiSCNView(frame: .zero)
        view.attach(MechanicalKoiScene(palette: palette, quality: quality), quality: quality)   // built exactly once
        handle?.view = view
        return view
    }

    public func updateNSView(_ view: MechanicalKoiSCNView, context: Context) {
        view.setActive(isActive)
        handle?.view = view
    }

    public static func dismantleNSView(_ view: MechanicalKoiSCNView, coordinator: ()) {
        view.tearDown()
    }
}
