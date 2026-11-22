import SwiftUI

// MARK: - Tone

enum CMTone {
    case neutral, accent, warning, danger, info

    var foreground: Color {
        switch self {
        case .neutral: return CMColor.textSecondary
        case .accent: return CMColor.accent
        case .warning: return CMColor.warning
        case .danger: return CMColor.danger
        case .info: return CMColor.info
        }
    }

    var fill: Color { foreground.opacity(0.14) }
    var stroke: Color { foreground.opacity(0.32) }
}

// MARK: - Status chip

struct CMStatusChip: View {
    let title: String
    var systemImage: String? = nil
    var tone: CMTone = .neutral

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(title)
                .cmText(.caption)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tone.fill))
        .overlay(Capsule().strokeBorder(tone.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section header

struct CMSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .cmText(.headline)
                .foregroundStyle(CMColor.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .cmText(.callout)
                    .foregroundStyle(CMColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Card

/// A glass panel with an optional header. Static by default; pass `spotlight: true`
/// only when the whole card responds to the pointer (selectable or clickable).
struct CMCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let level: CMSurfaceLevel
    private let spotlight: Bool
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        level: CMSurfaceLevel = .raised,
        spotlight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.level = level
        self.spotlight = spotlight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CMSpacing.md) {
            if let title {
                CMSectionHeader(title: title, subtitle: subtitle)
            }
            content
        }
        .padding(CMSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cmGlass(level: level, cornerRadius: CMRadius.card)
        .cmSpotlight(cornerRadius: CMRadius.card, isEnabled: spotlight)
    }
}

// MARK: - Empty / error state

/// Used for every empty, missing, unsupported and failure state so no screen is
/// ever blank. Say what happened and what to do next; do not apologize.
struct CMEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var tone: CMTone = .neutral
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: CMSpacing.md) {
            ZStack {
                Circle().fill(tone.fill)
                Circle().strokeBorder(tone.stroke, lineWidth: 1)
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(tone.foreground)
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)

            Text(title)
                .cmText(.title)
                .foregroundStyle(CMColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .cmText(.body)
                .foregroundStyle(CMColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.cmPrimary)
                    .padding(.top, CMSpacing.xs)
            }
        }
        .padding(CMSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}
