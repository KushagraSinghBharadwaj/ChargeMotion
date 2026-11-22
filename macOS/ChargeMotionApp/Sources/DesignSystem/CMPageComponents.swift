import SwiftUI

/// Scrolling page with a title, optional subtitle and a width-limited content column.
struct CMPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    private let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CMSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).cmText(.titleLarge).foregroundStyle(CMColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle).cmText(.body).foregroundStyle(CMColor.textSecondary)
                    }
                }
                content
            }
            .padding(CMSpacing.xl)
            .frame(maxWidth: CMLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Label and value on one line.
struct CMInfoRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CMSpacing.md) {
            Text(label).cmText(.caption).foregroundStyle(CMColor.textTertiary)
                .frame(width: 130, alignment: .leading)
            Text(value).cmText(monospaced ? .mono : .body).foregroundStyle(CMColor.textPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline message with an optional action.
struct CMBanner: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var tone: CMTone = .neutral
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: CMSpacing.sm) {
            Image(systemName: systemImage).foregroundStyle(tone.foreground).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).cmText(.bodyEmphasis).foregroundStyle(CMColor.textPrimary)
                if let message {
                    Text(message).cmText(.callout).foregroundStyle(CMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: CMSpacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.cmSecondary)
            }
            if let onDismiss {
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.cmIcon).accessibilityLabel("Dismiss").help("Dismiss")
            }
        }
        .padding(CMSpacing.sm)
        .background(RoundedRectangle(cornerRadius: CMRadius.tile, style: .continuous).fill(tone.fill))
        .overlay(RoundedRectangle(cornerRadius: CMRadius.tile, style: .continuous).strokeBorder(tone.stroke, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
