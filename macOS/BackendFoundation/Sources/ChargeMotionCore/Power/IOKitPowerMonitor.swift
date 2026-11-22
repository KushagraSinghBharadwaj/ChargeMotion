import Foundation
import Combine
import IOKit
import IOKit.ps

/// Reads the current macOS power-source state using Apple's public IOKit Power Sources API.
///
/// The monitor polls every five seconds as a reliable fallback. Call `start()` once during
/// application startup and retain the monitor for the lifetime of the app.
@MainActor
public final class IOKitPowerMonitor: ObservableObject {
    @Published public private(set) var snapshot: PowerSnapshot = .unreadable
    @Published public private(set) var state: PowerState = .unknown

    private var timer: Timer?
    private let pollingInterval: TimeInterval
    private var lastPublishedState: PowerState = .unknown

    public init(pollingInterval: TimeInterval = 5.0) {
        self.pollingInterval = max(1.0, pollingInterval)
    }

    deinit {
        timer?.invalidate()
    }

    public func start() {
        guard timer == nil else {
            refresh()
            return
        }

        // Read immediately so the app chooses the correct wallpaper on launch.
        refresh()

        let newTimer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Forces a fresh read. The published state changes only when the interpreted state changes.
    public func refresh() {
        let newSnapshot = Self.readSnapshot()
        let newState = PowerStateInterpreter.interpret(newSnapshot)

        snapshot = newSnapshot
        if newState != lastPublishedState {
            lastPublishedState = newState
            state = newState
        }
    }

    private static func readSnapshot() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unreadable
        }

        guard let sourceList = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unreadable
        }

        var descriptions: [[String: Any]] = []
        descriptions.reserveCapacity(sourceList.count)

        for source in sourceList {
            guard let unmanagedDescription = IOPSGetPowerSourceDescription(info, source),
                  let description = unmanagedDescription.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            descriptions.append(description)
        }

        // A successful IOKit query with no internal battery is a desktop Mac.
        return PowerSnapshotParser.parse(
            descriptions: descriptions,
            providingSource: nil
        )
    }
}
