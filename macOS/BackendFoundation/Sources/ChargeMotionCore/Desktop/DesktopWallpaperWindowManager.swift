import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

/// Maintains one click-through wallpaper window for each connected display.
@MainActor
public final class DesktopWallpaperWindowManager: ObservableObject {
    @Published public private(set) var activeDisplayIDs: [UInt32] = []

    private var windows: [UInt32: DesktopWallpaperWindow] = [:]
    private var playersByDisplayID: [UInt32: AVPlayer] = [:]
    private var screenChangeObserver: NSObjectProtocol?

    public init() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileDisplays()
            }
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    /// Assigns the player used by each display.
    public func setPlayers(_ players: [UInt32: AVPlayer]) {
        playersByDisplayID = players
        reconcileDisplays()
    }

    /// Hides and releases every wallpaper window and player reference.
    public func hideAll() {
        for window in windows.values {
            window.detachPlayer()
            window.orderOut(nil)
        }

        windows.removeAll()
        playersByDisplayID.removeAll()
        activeDisplayIDs = []
    }

    /// Reconciles wallpaper windows with the currently connected displays.
    public func reconcileDisplays() {
        let screensByID: [UInt32: NSScreen] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber else {
                    return nil
                }

                return (number.uint32Value, screen)
            }
        )

        // Remove disconnected displays without mutating during iteration.
        let removedIDs = windows.keys.filter {
            screensByID[$0] == nil
        }

        for displayID in removedIDs {
            guard let window = windows.removeValue(forKey: displayID) else {
                continue
            }

            window.detachPlayer()
            window.orderOut(nil)
            playersByDisplayID.removeValue(forKey: displayID)
        }

        // Update or create windows for connected displays.
        for (displayID, screen) in screensByID {
            // Reuse the shared wallpaper player for displays connected after startup.
            guard let player = playersByDisplayID[displayID] ?? playersByDisplayID.values.first else {
                if let oldWindow = windows.removeValue(forKey: displayID) {
                    oldWindow.detachPlayer()
                    oldWindow.orderOut(nil)
                }
                continue
            }

            let window: DesktopWallpaperWindow

            if let existing = windows[displayID] {
                window = existing
                window.setFrame(screen.frame, display: true)
            } else {
                window = DesktopWallpaperWindow(screen: screen)
                windows[displayID] = window
            }

            window.attach(player: player)
            window.orderFrontRegardless()
        }

        activeDisplayIDs = windows.keys.sorted()
    }

    /// Shows or hides existing wallpaper windows without destroying them.
    public func setVisible(_ visible: Bool) {
        if visible {
            reconcileDisplays()
        } else {
            for window in windows.values {
                window.orderOut(nil)
            }
        }
    }
}