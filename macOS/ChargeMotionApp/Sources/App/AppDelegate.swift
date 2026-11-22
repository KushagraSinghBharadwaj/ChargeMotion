import AppKit

/// Connects the application lifecycle to `AppEnvironment`.
///
/// The delegate owns the environment so it exists before any window and is available
/// to both the lifecycle callbacks and the SwiftUI scene.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        environment.start()
    }

    /// The wallpaper keeps playing after the window closes; quit from the menu or Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Delays termination until monitoring has stopped and queued settings are saved.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { [environment] in
            await environment.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
