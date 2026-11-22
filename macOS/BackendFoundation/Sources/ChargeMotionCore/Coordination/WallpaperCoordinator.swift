import AppKit
import AVFoundation
import Combine
import Foundation

/// Connects power state, user settings, the media library, playback, and desktop windows.
///
/// The coordinator owns one looping player shared by the connected display layers.
/// This keeps playback synchronized and avoids decoding the same video separately
/// for every monitor. Each display still receives its own AppKit wallpaper window.
@MainActor
public final class WallpaperCoordinator: ObservableObject {
    @Published public private(set) var settings: AppSettings
    @Published public private(set) var conditions = SystemConditions()
    @Published public private(set) var currentPlan: WallpaperPlan?
    @Published public private(set) var lastError: String?
    @Published public private(set) var isRunning = false

    private let powerMonitor: IOKitPowerMonitor
    private let mediaLibrary: MediaLibraryStore
    private let playbackController: VideoPlaybackController
    private let windowManager: DesktopWallpaperWindowManager
    private let playbackEnvironment: PlaybackEnvironment

    private var powerSubscription: AnyCancellable?
    private var environmentSubscription: AnyCancellable?
    private var activeMediaID: UUID?
    private var fallbackRole: WallpaperRole?

    public init(
        mediaLibrary: MediaLibraryStore,
        settings: AppSettings = AppSettings(),
        powerMonitor: IOKitPowerMonitor = IOKitPowerMonitor(),
        playbackController: VideoPlaybackController = VideoPlaybackController(),
        windowManager: DesktopWallpaperWindowManager = DesktopWallpaperWindowManager(),
        playbackEnvironment: PlaybackEnvironment = PlaybackEnvironment()
    ) {
        self.mediaLibrary = mediaLibrary
        self.settings = settings
        self.powerMonitor = powerMonitor
        self.playbackController = playbackController
        self.windowManager = windowManager
        self.playbackEnvironment = playbackEnvironment
    }

    /// Starts power monitoring and immediately calculates the wallpaper plan.
    public func start() async {
        guard !isRunning else {
            await reconcile()
            return
        }

        isRunning = true
        playbackEnvironment.startMonitoring()
        powerSubscription = powerMonitor.$state
            .removeDuplicates()
            .sink { [weak self] newState in
                Task { @MainActor in
                    guard let self else { return }
                    self.conditions.powerState = newState
                    if let newRole = WallpaperPolicy.role(for: newState, fallback: self.fallbackRole) {
                        self.fallbackRole = newRole
                    }
                    await self.reconcile()
                }
            }

        environmentSubscription = playbackEnvironment.$snapshot
            .removeDuplicates()
            .sink { [weak self] snapshot in
                Task { @MainActor in
                    guard let self else { return }
                    await self.applyEnvironmentSnapshot(snapshot)
                }
            }

        await applyEnvironmentSnapshot(playbackEnvironment.snapshot)

        powerMonitor.start()
        conditions.powerState = powerMonitor.state
        if let role = WallpaperPolicy.role(for: powerMonitor.state, fallback: fallbackRole) {
            fallbackRole = role
        }
        await reconcile()
    }

    /// Stops monitoring, playback, and all desktop wallpaper windows.
    public func stop() {
        powerSubscription?.cancel()
        powerSubscription = nil
        environmentSubscription?.cancel()
        environmentSubscription = nil
        powerMonitor.stop()
        playbackEnvironment.stopMonitoring()
        playbackController.stop()
        windowManager.hideAll()
        activeMediaID = nil
        currentPlan = nil
        isRunning = false
    }

    public func updateSettings(_ newSettings: AppSettings) async {
        settings = newSettings
        await reconcile()
    }

    public func updateConditions(_ newConditions: SystemConditions) async {
        conditions = newConditions
        if let role = WallpaperPolicy.role(for: newConditions.powerState, fallback: fallbackRole) {
            fallbackRole = role
        }
        await reconcile()
    }

    public func setUserPaused(_ paused: Bool) async {
        conditions.userPaused = paused
        await reconcile()
    }

    /// Requests a fresh IOKit read, then updates the active wallpaper if necessary.
    public func refreshPowerState() async {
        powerMonitor.refresh()
        conditions.powerState = powerMonitor.state
        if let role = WallpaperPolicy.role(for: powerMonitor.state, fallback: fallbackRole) {
            fallbackRole = role
        }
        await reconcile()
    }

    /// Recomputes the policy and applies the resulting media and playback state.
    public func reconcile() async {
        do {
            let assets = await mediaLibrary.listAssets()
            let availableIDs = Set(assets.map(\.id))

            let chargingID = settings.chargingWallpaperID.flatMap { availableIDs.contains($0) ? $0 : nil }
            let batteryID = settings.batteryWallpaperID.flatMap { availableIDs.contains($0) ? $0 : nil }
            let manualID = settings.manualWallpaperID.flatMap { availableIDs.contains($0) ? $0 : nil }

            let plan = WallpaperPolicy.makePlan(
                settings: settings,
                conditions: conditions,
                chargingMediaID: chargingID,
                batteryMediaID: batteryID,
                manualMediaID: manualID,
                fallbackRole: fallbackRole
            )
            currentPlan = plan

            guard let mediaID = plan.mediaID, plan.issue == nil else {
                playbackController.stop()
                windowManager.hideAll()
                activeMediaID = nil
                lastError = plan.issue
                return
            }

            if activeMediaID != mediaID || playbackController.player == nil {
                let url = try await mediaLibrary.fileURL(for: mediaID)
                try playbackController.load(url: url, muted: settings.audioMuted || !settings.allowAudio)
                activeMediaID = mediaID
                attachPlayerToConnectedDisplays()
            }

            if plan.shouldPlay {
                windowManager.setVisible(true)
                playbackController.play()
                lastError = nil
            } else {
                // Keep the last rendered frame visible while policy conditions pause playback.
                playbackController.pause()
                windowManager.setVisible(true)
                lastError = nil
            }
        } catch {
            playbackController.stop()
            windowManager.hideAll()
            activeMediaID = nil
            lastError = error.localizedDescription
        }
    }

    private func applyEnvironmentSnapshot(
        _ snapshot: PlaybackEnvironmentSnapshot
    ) async {
        var updated = conditions
        updated.lowPowerModeEnabled = snapshot.isLowPowerModeEnabled
        updated.screenLocked = snapshot.isScreenLocked
        updated.systemAsleep = snapshot.isSystemSleeping
        updated.fullScreenAppActive = snapshot.hasFullScreenApplication

        await updateConditions(updated)
    }

    private func attachPlayerToConnectedDisplays() {
        guard let player = playbackController.player else { return }

        var players: [UInt32: AVPlayer] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else {
                continue
            }
            players[number.uint32Value] = player
        }
        windowManager.setPlayers(players)
    }
}
