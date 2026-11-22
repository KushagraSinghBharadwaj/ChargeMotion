import SwiftUI
import ServiceManagement
import ChargeMotionCore

/// Controls existing AppSettings fields and the macOS login-item service.
struct SettingsView: View {
    @ObservedObject private var settings: SettingsController
    @ObservedObject private var launch: LaunchAtLoginController
    @AppStorage(CMAppearancePreference.storageKey)
    private var appearanceRaw = CMAppearancePreference.dark.rawValue

    init(services: AppServices) {
        _settings = ObservedObject(wrappedValue: services.settings)
        _launch = ObservedObject(wrappedValue: services.launchAtLogin)
    }

    private func binding<V>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { settings.settings[keyPath: keyPath] },
            set: { value in settings.update { $0[keyPath: keyPath] = value } }
        )
    }

    var body: some View {
        CMPage(title: "Settings", subtitle: SidebarItem.settings.subtitle) {
            if let error = settings.lastSaveError {
                CMBanner(
                    systemImage: "externaldrive.badge.exclamationmark",
                    title: "Settings couldn't be saved",
                    message: "Your latest choices may not survive quitting the app. \(error)",
                    tone: .danger
                )
            }

            switchingSection
            pauseSection
            videoSection
            startupSection
            appearanceSection
        }
        .onAppear {
            launch.refresh()
            if CMAppearancePreference(rawValue: appearanceRaw) == nil {
                appearanceRaw = CMAppearancePreference.dark.rawValue
            }
        }
    }

    private var switchingSection: some View {
        CMCard(title: "Automatic switching", subtitle: "Choose how ChargeMotion responds to power changes.") {
            settingToggle(
                "Switch wallpaper automatically with power state",
                binding(\.automaticSwitchingEnabled),
                "When enabled, ChargeMotion selects the charging or battery wallpaper according to the Mac's power state."
            )
        }
    }

    private var pauseSection: some View {
        CMCard(title: "Pause playback when", subtitle: "Playback resumes when the selected condition clears.") {
            settingToggle("Low Power Mode is on", binding(\.pauseOnLowPowerMode), nil)
            settingToggle(
                "A full-screen app is in front",
                binding(\.pauseOnFullScreenApp),
                "Detection is based on visible-window information and may not identify every full-screen app."
            )
            settingToggle("The screen is locked", binding(\.pauseWhileScreenLocked), nil)
            settingToggle(
                "Displays sleep",
                binding(\.pauseWhenDisplaysSleep),
                "This preference is saved, but the current backend does not yet detect display-sleep state. Enabling it has no effect yet."
            )
            settingToggle("The Mac is running on battery", binding(\.pauseOnBattery), nil)
        }
    }

    private var videoSection: some View {
        CMCard(title: "Video playback", subtitle: "Control how wallpaper videos are presented.") {
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                Text("Scaling").cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary)
                Picker("Scaling", selection: binding(\.scalingMode)) {
                    Text("Fill").tag(VideoScalingMode.fill)
                    Text("Fit").tag(VideoScalingMode.fit)
                    Text("Stretch").tag(VideoScalingMode.stretch)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Text("The selected mode is saved, but the current wallpaper renderer still uses Fill.")
                    .cmText(.callout)
                    .foregroundStyle(CMColor.textTertiary)
            }

            Divider().overlay(CMColor.edgeHighlight.opacity(0.12))

            settingToggle(
                "Allow wallpaper audio",
                binding(\.allowAudio),
                "Audio is disabled by default. Changes apply the next time a wallpaper video loads."
            )
            settingToggle(
                "Keep wallpaper audio muted",
                binding(\.audioMuted),
                "When audio is allowed, this keeps newly loaded wallpaper videos muted."
            )
            .disabled(!settings.settings.allowAudio)
            .opacity(settings.settings.allowAudio ? 1 : 0.55)
        }
    }

    private var startupSection: some View {
        CMCard(title: "Startup", subtitle: "Optionally start ChargeMotion automatically when you sign in to macOS.") {
            settingToggle(
                "Launch ChargeMotion at login",
                Binding(
                    get: {
                        launch.status == .enabled || launch.status == .requiresApproval
                    },
                    set: { launch.setEnabled($0) }
                ),
                "This is an optional macOS startup setting. It does not create a ChargeMotion account or require an app login."
            )

            HStack(alignment: .top, spacing: CMSpacing.sm) {
                Image(systemName: launchStatusSymbol)
                    .foregroundStyle(launchStatusTone)
                    .accessibilityHidden(true)

                Text(statusText)
                    .cmText(.callout)
                    .foregroundStyle(CMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = launch.lastError {
                CMBanner(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Login item couldn't be updated",
                    message: error,
                    tone: .danger
                )
            }

            if launch.status == .requiresApproval {
                Button("Open Login Items Settings") {
                    launch.openSystemSettings()
                }
                .buttonStyle(.cmSecondary)
            }

            Button("Refresh login-item status") {
                launch.refresh()
            }
            .buttonStyle(.cmSecondary)
        }
        .onAppear { launch.refresh() }
    }

    private var appearanceSection: some View {
        CMCard(title: "Appearance", subtitle: "Choose the look of the ChargeMotion window.") {
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(CMAppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Text("The appearance choice is stored locally on this Mac.")
                .cmText(.callout)
                .foregroundStyle(CMColor.textTertiary)
        }
    }

    private var statusText: String {
        switch launch.status {
        case .enabled:
            return "Enabled. macOS has registered ChargeMotion to launch at sign-in."
        case .notRegistered:
            return "Disabled. ChargeMotion will not launch automatically at sign-in."
        case .requiresApproval:
            return "Approval required. Open System Settings > General > Login Items and allow ChargeMotion."
        case .notFound:
            return "macOS couldn't find the login item for this app build. Try refreshing or reinstalling the app."
        @unknown default:
            return "macOS reported an unknown login-item status. Refresh to check again."
        }
    }

    private var launchStatusSymbol: String {
        switch launch.status {
        case .enabled: return "checkmark.circle.fill"
        case .requiresApproval: return "exclamationmark.circle.fill"
        case .notRegistered: return "minus.circle"
        case .notFound: return "questionmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var launchStatusTone: Color {
        switch launch.status {
        case .enabled: return CMColor.accent
        case .requiresApproval, .notFound: return CMColor.warning
        case .notRegistered: return CMColor.textTertiary
        @unknown default: return CMColor.textTertiary
        }
    }

    private func settingToggle(_ title: String, _ isOn: Binding<Bool>, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .tint(CMColor.accent)

            if let note {
                Text(note)
                    .cmText(.callout)
                    .foregroundStyle(CMColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AboutView: View {
    private func value(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    var body: some View {
        CMPage(title: "About", subtitle: SidebarItem.about.subtitle) {
            CMCard(level: .overlay) {
                HStack(spacing: CMSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CMGradient.accent)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(CMColor.onAccent)
                    }
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ChargeMotion")
                            .cmText(.title)
                            .foregroundStyle(CMColor.textPrimary)
                        Text("Power-aware video wallpaper")
                            .cmText(.body)
                            .foregroundStyle(CMColor.textSecondary)
                        Text("macOS")
                            .cmText(.caption)
                            .foregroundStyle(CMColor.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                Text("Your desktop wallpaper responds to your Mac's power state. Use separate videos for charging and battery operation, and let ChargeMotion switch between them automatically.")
                    .cmText(.body)
                    .foregroundStyle(CMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CMCard(title: "Application information") {
                CMInfoRow(label: "Version", value: value("CFBundleShortVersionString") ?? "Unknown")
                CMInfoRow(label: "Build", value: value("CFBundleVersion") ?? "Unknown")
                CMInfoRow(label: "Bundle ID", value: value("CFBundleIdentifier") ?? "Unknown")
                if let credit = value("NSHumanReadableCopyright") {
                    CMInfoRow(label: "Creator", value: credit.replacingOccurrences(of: "Made by ", with: ""))
                }
            }

            CMCard(title: "How it works") {
                aboutFeature(
                    "bolt.fill",
                    title: "Power-aware",
                    detail: "ChargeMotion reads the Mac's reported power state to choose the appropriate wallpaper."
                )
                aboutFeature(
                    "film",
                    title: "Your video library",
                    detail: "Imported videos are copied into ChargeMotion's library. Your original files are left untouched."
                )
                aboutFeature(
                    "display",
                    title: "Desktop wallpaper",
                    detail: "Videos are displayed behind your desktop icons. ChargeMotion does not animate the macOS lock screen."
                )
                aboutFeature(
                    "lock.shield",
                    title: "Local preferences",
                    detail: "Settings and imported media are stored locally on this Mac. No ChargeMotion account is required."
                )
            }

            Text("ChargeMotion is designed for macOS 14 or later.")
                .cmText(.callout)
                .foregroundStyle(CMColor.textTertiary)
        }
    }

    private func aboutFeature(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: CMSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CMColor.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .cmText(.bodyEmphasis)
                    .foregroundStyle(CMColor.textPrimary)
                Text(detail)
                    .cmText(.callout)
                    .foregroundStyle(CMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
