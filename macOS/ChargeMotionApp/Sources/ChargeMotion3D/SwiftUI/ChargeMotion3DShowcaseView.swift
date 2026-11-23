import SwiftUI

/// 3D Studio surfaces use the shared ChargeMotion design system.
public enum ChargeMotion3DTheme {
    public static func cardFill(_ s: ColorScheme) -> LinearGradient {
        let colors = s == .dark
            ? [CMColor.graphite, CMColor.ink]
            : [CMColor.slate, CMColor.graphite]

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    public static func stroke(_ s: ColorScheme) -> Color {
        CMColor.edgeHighlight.opacity(0.12)
    }

    public static let accent = CMColor.accent
}

/// Self-contained "Studio" panel: mechanical koi card + hanging creator medallion.
/// Add it as one navigation destination / section; it does not alter existing screens.
public struct ChargeMotion3DShowcaseView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var handle = MechanicalKoiHandle()
    public var isActive: Bool
    public init(isActive: Bool = true) { self.isActive = isActive }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 720
            let layout = wide ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
            layout {
                koiCard.frame(minHeight: 280)
                medallionCard.frame(width: wide ? 210 : nil, height: wide ? nil : 300)
            }
            .padding(16)
        }
    }

    private var koiCard: some View {
        card {
            ZStack(alignment: .topLeading) {
                MechanicalKoiView(isActive: isActive, handle: handle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mechanical Koi").font(.headline)
                    Text("Drag to orbit · pinch or ⌥-scroll to zoom · double-click to reset")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(14)
                VStack { Spacer(); HStack { Spacer()
                    Button("Reset view") { handle.resetView() }.controlSize(.small).padding(12)
                } }
            }
        }
    }

    private var medallionCard: some View {
        card { CreatorMedallionView(isActive: isActive) }
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().background(ChargeMotion3DTheme.cardFill(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ChargeMotion3DTheme.stroke(scheme)))
    }
}
