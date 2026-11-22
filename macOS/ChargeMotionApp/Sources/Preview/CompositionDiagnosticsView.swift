import SwiftUI
import ServiceManagement
import ChargeMotionCore

/// Temporary development card that shows live values from the retained backend
/// services, so the composition root can be verified on a Mac. Removed in Task 4.
///
/// Every value comes from a service that has already started; nothing is simulated.
struct CompositionDiagnosticsView: View {
    private let settingsStore: AppSettingsStore
    @ObservedObject private var coordinator: WallpaperCoordinator
    @ObservedObject private var powerMonitor: IOKitPowerMonitor
    @ObservedObject private var settings: SettingsController
    @ObservedObject private var launchAtLogin: LaunchAtLoginController

    @State private var settingsPath: String = "Reading…"

    init(services: AppServices) {
        self.settingsStore = services.settingsStore
        _coordinator = ObservedObject(wrappedValue: services.coordinator)
        _powerMonitor = ObservedObject(wrappedValue: services.powerMonitor)
        _settings = ObservedObject(wrappedValue: services.settings)
        _launchAtLogin = ObservedObject(wrappedValue: services.launchAtLogin)
    }

    var body: some View {
        CMCard(
            title: "Composition root diagnostics",
            subtitle: "Development only. Live values from the retained backend services. Removed in Task 4."
        ) {
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                row("Coordinator", coordinator.isRunning ? "Running" : "Stopped")
                row("Power state", powerMonitor.state.title)
                row("Battery level", batteryText)
                row("Wallpaper role", coordinator.currentPlan?.role?.rawValue ?? "None")
                row("Plan issue", coordinator.currentPlan?.issue ?? "None")
                row("Pause reasons", pauseText)
                row("Automatic switching", settings.settings.automaticSwitchingEnabled ? "On" : "Off")
                row("Last settings save", settings.lastSaveError ?? "No errors")
                row("Launch at login", text(for: launchAtLogin.status))
                row("Settings file", settingsPath)
            }
        }
        .task {
            settingsPath = await settingsStore.settingsFileURL().path
        }
    }

    // MARK: Rows

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CMSpacing.md) {
            Text(label)
                .cmText(.caption)
                .foregroundStyle(CMColor.textTertiary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .cmText(.body)
                .foregroundStyle(CMColor.textPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var batteryText: String {
        guard let percent = powerMonitor.snapshot.batteryPercent else { return "Not reported" }
        return "\(percent)%"
    }

    private var pauseText: String {
        guard let reasons = coordinator.currentPlan?.pauseReasons, !reasons.isEmpty else { return "None" }
        return reasons.map(\.rawValue).joined(separator: ", ")
    }

    private func text(for status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "Not registered"
        case .enabled: return "Enabled"
        case .requiresApproval: return "Needs approval in System Settings"
        case .notFound: return "Not found"
        @unknown default: return "Unknown"
        }
    }
}
