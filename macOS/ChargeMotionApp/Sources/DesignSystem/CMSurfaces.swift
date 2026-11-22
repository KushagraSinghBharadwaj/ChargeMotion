import SwiftUI

enum CMSurfaceLevel {
    case base, raised, overlay
}

// MARK: - Glass

struct CMGlassModifier: ViewModifier {
    let level: CMSurfaceLevel
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let deep = level == .overlay

        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(CMColor.surfaceTint(level))
                    shape.fill(
                        LinearGradient(
                            colors: [CMColor.edgeHighlight.opacity(0.09), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            CMColor.edgeHighlight.opacity(0.26),
                            CMColor.edgeHighlight.opacity(0.05),
                            CMColor.accent.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .clipShape(shape)
            .shadow(
                color: CMColor.shadow.opacity(deep ? 0.55 : 0.36),
                radius: deep ? 28 : 16,
                x: 0,
                y: deep ? 16 : 9
            )
    }
}

// MARK: - Spotlight

/// A soft green glow that follows the pointer. Reserve it for surfaces a person can
/// act on (selectable tiles, media cards); static panels stay still.
struct CMSpotlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    let radius: CGFloat
    let isEnabled: Bool

    @State private var pointer: CGPoint?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled {
                    GeometryReader { proxy in
                        if let pointer {
                            RadialGradient(
                                colors: [CMColor.accent.opacity(0.17), Color.clear],
                                center: UnitPoint(
                                    x: pointer.x / max(proxy.size.width, 1),
                                    y: pointer.y / max(proxy.size.height, 1)
                                ),
                                startRadius: 0,
                                endRadius: radius
                            )
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .blendMode(.plusLighter)
                            .transition(.opacity)
                        }
                    }
                    .allowsHitTesting(false)
                    .cmAnimation(CMMotion.hover, value: pointer == nil)
                }
            }
            .onContinuousHover { phase in
                guard isEnabled else { return }
                switch phase {
                case .active(let location):
                    pointer = location
                case .ended:
                    pointer = nil
                }
            }
    }
}

extension View {
    func cmGlass(level: CMSurfaceLevel = .raised, cornerRadius: CGFloat = CMRadius.card) -> some View {
        modifier(CMGlassModifier(level: level, cornerRadius: cornerRadius))
    }

    func cmSpotlight(
        cornerRadius: CGFloat = CMRadius.card,
        radius: CGFloat = 240,
        isEnabled: Bool = true
    ) -> some View {
        modifier(CMSpotlightModifier(cornerRadius: cornerRadius, radius: radius, isEnabled: isEnabled))
    }
}

// MARK: - Background

/// Window background: near-black with a faint green bloom top-right and a warm
/// metallic bloom bottom-left.
struct CMBackground: View {
    var body: some View {
        ZStack {
            CMColor.ink
            LinearGradient(
                colors: [CMColor.charcoal, CMColor.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [CMColor.accent.opacity(0.10), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [CMColor.gold.opacity(0.05), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
