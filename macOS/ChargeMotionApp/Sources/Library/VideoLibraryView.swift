import SwiftUI
import ChargeMotionCore

/// The video library: grid of imported videos with import, preview, rename, remove and assignment.
struct VideoLibraryView: View {
    let ctx: ShellContext
    @ObservedObject private var catalog: MediaCatalogController
    @ObservedObject private var info: MediaInfoStore
    @ObservedObject private var settings: SettingsController

    @State private var previewAsset: MediaAsset?
    @State private var renameTarget: MediaAsset?
    @State private var renameText = ""
    @State private var removeTarget: MediaAsset?

    init(ctx: ShellContext) {
        self.ctx = ctx
        _catalog = ObservedObject(wrappedValue: ctx.catalog)
        _info = ObservedObject(wrappedValue: ctx.info)
        _settings = ObservedObject(wrappedValue: ctx.services.settings)
    }

    var body: some View {
        CMPage(title: "Video Library", subtitle: SidebarItem.videoLibrary.subtitle) {
            ForEach(catalog.notices) { notice in
                CMBanner(systemImage: icon(notice.tone), title: notice.message, tone: notice.tone,
                         onDismiss: { catalog.dismissNotice(notice.id) })
            }
            if catalog.isImporting {
                HStack(spacing: CMSpacing.sm) {
                    ProgressView().controlSize(.small).tint(CMColor.accent)
                    Text(catalog.importStatus).cmText(.body).foregroundStyle(CMColor.textSecondary)
                    Spacer()
                    Button("Cancel Import") { catalog.cancelImport() }.buttonStyle(.cmSecondary)
                }
                .accessibilityElement(children: .contain)
            }
            content
        }
        .dropDestination(for: URL.self) { urls, _ in
            catalog.startImport(urls)
            return !urls.isEmpty
        }
        .sheet(item: $previewAsset) { asset in
            VideoPreviewSheet(asset: asset, ctx: ctx)
        }
        .alert("Rename Video", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let target = renameTarget { Task { await catalog.rename(target, to: renameText) } }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .confirmationDialog("Remove this video?", isPresented: Binding(get: { removeTarget != nil }, set: { if !$0 { removeTarget = nil } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let target = removeTarget { Task { await catalog.remove(target) } }
                removeTarget = nil
            }
            Button("Cancel", role: .cancel) { removeTarget = nil }
        } message: {
            Text("\"\(removeTarget?.displayName ?? "")\" is deleted from ChargeMotion and unassigned from any wallpaper. Your original file isn't affected.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !catalog.hasLoaded {
            HStack { Spacer(); ProgressView("Loading library").tint(CMColor.accent); Spacer() }.padding(CMSpacing.xl)
        } else if catalog.assets.isEmpty {
            CMCard(level: .overlay) {
                CMEmptyState(systemImage: "film.stack", title: "No videos yet",
                             message: "Import an \(SupportedVideoFormats.readableList) file, or drop one here, to use it as a wallpaper.",
                             tone: .accent, actionTitle: "Import Video", action: { catalog.presentImportPanel() })
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: CMSpacing.md, alignment: .top)], spacing: CMSpacing.md) {
                ForEach(catalog.assets) { asset in card(asset) }
            }
        }
    }

    private func card(_ asset: MediaAsset) -> some View {
        let roles = catalog.role(s: settings.settings, of: asset)
        let entry = info.entries[asset.id]
        return CMCard(spotlight: true) {
            VideoThumbnailView(asset: asset, info: info)
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName).cmText(.headline).foregroundStyle(CMColor.textPrimary).lineLimit(2)
                Text(details(asset)).cmText(.callout).foregroundStyle(CMColor.textSecondary)
                if let meta = info.metadata(for: asset.id) {
                    Text([meta.resolutionText, meta.aspectRatioText, meta.frameRateText].compactMap { $0 }.joined(separator: " · "))
                        .cmText(.callout).foregroundStyle(CMColor.textTertiary)
                }
                if case .unavailable(let message) = entry {
                    CMBanner(systemImage: "exclamationmark.triangle.fill", title: "Details unavailable", message: message,
                             tone: .warning, actionTitle: "Retry", action: { info.retry(asset) })
                } else if case .ready(let loaded) = entry, !loaded.metadata.isPlayable {
                    CMStatusChip(title: "Can't be played", systemImage: "exclamationmark.triangle.fill", tone: .warning)
                }
            }
            HStack(spacing: CMSpacing.xs) {
                ForEach(roles) { role in CMStatusChip(title: role.title, systemImage: role.systemImage, tone: .accent) }
                if roles.isEmpty { CMStatusChip(title: "Not assigned") }
            }
            HStack(spacing: CMSpacing.xs) {
                Button("Preview") { previewAsset = asset }.buttonStyle(.cmSecondary)
                Menu("Use As") {
                    ForEach(WallpaperAssignmentRole.allCases) { role in
                        Button(role.assignedID(in: settings.settings) == asset.id ? "\(role.title) Wallpaper ✓" : "\(role.title) Wallpaper") {
                            catalog.assign(asset, to: role)
                        }
                    }
                }
                .menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Menu {
                    Button("Rename…") { renameText = asset.displayName; renameTarget = asset }
                    Button("Remove…", role: .destructive) { removeTarget = asset }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("More actions").help("Rename or remove")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func details(_ asset: MediaAsset) -> String {
        var parts = [asset.fileExtension.uppercased(), VideoFormatting.fileSize(asset.fileSize)]
        if let meta = info.metadata(for: asset.id), let d = meta.durationSeconds { parts.append(VideoFormatting.duration(d)) }
        parts.append("Imported \(VideoFormatting.date(asset.importedAt))")
        return parts.joined(separator: " · ")
    }

    private func icon(_ tone: CMTone) -> String {
        switch tone {
        case .danger: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .accent: return "checkmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
}
