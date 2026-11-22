import SwiftUI

// Button styles share one shape (control radius) so primary and secondary actions
// line up when placed side by side. Icon-only buttons must set both
// `.accessibilityLabel(...)` and `.help(...)` at the call site.

// MARK: Primary

struct CMPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        CMPrimaryButtonBody(configuration: configuration)
    }
}

private struct CMPrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CMRadius.control, style: .continuous)

        configuration.label
            .cmText(.bodyEmphasis)
            .foregroundStyle(CMColor.onAccent)
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, 9)
            .background(shape.fill(CMGradient.accent))
            .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(
                color: CMColor.accent.opacity(hovering ? 0.42 : 0.22),
                radius: hovering ? 16 : 9,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(shape)
            .onHover { hovering = $0 }
            .cmAnimation(CMMotion.quick, value: configuration.isPressed)
            .cmAnimation(CMMotion.hover, value: hovering)
    }
}

// MARK: Secondary

struct CMSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        CMSecondaryButtonBody(configuration: configuration)
    }
}

private struct CMSecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CMRadius.control, style: .continuous)

        configuration.label
            .cmText(.bodyEmphasis)
            .foregroundStyle(hovering ? CMColor.accent : CMColor.textPrimary)
            .padding(.horizontal, CMSpacing.md)
            .padding(.vertical, 9)
            .background(shape.fill(CMColor.edgeHighlight.opacity(hovering ? 0.12 : 0.07)))
            .overlay(shape.strokeBorder(CMColor.edgeHighlight.opacity(hovering ? 0.28 : 0.16), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(shape)
            .onHover { hovering = $0 }
            .cmAnimation(CMMotion.quick, value: configuration.isPressed)
            .cmAnimation(CMMotion.hover, value: hovering)
    }
}

// MARK: Icon

struct CMIconButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        CMIconButtonBody(configuration: configuration)
    }
}

private struct CMIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(hovering ? CMColor.accent : CMColor.textSecondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(CMColor.edgeHighlight.opacity(hovering ? 0.13 : 0.06)))
            .overlay(Circle().strokeBorder(CMColor.edgeHighlight.opacity(hovering ? 0.26 : 0.12), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .cmAnimation(CMMotion.quick, value: configuration.isPressed)
            .cmAnimation(CMMotion.hover, value: hovering)
    }
}

// MARK: Shorthand

extension ButtonStyle where Self == CMPrimaryButtonStyle {
    static var cmPrimary: CMPrimaryButtonStyle { CMPrimaryButtonStyle() }
}

extension ButtonStyle where Self == CMSecondaryButtonStyle {
    static var cmSecondary: CMSecondaryButtonStyle { CMSecondaryButtonStyle() }
}

extension ButtonStyle where Self == CMIconButtonStyle {
    static var cmIcon: CMIconButtonStyle { CMIconButtonStyle() }
}
