import ChargeMotionCore

/// The single set of backend service instances for the running application.
///
/// An `AppServices` value only exists once every service has been created and the
/// coordinator has started, so holding one means the hardware monitor is live.
/// Views observe the individual objects (power monitor, coordinator, ...) directly.
/// The struct only holds references; each object keeps its own main-actor isolation.
struct AppServices {
    let settingsStore: AppSettingsStore
    let mediaLibrary: MediaLibraryStore
    let powerMonitor: IOKitPowerMonitor
    let playbackEnvironment: PlaybackEnvironment
    /// The controller that drives the desktop wallpaper. It belongs to the coordinator's
    /// pipeline. Previews must use a separate `VideoPlaybackController` instance.
    let playbackController: VideoPlaybackController
    let windowManager: DesktopWallpaperWindowManager
    let coordinator: WallpaperCoordinator
    let settings: SettingsController
    let launchAtLogin: LaunchAtLoginController
}
