import Foundation
import Combine
import ChargeMotionCore

/// Holds the loaded `AppSettings`, applies changes to the coordinator, and persists
/// them through `AppSettingsStore`.
///
/// `update(_:)` changes the published value immediately so the UI stays responsive.
/// Applying to the coordinator and saving then run in order on a serial chain, so
/// rapid changes can never reach disk or the coordinator out of order.
@MainActor
final class SettingsController: ObservableObject {
    @Published private(set) var settings: AppSettings
    /// Set when the last attempt to save settings failed; cleared by the next success.
    @Published private(set) var lastSaveError: String?

    private let store: AppSettingsStore
    private let coordinator: WallpaperCoordinator
    private var syncTask: Task<Void, Never>?

    init(initial: AppSettings, store: AppSettingsStore, coordinator: WallpaperCoordinator) {
        self.settings = initial
        self.store = store
        self.coordinator = coordinator
    }

    /// Applies a change. Does nothing if the change leaves the settings unchanged.
    func update(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        enqueueSync(of: updated)
    }

    /// Waits until every queued change has been applied and saved.
    func flush() async {
        await syncTask?.value
    }

    private func enqueueSync(of snapshot: AppSettings) {
        let previous = syncTask
        syncTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await self.apply(snapshot)
        }
    }

    private func apply(_ snapshot: AppSettings) async {
        await coordinator.updateSettings(snapshot)
        do {
            try await store.save(snapshot)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }
}
