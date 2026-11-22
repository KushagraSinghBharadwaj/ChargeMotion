import Foundation
import ServiceManagement
import ChargeMotionCore

/// Observable wrapper around the backend `LaunchAtLoginManager`.
///
/// The system owns this state, so it is not stored in `AppSettings`. Requesting
/// registration does not mean the login item is approved: always show `status`.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private let manager: LaunchAtLoginManager

    init(manager: LaunchAtLoginManager) {
        self.manager = manager
        self.status = manager.status
    }

    func refresh() {
        status = manager.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            try manager.setEnabled(enabled)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        status = manager.status
    }

    /// Opens System Settings at Login Items, where the person can approve the item.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
