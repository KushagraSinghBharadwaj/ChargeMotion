import AppKit
import SceneKit

/// Base SCNView for both 3D components. Owns everything about *lifecycle*:
///  - renders only while the window is visible, not miniaturised, the view is on screen
///    (also when scrolled out of an enclosing NSScrollView) and `isActive` is true;
///  - drops to a lower frame rate while the app is in the background;
///  - follows Reduce Motion and light/dark appearance;
///  - reports size changes so scenes can refit the camera;
///  - releases scene resources in `tearDown()`.
open class SceneKitHostView: SCNView {
    var onLayoutSize: ((CGSize) -> Void)?
    var onResume: (() -> Void)?
    var onAppearance: ((Bool) -> Void)?
    var onReduceMotion: ((Bool) -> Void)?

    private var activeFlag = true
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var quality: KoiRenderQuality = .balanced
    private var tornDown = false

    public override init(frame frameRect: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frameRect, options: options)
        commonInit()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        backgroundColor = .clear
        layer?.isOpaque = false
        allowsCameraControl = false
        isPlaying = false                   // starts paused; refreshPlayback() enables it once on screen
        rendersContinuously = false
        setAccessibilityElement(true)
    }

    func configure(quality: KoiRenderQuality) {
        self.quality = quality
        antialiasingMode = quality.antialiasing
        preferredFramesPerSecond = quality.framesPerSecond
    }

    /// Host app (SwiftUI) toggles this, e.g. when its tab/screen is not showing.
    func setActive(_ active: Bool) {
        activeFlag = active
        refreshPlayback()
    }

    // MARK: Lifecycle

    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()
        guard let win = window, !tornDown else { refreshPlayback(); return }
        let nc = NotificationCenter.default
        let refresh: (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPlayback() }
        }
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification, NSWindow.didChangeScreenNotification] {
            observe(nc, name, win, refresh)
        }
        observe(nc, NSApplication.didBecomeActiveNotification, nil, refresh)
        observe(nc, NSApplication.didResignActiveNotification, nil, refresh)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.onReduceMotion?(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) }
        }
        // Scrolled off-screen inside a ScrollView? Watch the clip view.
        if let clip = enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            observe(nc, NSView.boundsDidChangeNotification, clip, refresh)
        }
        onReduceMotion?(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        viewDidChangeEffectiveAppearance()
        refreshPlayback()
    }

    open override func layout() {
        super.layout()
        onLayoutSize?(bounds.size)
        refreshPlayback()
    }

    open override func viewDidHide() { super.viewDidHide(); refreshPlayback() }
    open override func viewDidUnhide() { super.viewDidUnhide(); refreshPlayback() }

    open override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearance?(effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }

    func refreshPlayback() {
        guard !tornDown else { return }
        var visible = activeFlag && window != nil && !isHiddenOrHasHiddenAncestor && !visibleRect.isEmpty
        if let w = window { visible = visible && w.occlusionState.contains(.visible) && !w.isMiniaturized }
        preferredFramesPerSecond = NSApp.isActive ? quality.framesPerSecond : min(quality.framesPerSecond, 24)
        if visible != isPlaying {
            if visible { onResume?() }
            isPlaying = visible
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ object: AnyObject?,
                         _ block: @escaping (Notification) -> Void) {
        let token = center.addObserver(forName: name, object: object, queue: .main, using: block)
        observers.append((center, token))
    }

    private func removeObservers() {
        observers.forEach { $0.center.removeObserver($0.token) }
        observers.removeAll()
    }

    /// Stops rendering and releases scene resources. Called from `dismantleNSView`.
    func tearDown() {
        guard !tornDown else { return }
        tornDown = true
        isPlaying = false
        removeObservers()
        delegate = nil
        onLayoutSize = nil; onResume = nil; onAppearance = nil; onReduceMotion = nil
        pointOfView = nil
        scene = nil
    }
}
