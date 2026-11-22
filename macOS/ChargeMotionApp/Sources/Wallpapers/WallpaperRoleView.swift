import SwiftUI
import ChargeMotionCore

/// Charging / Battery wallpaper page: shows the current selection and lets the person pick
/// any imported video for this role. Writes only `chargingWallpaperID` / `batteryWallpaperID`.
struct WallpaperRoleView: View {
    let role: WallpaperAssignmentRole
    let ctx: ShellContext
    @ObservedObject private var settings: SettingsController
    @ObservedObject private var catalog: MediaCatalogController
    @ObservedObject private var info: MediaInfoStore
    @ObservedObject private var coordinator: WallpaperCoordinator
    @EnvironmentObject private var router: NavigationRouter
    @State private var previewAsset: MediaAsset?

    init(role: WallpaperAssignmentRole, ctx: ShellContext) {
        self.role = role
        self.ctx = ctx
        _settings = ObservedObject(wrappedValue: ctx.services.settings)
        _catalog = ObservedObject(wrappedValue: ctx.catalog)
        _info = ObservedObject(wrappedValue: ctx.info)
        _coordinator = ObservedObject(wrappedValue: ctx.services.coordinator)
    }

    private var selectedID: UUID? { role.assignedID(in: settings.settings) }

    var body: some View {
        CMPage(title: "\(role.title) Wallpaper", subtitle: role.sidebarItem.subtitle) {
            CMCard(title: "Current selection") {
                if let asset = catalog.asset(for: selectedID) {
                    HStack(alignment: .top, spacing: CMSpacing.md) {
                        VideoThumbnailView(asset: asset, info: info).frame(width: 260)
                        VStack(alignment: .leading, spacing: CMSpacing.xs) {
                            Text(asset.displayName).cmText(.title).foregroundStyle(CMColor.textPrimary).lineLimit(2)
                            if coordinator.currentPlan?.role == role.backendRole {
                                CMStatusChip(title: "Active now", systemImage: "play.fill", tone: .accent)
                            }
                            Button("Clear Selection") { catalog.clearAssignment(for: role) }.buttonStyle(.cmSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("No video selected. Until you choose one, ChargeMotion shows your regular macOS wallpaper for this power state.")
                        .cmText(.body).foregroundStyle(CMColor.textSecondary)
                }
            }

            CMCard(title: "Choose a video", level: .base) {
                if !catalog.hasLoaded {
                    ProgressView().tint(CMColor.accent)
                } else if catalog.assets.isEmpty {
                    CMEmptyState(systemImage: "film.stack", title: "No videos yet",
                                 message: "Import an \(SupportedVideoFormats.readableList) video to choose it here.",
                                 tone: .accent, actionTitle: "Import Video", action: { catalog.presentImportPanel() })
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: CMSpacing.md, alignment: .top)], spacing: CMSpacing.md) {
                        ForEach(catalog.assets) { asset in tile(asset) }
                    }
                }
            }
        }
        .sheet(item: $previewAsset) { VideoPreviewSheet(asset: $0, ctx: ctx) }
    }

    private func tile(_ asset: MediaAsset) -> some View {
        let selected = asset.id == selectedID
        return VStack(alignment: .leading, spacing: CMSpacing.xs) {
            VideoThumbnailView(asset: asset, info: info)
                .overlay(RoundedRectangle(cornerRadius: CMRadius.tile, style: .continuous)
                    .strokeBorder(selected ? CMColor.accent : Color.clear, lineWidth: 2))
            Text(asset.displayName).cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary).lineLimit(1)
            HStack(spacing: CMSpacing.xs) {
                Button(selected ? "Selected" : "Use This") { catalog.assign(asset, to: role) }
                    .buttonStyle(.cmPrimary).disabled(selected)
                Button("Preview") { previewAsset = asset }.buttonStyle(.cmSecondary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
