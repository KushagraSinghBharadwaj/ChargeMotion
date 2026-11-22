import SwiftUI
import ChargeMotionCore

/// Temporary development screen that exercises every design-system piece and proves
/// the ChargeMotionCore package links. It is replaced by the real shell in Task 4.
///
/// The design-system sections show sample content only. The diagnostics card at the top
/// (present once services are running) is the only part that shows live state.
struct DesignSystemPreviewView: View {
    private let services: AppServices?

    @AppStorage(CMAppearancePreference.storageKey)
    private var appearanceRaw: String = CMAppearancePreference.dark.rawValue

    init(services: AppServices? = nil) {
        self.services = services
    }

    private struct Swatch: Identifiable {
        let name: String
        let color: Color
        var id: String { name }
    }

    private let swatches: [Swatch] = [
        Swatch(name: "Ink", color: CMColor.ink),
        Swatch(name: "Charcoal", color: CMColor.charcoal),
        Swatch(name: "Graphite", color: CMColor.graphite),
        Swatch(name: "Slate", color: CMColor.slate),
        Swatch(name: "Accent", color: CMColor.accent),
        Swatch(name: "Accent deep", color: CMColor.accentDeep),
        Swatch(name: "Gold", color: CMColor.gold),
        Swatch(name: "Warning", color: CMColor.warning),
        Swatch(name: "Danger", color: CMColor.danger),
        Swatch(name: "Info", color: CMColor.info)
    ]

    var body: some View {
        ZStack {
            CMBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: CMSpacing.xl) {
                    header
                    if let services {
                        CompositionDiagnosticsView(services: services)
                    }
                    paletteSection
                    typographySection
                    controlsSection
                    surfacesSection
                    backendLinkSection
                }
                .padding(CMSpacing.xl)
                .frame(maxWidth: CMLayout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                Text("ChargeMotion design system")
                    .cmText(.display)
                    .foregroundStyle(CMColor.textPrimary)
                Text("Development preview of colors, type, surfaces and controls.")
                    .cmText(.body)
                    .foregroundStyle(CMColor.textSecondary)
            }
            Spacer()
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(CMAppearancePreference.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .help("Switch between dark, light and system appearance")
        }
    }

    private var paletteSection: some View {
        CMCard(title: "Palette", subtitle: "Dark is primary; light keeps the same hierarchy.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: CMSpacing.sm)], spacing: CMSpacing.sm) {
                ForEach(swatches) { swatch in
                    VStack(alignment: .leading, spacing: CMSpacing.xs) {
                        RoundedRectangle(cornerRadius: CMRadius.control, style: .continuous)
                            .fill(swatch.color)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: CMRadius.control, style: .continuous)
                                    .strokeBorder(CMColor.edgeHighlight.opacity(0.14), lineWidth: 1)
                            )
                        Text(swatch.name)
                            .cmText(.caption)
                            .foregroundStyle(CMColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var typographySection: some View {
        CMCard(title: "Typography") {
            VStack(alignment: .leading, spacing: CMSpacing.sm) {
                ForEach(CMTextStyle.allCases, id: \.displayName) { style in
                    HStack(alignment: .firstTextBaseline, spacing: CMSpacing.md) {
                        Text(style.displayName)
                            .cmText(.caption)
                            .foregroundStyle(CMColor.textTertiary)
                            .frame(width: 190, alignment: .leading)
                        Text(sample(for: style))
                            .cmText(style)
                            .foregroundStyle(CMColor.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        CMCard(title: "Controls") {
            VStack(alignment: .leading, spacing: CMSpacing.md) {
                HStack(spacing: CMSpacing.sm) {
                    Button("Primary action") {}
                        .buttonStyle(.cmPrimary)
                    Button("Secondary action") {}
                        .buttonStyle(.cmSecondary)
                    Button("Disabled") {}
                        .buttonStyle(.cmPrimary)
                        .disabled(true)
                    Button {
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.cmIcon)
                    .accessibilityLabel("Play")
                    .help("Play")
                }
                HStack(spacing: CMSpacing.xs) {
                    CMStatusChip(title: "Neutral", systemImage: "circle", tone: .neutral)
                    CMStatusChip(title: "Active", systemImage: "bolt.fill", tone: .accent)
                    CMStatusChip(title: "Needs attention", systemImage: "exclamationmark.triangle.fill", tone: .warning)
                    CMStatusChip(title: "Failed", systemImage: "xmark.octagon.fill", tone: .danger)
                    CMStatusChip(title: "Info", systemImage: "info.circle.fill", tone: .info)
                }
            }
        }
    }

    private var surfacesSection: some View {
        HStack(alignment: .top, spacing: CMSpacing.md) {
            CMCard(title: "Interactive card", subtitle: "Move the pointer over this card.", spotlight: true) {
                Text("The green spotlight is reserved for surfaces a person can act on.")
                    .cmText(.body)
                    .foregroundStyle(CMColor.textSecondary)
            }
            CMCard(title: "Static card", subtitle: "No hover effect.", level: .base) {
                Text("Panels that only display information stay still.")
                    .cmText(.body)
                    .foregroundStyle(CMColor.textSecondary)
            }
            CMCard(level: .overlay) {
                CMEmptyState(
                    systemImage: "film.stack",
                    title: "No videos yet",
                    message: "Import an MP4, MOV or M4V file to use it as a wallpaper.",
                    tone: .accent,
                    actionTitle: "Import video",
                    action: {}
                )
            }
        }
    }

    /// Lists the real `PowerState` cases from the backend package. These are the
    /// model's possible values, not the Mac's current state.
    private var backendLinkSection: some View {
        CMCard(
            title: "Backend link check",
            subtitle: "PowerState cases read from ChargeMotionCore. These are model values, not live state."
        ) {
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                ForEach(PowerState.allCases, id: \.self) { state in
                    HStack {
                        Text(state.title)
                            .cmText(.body)
                            .foregroundStyle(CMColor.textPrimary)
                        Spacer()
                        CMStatusChip(
                            title: externalPowerLabel(for: state),
                            tone: externalPowerTone(for: state)
                        )
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func sample(for style: CMTextStyle) -> String {
        switch style {
        case .metricLarge, .metric: return "86%"
        case .mono: return "3F2A9C1E-7B44.mp4"
        default: return "Charging wallpaper"
        }
    }

    private func externalPowerLabel(for state: PowerState) -> String {
        switch state.isExternalPowerConnected {
        case .some(true): return "External power"
        case .some(false): return "No external power"
        case .none: return "Unknown"
        }
    }

    private func externalPowerTone(for state: PowerState) -> CMTone {
        switch state.isExternalPowerConnected {
        case .some(true): return .accent
        case .some(false): return .neutral
        case .none: return .warning
        }
    }
}
