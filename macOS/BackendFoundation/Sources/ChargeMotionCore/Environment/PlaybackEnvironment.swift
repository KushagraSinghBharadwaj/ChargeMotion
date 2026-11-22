import AppKit
import Combine
import CoreGraphics
import Foundation

public struct PlaybackEnvironmentSnapshot: Equatable, Sendable {
    public var isLowPowerModeEnabled: Bool
    public var isScreenLocked: Bool
    public var isSystemSleeping: Bool
    public var isApplicationActive: Bool
    public var hasFullScreenApplication: Bool

    public init(
        isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        isScreenLocked: Bool = false,
        isSystemSleeping: Bool = false,
        isApplicationActive: Bool = true,
        hasFullScreenApplication: Bool = false
    ) {
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.isScreenLocked = isScreenLocked
        self.isSystemSleeping = isSystemSleeping
        self.isApplicationActive = isApplicationActive
        self.hasFullScreenApplication = hasFullScreenApplication
    }
}

@MainActor
public final class PlaybackEnvironment: ObservableObject {
    @Published public private(set) var snapshot = PlaybackEnvironmentSnapshot()

    private var notificationObservers: [NSObjectProtocol] = []
    private var standardNotificationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var fullscreenTimer: Timer?

    public init() {
        startMonitoring()
    }

    /// Starts environment observers and full-screen polling exactly once.
    public func startMonitoring() {
        guard fullscreenTimer == nil else {
            refresh()
            return
        }

        observePowerMode()
        observeApplicationActivity()
        observeSleepWake()
        observeScreenLock()
        refreshFullScreenState()
        startFullScreenPolling()
    }

    deinit {
        fullscreenTimer?.invalidate()
        notificationObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        standardNotificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    public var shouldPausePlayback: Bool {
        snapshot.isLowPowerModeEnabled
            || snapshot.isScreenLocked
            || snapshot.isSystemSleeping
            || snapshot.hasFullScreenApplication
    }

    public func refresh() {
        snapshot.isLowPowerModeEnabled =
            ProcessInfo.processInfo.isLowPowerModeEnabled
        refreshFullScreenState()
    }

    public func stopMonitoring() {
        fullscreenTimer?.invalidate()
        fullscreenTimer = nil

        notificationObservers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
        }

        standardNotificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }

        workspaceObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }

        notificationObservers.removeAll()
        standardNotificationObservers.removeAll()
        workspaceObservers.removeAll()
    }

    private func observePowerMode() {
        let token = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isLowPowerModeEnabled =
                    ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        standardNotificationObservers.append(token)
    }

    private func observeApplicationActivity() {
        let center = NSWorkspace.shared.notificationCenter

        let active = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isApplicationActive = true
            }
        }

        let inactive = center.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isApplicationActive = false
            }
        }

        workspaceObservers.append(contentsOf: [active, inactive])
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        let sleeping = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isSystemSleeping = true
            }
        }

        let awake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isSystemSleeping = false
                self?.refresh()
            }
        }

        workspaceObservers.append(contentsOf: [sleeping, awake])
    }

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()

        let locked = center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isScreenLocked = true
            }
        }

        let unlocked = center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.snapshot.isScreenLocked = false
            }
        }

        notificationObservers.append(contentsOf: [locked, unlocked])
    }

    private func startFullScreenPolling() {
        fullscreenTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFullScreenState()
            }
        }
    }

    // Heuristic detection based on visible windows covering a display.
    // This is not an authoritative macOS fullscreen-state API.
    private func refreshFullScreenState() {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            snapshot.hasFullScreenApplication = false
            return
        }

        let displayFrames = NSScreen.screens.map(\.frame)

        let found = windows.contains { info in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
                ownerPID != ProcessInfo.processInfo.processIdentifier,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                let alpha = info[kCGWindowAlpha as String] as? Double,
                alpha > 0.95,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0
            else {
                return false
            }

            return displayFrames.contains { display in
                let intersection = display.intersection(bounds)

                guard !intersection.isNull,
                      display.width > 0,
                      display.height > 0 else {
                    return false
                }

                let coverage =
                    (intersection.width * intersection.height)
                    / (display.width * display.height)

                return coverage > 0.96
            }
        }

        snapshot.hasFullScreenApplication = found
    }
}
