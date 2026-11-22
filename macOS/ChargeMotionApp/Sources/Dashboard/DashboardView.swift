import SwiftUI
import ChargeMotionCore

/// Live overview bound to the existing services. No values are invented.
struct DashboardView: View {
    private let ctx: ShellContext
    @ObservedObject private var power: IOKitPowerMonitor
    @ObservedObject private var coordinator: WallpaperCoordinator
    @ObservedObject private var playback: VideoPlaybackController
    @ObservedObject private var windowManager: DesktopWallpaperWindowManager
    @ObservedObject private var settings: SettingsController
    @ObservedObject private var launch: LaunchAtLoginController
    @ObservedObject private var catalog: MediaCatalogController
    @ObservedObject private var info: MediaInfoStore
    @ObservedObject private var displays: DisplayMonitor
    @EnvironmentObject private var router: NavigationRouter

    init(ctx: ShellContext) {
        self.ctx = ctx
        _power = ObservedObject(wrappedValue: ctx.services.powerMonitor)
        _coordinator = ObservedObject(wrappedValue: ctx.services.coordinator)
        _playback = ObservedObject(wrappedValue: ctx.services.playbackController)
        _windowManager = ObservedObject(wrappedValue: ctx.services.windowManager)
        _settings = ObservedObject(wrappedValue: ctx.services.settings)
        _launch = ObservedObject(wrappedValue: ctx.services.launchAtLogin)
        _catalog = ObservedObject(wrappedValue: ctx.catalog)
        _info = ObservedObject(wrappedValue: ctx.info)
        _displays = ObservedObject(wrappedValue: ctx.displays)
    }

    private var plan: WallpaperPlan? { coordinator.currentPlan }

    private var warnings: [DashboardWarning] {
        DashboardWarningBuilder.make(
            powerState: power.state, readSucceeded: power.snapshot.readSucceeded, plan: plan,
            coordinatorError: coordinator.lastError, assetCount: catalog.assets.count, catalogLoaded: catalog.hasLoaded,
            saveError: settings.lastSaveError, loginStatus: launch.status,
            connectedIDs: displays.displays.map(\.id), activeIDs: windowManager.activeDisplayIDs)
    }

    var body: some View {
        CMPage(title: "Dashboard", subtitle: SidebarItem.dashboard.subtitle) {
            ForEach(warnings) { warning in
                banner(warning)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: CMSpacing.md, alignment: .top)], spacing: CMSpacing.md) {
                powerCard
                wallpaperCard
                assignmentCard(.charging)
                assignmentCard(.battery)
                displaysCard
            }
        }
    }

    private func banner(_ warning: DashboardWarning) -> some View {
        let target = warning.target
        return CMBanner(
            systemImage: warning.systemImage, title: warning.title, message: warning.message, tone: warning.tone,
            actionTitle: target.map { "Open \($0.title)" },
            action: target == nil ? nil : { if let target { router.navigate(to: target) } })
    }

    // MARK: Cards

    private func yesNo(_ value: Bool?) -> String { value.map { $0 ? "Yes" : "No" } ?? "Not reported" }

    private var powerCard: some View {
        let p = power.state.presentation
        let snap = power.snapshot
        return CMCard(title: "Power") {
            HStack(spacing: CMSpacing.md) {
                Image(systemName: p.systemImage).font(.system(size: 34)).foregroundStyle(p.tone.foreground).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.label).cmText(.title).foregroundStyle(CMColor.textPrimary)
                    Text(p.detail).cmText(.callout).foregroundStyle(CMColor.textSecondary)
                }
                Spacer()
                if let percent = snap.batteryPercent { Text("\(percent)%").cmText(.metricLarge).foregroundStyle(CMColor.textPrimary) }
            }
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                CMInfoRow(label: "External power", value: yesNo(power.state.isExternalPowerConnected))
                CMInfoRow(label: "Charging", value: snap.hasInternalBattery ? yesNo(snap.isCharging) : "No internal battery")
                CMInfoRow(label: "Fully charged", value: snap.hasInternalBattery ? yesNo(snap.isCharged) : "No internal battery")
                CMInfoRow(label: "Battery level", value: snap.batteryPercent.map { "\($0)%" } ?? "Not reported")
            }
        }
    }

    private var wallpaperCard: some View {
        let summary = PlaybackSummary.make(running: coordinator.isRunning, plan: plan, error: coordinator.lastError,
                                           isPlaying: playback.isPlaying, automatic: settings.settings.automaticSwitchingEnabled)
        let active = catalog.asset(for: plan?.mediaID)
        return CMCard(title: "Wallpaper") {
            HStack(spacing: CMSpacing.sm) {
                CMStatusChip(title: summary.title, systemImage: summary.systemImage, tone: summary.tone)
                if let role = plan?.role { CMStatusChip(title: "\(role.displayTitle) role", tone: .neutral) }
            }
            if let detail = summary.detail {
                Text(detail).cmText(.callout).foregroundStyle(CMColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if let active {
                HStack(spacing: CMSpacing.sm) {
                    VideoThumbnailView(asset: active, info: info).frame(width: 120)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active video").cmText(.caption).foregroundStyle(CMColor.textTertiary)
                        Text(active.displayName).cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary).lineLimit(2)
                    }
                }
            }
            Toggle("Switch automatically with power state", isOn: Binding(
                get: { settings.settings.automaticSwitchingEnabled },
                set: { value in settings.update { $0.automaticSwitchingEnabled = value } }))
                .toggleStyle(.switch).tint(CMColor.accent)
            HStack(spacing: CMSpacing.sm) {
                Button(coordinator.conditions.userPaused ? "Resume" : "Pause") {
                    let paused = coordinator.conditions.userPaused
                    Task { await coordinator.setUserPaused(!paused) }
                }
                .buttonStyle(.cmPrimary).disabled(!coordinator.isRunning)
                Button("Refresh Power State") { Task { await coordinator.refreshPowerState() } }.buttonStyle(.cmSecondary)
            }
        }
    }

    private func assignmentCard(_ role: WallpaperAssignmentRole) -> some View {
        let asset = catalog.asset(for: role.assignedID(in: settings.settings))
        return CMCard(title: "\(role.title) wallpaper", subtitle: asset == nil ? "Nothing assigned" : nil, level: .base) {
            if let asset {
                HStack(spacing: CMSpacing.sm) {
                    VideoThumbnailView(asset: asset, info: info).frame(width: 120)
                    Text(asset.displayName).cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary).lineLimit(2)
                    Spacer()
                }
            }
            Button(asset == nil ? "Choose a Video" : "Change") { router.navigate(to: role.sidebarItem) }.buttonStyle(.cmSecondary)
        }
    }

    private var displaysCard: some View {
        let active = Set(windowManager.activeDisplayIDs)
        return CMCard(title: "Displays", subtitle: "\(displays.displays.count) connected", level: .base) {
            ForEach(displays.displays) { display in
                HStack {
                    Text(display.name).cmText(.body).foregroundStyle(CMColor.textPrimary)
                    Spacer()
                    CMStatusChip(title: active.contains(display.id) ? "Wallpaper active" : "No window",
                                 tone: active.contains(display.id) ? .accent : .neutral)
                }
            }
            Button("Open Displays") { router.navigate(to: .displays) }.buttonStyle(.cmSecondary)
        }
    }
}
