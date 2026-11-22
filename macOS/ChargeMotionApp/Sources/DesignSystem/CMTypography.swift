import SwiftUI

/// Type scale. San Francisco throughout, with weight, size and tracking doing the
/// work: large sizes are tightened, small sizes stay open. Metrics use rounded,
/// tabular digits so changing numbers do not jitter.
enum CMTextStyle: CaseIterable {
    case display, titleLarge, title, headline
    case body, bodyEmphasis, callout, caption
    case metricLarge, metric, mono

    var displayName: String {
        switch self {
        case .display: return "Display"
        case .titleLarge: return "Title large"
        case .title: return "Title"
        case .headline: return "Headline"
        case .body: return "Body"
        case .bodyEmphasis: return "Body emphasis"
        case .callout: return "Callout"
        case .caption: return "Caption"
        case .metricLarge: return "Metric large"
        case .metric: return "Metric"
        case .mono: return "Monospaced (file names, IDs)"
        }
    }

    var font: Font {
        switch self {
        case .display:      return .system(size: 40, weight: .semibold)
        case .titleLarge:   return .system(size: 28, weight: .semibold)
        case .title:        return .system(size: 21, weight: .semibold)
        case .headline:     return .system(size: 15, weight: .semibold)
        case .body:         return .system(size: 13, weight: .regular)
        case .bodyEmphasis: return .system(size: 13, weight: .semibold)
        case .callout:      return .system(size: 12, weight: .regular)
        case .caption:      return .system(size: 11, weight: .medium)
        case .metricLarge:  return Font.system(size: 44, weight: .light, design: .rounded).monospacedDigit()
        case .metric:       return Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
        case .mono:         return .system(size: 12, weight: .regular, design: .monospaced)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: return -0.9
        case .titleLarge: return -0.5
        case .title: return -0.25
        case .metricLarge: return -1.0
        case .metric: return -0.3
        case .caption: return 0.1
        default: return 0
        }
    }
}

struct CMTextModifier: ViewModifier {
    let style: CMTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
    }
}

extension View {
    /// Applies a ChargeMotion text style (font and tracking). Color is set separately.
    func cmText(_ style: CMTextStyle) -> some View {
        modifier(CMTextModifier(style: style))
    }
}
