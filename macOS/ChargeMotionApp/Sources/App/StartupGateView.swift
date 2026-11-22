import SwiftUI

/// Shows the right screen for the application phase: progress while starting, a clear
/// failure screen if startup failed, and the application shell once services are running.
struct StartupGateView: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        switch environment.phase {
        case .running(let services):
            AppShellView(services: services)
        case .failed(let failure):
            StartupFailureView(
                failure: failure,
                onRetry: { environment.retry() },
                onReset: resetAction(for: failure)
            )
        case .notStarted, .starting:
            StartupProgressView(message: "Starting ChargeMotion")
        case .shuttingDown, .stopped:
            StartupProgressView(message: "Shutting down")
        }
    }

    /// Reset is offered only when the settings file caused the failure.
    private func resetAction(for failure: StartupFailure) -> (() -> Void)? {
        guard failure.canResetSettings else { return nil }
        return { environment.resetSettingsAndRetry() }
    }
}

private struct StartupProgressView: View {
    let message: String

    var body: some View {
        ZStack {
            CMBackground()
            VStack(spacing: CMSpacing.md) {
                ProgressView().controlSize(.large).tint(CMColor.accent)
                Text(message).cmText(.body).foregroundStyle(CMColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct StartupFailureView: View {
    let failure: StartupFailure
    let onRetry: () -> Void
    let onReset: (() -> Void)?

    var body: some View {
        ZStack {
            CMBackground()
            CMCard(level: .overlay) {
                VStack(spacing: CMSpacing.md) {
                    CMEmptyState(
                        systemImage: "exclamationmark.triangle",
                        title: failure.title,
                        message: failure.message,
                        tone: .danger,
                        actionTitle: "Retry",
                        action: onRetry
                    )
                    if let onReset {
                        Button("Reset settings", action: onReset)
                            .buttonStyle(.cmSecondary)
                            .help("Delete the settings file and start with default settings")
                    }
                    VStack(spacing: 4) {
                        Text(failure.detail).cmText(.callout).foregroundStyle(CMColor.textTertiary)
                            .multilineTextAlignment(.center)
                        if let location = failure.location {
                            Text(location).cmText(.mono).foregroundStyle(CMColor.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: 560)
            .padding(CMSpacing.xl)
        }
    }
}
