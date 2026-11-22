import Foundation
import Combine
import ChargeMotionCore

/// The application composition root.
///
/// Owns the one instance of every backend service, drives startup and shutdown, and
/// publishes a `Phase` the UI switches on. Nothing is created in `init`: services are
/// built in `performStart()` after settings and the media library load successfully,
/// so a failed start leaves no monitors, timers or windows behind.
///
/// Lifecycle (driven by `AppDelegate`):
///   launch   -> `start()`    -> .starting -> .running(services) | .failed(reason)
///   quit     -> `shutdown()` -> .shuttingDown -> .stopped
@MainActor
final class AppEnvironment: ObservableObject {
    enum Phase {
        case notStarted
        case starting
        case running(AppServices)
        case failed(StartupFailure)
        case shuttingDown
        case stopped
    }

    @Published private(set) var phase: Phase = .notStarted

    private let settingsStore: AppSettingsStore
    private var startTask: Task<Void, Never>?

    init(settingsStore: AppSettingsStore = AppSettingsStore()) {
        self.settingsStore = settingsStore
    }

    /// The services, available only while the application is running.
    var runningServices: AppServices? {
        if case .running(let services) = phase { return services }
        return nil
    }

    // MARK: - Lifecycle

    /// Starts the application once. Safe to call repeatedly.
    func start() {
        guard case .notStarted = phase else { return }
        startTask = Task { [self] in await performStart() }
    }

    /// Tries again after a startup failure.
    func retry() {
        guard case .failed = phase else { return }
        startTask = Task { [self] in await performStart() }
    }

    /// Deletes the settings file through `AppSettingsStore`, then tries again.
    /// Only available when the settings file was the cause of the failure.
    func resetSettingsAndRetry() {
        guard case .failed(let failure) = phase, failure.canResetSettings else { return }
        startTask = Task { [self] in
            do {
                try await settingsStore.deleteStoredSettings()
            } catch {
                let location = await settingsStore.settingsFileURL().path
                phase = .failed(.settingsResetFailed(error: error, location: location))
                return
            }
            await performStart()
        }
    }

    /// Stops monitoring, playback and wallpaper windows. Waits for any start in
    /// progress and for queued settings saves first. Safe to call more than once.
    func shutdown() async {
        await startTask?.value

        switch phase {
        case .running(let services):
            phase = .shuttingDown
            await services.settings.flush()
            // Stops power monitoring, cancels subscriptions, stops playback and hides every
            // wallpaper window, which reveals the original macOS wallpaper.
            services.coordinator.stop()
            services.playbackEnvironment.stopMonitoring()
            phase = .stopped
        case .notStarted, .failed:
            phase = .stopped
        case .starting, .shuttingDown, .stopped:
            break
        }
    }

    // MARK: - Startup

    private func performStart() async {
        switch phase {
        case .notStarted, .failed:
            break
        default:
            return
        }
        phase = .starting

        // 1. Persisted settings.
        let loadedSettings: AppSettings
        do {
            loadedSettings = try await settingsStore.load()
        } catch {
            let location = await settingsStore.settingsFileURL().path
            phase = .failed(.settingsUnreadable(error: error, location: location))
            return
        }

        // 2. Media library. The initializer performs a small amount of file I/O.
        let mediaLibrary: MediaLibraryStore
        do {
            mediaLibrary = try MediaLibraryStore()
        } catch {
            phase = .failed(.mediaLibraryUnavailable(error: error))
            return
        }

        // 3. One instance of each service. The coordinator is given every collaborator
        //    explicitly, so its default arguments (which would create duplicates) are unused.
        let powerMonitor = IOKitPowerMonitor()
        let playbackEnvironment = PlaybackEnvironment()
        let playbackController = VideoPlaybackController()
        let windowManager = DesktopWallpaperWindowManager()
        let coordinator = WallpaperCoordinator(
            mediaLibrary: mediaLibrary,
            settings: loadedSettings,
            powerMonitor: powerMonitor,
            playbackController: playbackController,
            windowManager: windowManager,
            playbackEnvironment: playbackEnvironment
        )

        // 4. Start. This starts the power monitor and applies the first wallpaper plan.
        //    The phase becomes .running only afterwards, so the UI never shows
        //    power state from a monitor that has not started.
        await coordinator.start()

        let services = AppServices(
            settingsStore: settingsStore,
            mediaLibrary: mediaLibrary,
            powerMonitor: powerMonitor,
            playbackEnvironment: playbackEnvironment,
            playbackController: playbackController,
            windowManager: windowManager,
            coordinator: coordinator,
            settings: SettingsController(
                initial: loadedSettings,
                store: settingsStore,
                coordinator: coordinator
            ),
            launchAtLogin: LaunchAtLoginController(manager: LaunchAtLoginManager())
        )
        phase = .running(services)
    }
}
