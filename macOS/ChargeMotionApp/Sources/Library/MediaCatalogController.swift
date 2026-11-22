import AppKit
import Combine
import ChargeMotionCore

/// The single frontend entry point to `MediaLibraryStore`: observable asset list, import,
/// rename, remove and wallpaper assignment. It stores nothing itself; media lives in the
/// backend library and assignments live in `AppSettings` (changed via `SettingsController`).
@MainActor
final class MediaCatalogController: ObservableObject {
    struct Notice: Identifiable {
        let id = UUID()
        let tone: CMTone
        let message: String
    }

    @Published private(set) var assets: [MediaAsset] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var isImporting = false
    @Published private(set) var importStatus = ""
    @Published private(set) var notices: [Notice] = []

    private let library: MediaLibraryStore
    private let settings: SettingsController
    private let info: MediaInfoStore
    private var importTask: Task<Void, Never>?

    init(library: MediaLibraryStore, settings: SettingsController, info: MediaInfoStore) {
        self.library = library
        self.settings = settings
        self.info = info
    }

    func asset(for id: UUID?) -> MediaAsset? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    func role(s: AppSettings, of asset: MediaAsset) -> [WallpaperAssignmentRole] {
        WallpaperAssignmentRole.allCases.filter { $0.assignedID(in: s) == asset.id }
    }

    // MARK: Loading

    func reload() async {
        let latest = await library.listAssets()
        assets = latest
        hasLoaded = true
        let ids = Set(latest.map(\.id))
        info.prune(keeping: ids)
        // Clear assignments whose video no longer exists, so settings stay consistent.
        settings.update { s in
            if let id = s.chargingWallpaperID, !ids.contains(id) { s.chargingWallpaperID = nil }
            if let id = s.batteryWallpaperID, !ids.contains(id) { s.batteryWallpaperID = nil }
            if let id = s.manualWallpaperID, !ids.contains(id) {
                s.manualWallpaperID = nil
                s.manualOverrideEnabled = false
            }
        }
    }

    // MARK: Import

    func presentImportPanel() {
        guard !isImporting else { return }
        let panel = NSOpenPanel()
        panel.title = "Import Video"
        panel.message = "Choose \(SupportedVideoFormats.readableList) videos. ChargeMotion copies them; your originals aren't changed."
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = SupportedVideoFormats.contentTypes
        panel.begin { [weak self] response in
            let urls = panel.urls
            guard response == .OK, !urls.isEmpty else { return }
            Task { @MainActor in self?.startImport(urls) }
        }
    }

    func startImport(_ urls: [URL]) {
        guard importTask == nil else { addNotice(.info, "An import is already running."); return }
        importTask = Task { [self] in
            await runImport(urls)
            importTask = nil
        }
    }

    /// Stops after the file currently being copied; the backend's copy itself can't be interrupted.
    func cancelImport() { importTask?.cancel() }

    private func runImport(_ urls: [URL]) async {
        isImporting = true
        var imported = 0
        var wasCancelled = false
        for (index, url) in urls.enumerated() {
            if Task.isCancelled { wasCancelled = true; break }
            importStatus = "Importing \(url.lastPathComponent) (\(index + 1) of \(urls.count))"
            guard SupportedVideoFormats.isSupported(url) else {
                addNotice(.warning, "\"\(url.lastPathComponent)\" isn't supported. Import \(SupportedVideoFormats.readableList) files.")
                continue
            }
            do {
                _ = try await library.importFile(from: url)
                imported += 1
                await reload()
            } catch {
                addNotice(.danger, "\"\(url.lastPathComponent)\" couldn't be imported. \(error.localizedDescription)")
            }
        }
        isImporting = false
        importStatus = ""
        if wasCancelled { addNotice(.info, "Import cancelled. \(imported) of \(urls.count) imported.") }
        else if imported > 0 { addNotice(.accent, imported == 1 ? "Video imported." : "\(imported) videos imported.") }
    }

    // MARK: Rename, remove, assign

    func rename(_ asset: MediaAsset, to name: String) async {
        do {
            try await library.renameAsset(asset.id, to: name)
            await reload()
        } catch {
            addNotice(.danger, "Couldn't rename \"\(asset.displayName)\". \(error.localizedDescription)")
        }
    }

    /// Clears assignments first (through `SettingsController`), waits until the coordinator has
    /// applied that, then removes the video, so the wallpaper never points at a deleted file.
    func remove(_ asset: MediaAsset) async {
        settings.update { s in
            if s.chargingWallpaperID == asset.id { s.chargingWallpaperID = nil }
            if s.batteryWallpaperID == asset.id { s.batteryWallpaperID = nil }
            if s.manualWallpaperID == asset.id {
                s.manualWallpaperID = nil
                s.manualOverrideEnabled = false
            }
        }
        await settings.flush()
        do {
            try await library.removeAsset(asset.id)
            await info.discard(asset.id)
            addNotice(.neutral, "Removed \"\(asset.displayName)\".")
        } catch {
            addNotice(.danger, "Couldn't remove \"\(asset.displayName)\". \(error.localizedDescription)")
        }
        await reload()
    }

    func assign(_ asset: MediaAsset, to role: WallpaperAssignmentRole) {
        settings.update { role.apply(asset.id, to: &$0) }
    }

    func clearAssignment(for role: WallpaperAssignmentRole) {
        settings.update { role.apply(nil, to: &$0) }
    }

    // MARK: Notices

    func addNotice(_ tone: CMTone, _ message: String) {
        notices.append(Notice(tone: tone, message: message))
        if notices.count > 4 { notices.removeFirst(notices.count - 4) }
    }

    func dismissNotice(_ id: UUID) { notices.removeAll { $0.id == id } }
}
