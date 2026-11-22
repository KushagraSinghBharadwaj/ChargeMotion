import AppKit
import Combine
import CoreGraphics

/// A read-only snapshot of one connected display (AppKit and Core Graphics).
/// `id` is the Core Graphics display ID, the same key `DesktopWallpaperWindowManager.activeDisplayIDs` uses.
struct DisplayInfo: Identifiable, Equatable {
    let id: UInt32
    let name: String
    let frame: CGRect
    let pixelSize: CGSize?
    let scaleFactor: CGFloat
    let maxRefreshRate: Int?
    let isPrimary: Bool
    let isBuiltIn: Bool

    init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let displayID = number.uint32Value
        id = displayID
        name = screen.localizedName
        frame = screen.frame
        scaleFactor = screen.backingScaleFactor
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            pixelSize = CGSize(width: mode.pixelWidth, height: mode.pixelHeight)
        } else {
            pixelSize = nil
        }
        let fps = screen.maximumFramesPerSecond
        maxRefreshRate = fps > 0 ? fps : nil
        isPrimary = CGDisplayIsMain(displayID) != 0
        isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
    }

    var pointSizeText: String { "\(Int(frame.width.rounded())) × \(Int(frame.height.rounded())) points" }
    var pixelSizeText: String? { pixelSize.map { "\(Int($0.width)) × \(Int($0.height)) pixels at \(Int(scaleFactor))×" } }
    var refreshText: String? { maxRefreshRate.map { "\($0) Hz" } }
    var positionText: String { "\(Int(frame.origin.x.rounded())), \(Int(frame.origin.y.rounded()))" }
}

/// Publishes the connected displays and refreshes on screen-configuration changes.
/// It only reads facts; wallpaper windows remain the backend window manager's job.
@MainActor
final class DisplayMonitor: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    private var observer: ScreenChangeObserver?

    init() {
        displays = Self.read()
        observer = ScreenChangeObserver { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let latest = Self.read()
        if latest != displays { displays = latest }
    }

    private static func read() -> [DisplayInfo] {
        NSScreen.screens.compactMap { DisplayInfo(screen: $0) }.sorted {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.id < $1.id
        }
    }
}

/// Removes its observer when released, so the main-actor owner needs no isolated deinit.
private final class ScreenChangeObserver {
    private var token: NSObjectProtocol?

    init(onChange: @escaping @Sendable () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in onChange() }
    }

    deinit { if let token { NotificationCenter.default.removeObserver(token) } }
}
