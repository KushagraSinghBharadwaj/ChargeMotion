import SwiftUI
import ChargeMotionCore

/// The main window: sidebar, toolbar and one page at a time. Creates no backend objects.
struct AppShellView: View {
    @StateObject private var ctx: ShellContext
    @StateObject private var router = NavigationRouter()
    @ObservedObject private var coordinator: WallpaperCoordinator
    @ObservedObject private var catalog: MediaCatalogController

    init(services: AppServices) {
        let context = ShellContext(services: services)
        _ctx = StateObject(wrappedValue: context)
        _coordinator = ObservedObject(wrappedValue: services.coordinator)
        _catalog = ObservedObject(wrappedValue: context.catalog)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(ctx: ctx, router: router)
                .navigationSplitViewColumnWidth(min: 208, ideal: CMLayout.sidebarWidth, max: 288)
        } detail: {
            ZStack {
                CMBackground()
                page
            }
            .navigationTitle(router.selection.title)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if router.selection.offersImport {
                    Button { catalog.presentImportPanel() } label: {
                        Label("Import Video", systemImage: "square.and.arrow.down")
                    }
                    .disabled(catalog.isImporting)
                    .help("Import an MP4, MOV or M4V video")
                }
                Button {
                    Task { await refreshAll() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Re-read power state, displays and the video library")
                Button {
                    let paused = coordinator.conditions.userPaused
                    Task { await coordinator.setUserPaused(!paused) }
                } label: {
                    Label(coordinator.conditions.userPaused ? "Resume Wallpaper" : "Pause Wallpaper",
                          systemImage: coordinator.conditions.userPaused ? "play.fill" : "pause.fill")
                }
                .disabled(!coordinator.isRunning)
                .help(coordinator.conditions.userPaused ? "Resume the wallpaper video" : "Pause the wallpaper video")
            }
        }
        .environmentObject(router)
        .focusedSceneValue(\.navigationRouter, router)
        .task { await ctx.catalog.reload() }
    }

    private func refreshAll() async {
        await coordinator.refreshPowerState()
        ctx.displays.refresh()
        await ctx.catalog.reload()
    }

    @ViewBuilder
    private var page: some View {
        switch router.selection {
        case .dashboard: DashboardView(ctx: ctx)
        case .videoLibrary: VideoLibraryView(ctx: ctx)
        case .displays: DisplaysView(ctx: ctx)
        case .chargingWallpaper: WallpaperRoleView(role: .charging, ctx: ctx)
        case .batteryWallpaper: WallpaperRoleView(role: .battery, ctx: ctx)
        case .settings: SettingsView(services: ctx.services)
        case .about: AboutView()
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var router: NavigationRouter
    @ObservedObject private var power: IOKitPowerMonitor

    init(ctx: ShellContext, router: NavigationRouter) {
        self.router = router
        _power = ObservedObject(wrappedValue: ctx.services.powerMonitor)
    }

    private var selection: Binding<SidebarItem?> {
        Binding(get: { router.selection }, set: { if let value = $0 { router.selection = value } })
    }

    var body: some View {
        List(selection: selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(CMColor.charcoal.opacity(0.55))
        .safeAreaInset(edge: .top, spacing: 0) { brand }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var brand: some View {
        HStack(spacing: CMSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CMGradient.accent)
                Image(systemName: "bolt.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(CMColor.onAccent)
            }
            .frame(width: 30, height: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("ChargeMotion").cmText(.headline).foregroundStyle(CMColor.textPrimary)
                Text("Power-aware wallpaper").cmText(.caption).foregroundStyle(CMColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CMSpacing.md).padding(.top, CMSpacing.sm).padding(.bottom, CMSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        let p = power.state.presentation
        return HStack(spacing: CMSpacing.sm) {
            Image(systemName: p.systemImage).foregroundStyle(p.tone.foreground).frame(width: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.label).cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary)
                if let percent = power.snapshot.batteryPercent {
                    Text("\(percent)% battery").cmText(.caption).foregroundStyle(CMColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(CMSpacing.sm)
        .cmGlass(level: .base, cornerRadius: CMRadius.tile)
        .padding(CMSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Power status")
    }
}
