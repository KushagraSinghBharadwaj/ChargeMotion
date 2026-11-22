import SwiftUI
import AppKit

// MARK: - Helpers

extension NSColor {
    /// sRGB color from a 0xRRGGBB value.
    convenience init(cmHex hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

/// A color that resolves differently in dark and light appearance.
private func cmDynamic(dark: NSColor, light: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? dark : light
    }))
}

private func cmDynamic(dark: UInt32, light: UInt32) -> Color {
    cmDynamic(dark: NSColor(cmHex: dark), light: NSColor(cmHex: light))
}

// MARK: - Palette

/// ChargeMotion palette. Dark appearance is the primary direction; light values
/// keep the same hierarchy with a deeper green so contrast holds on pale surfaces.
enum CMColor {
    // Backgrounds, deepest to highest.
    static let ink      = cmDynamic(dark: 0x050706, light: 0xF1F4F2)
    static let charcoal = cmDynamic(dark: 0x0C100F, light: 0xE7ECE9)
    static let graphite = cmDynamic(dark: 0x151B19, light: 0xFFFFFF)
    static let slate    = cmDynamic(dark: 0x1F2724, light: 0xF6F8F7)

    // Text.
    static let textPrimary   = cmDynamic(dark: 0xEEF3F0, light: 0x0D1311)
    static let textSecondary = cmDynamic(dark: 0x9DABA5, light: 0x47544F)
    static let textTertiary  = cmDynamic(dark: 0x6B7872, light: 0x75827D)

    // Accent: pastel-neon green.
    static let accent     = cmDynamic(dark: 0x7CFFB8, light: 0x0C9A5B)
    static let accentDeep = cmDynamic(dark: 0x2FE595, light: 0x087A47)
    /// Text or icons drawn on top of an accent fill.
    static let onAccent   = Color(nsColor: NSColor(cmHex: 0x03130B))

    // Status.
    static let warning = cmDynamic(dark: 0xFFC66B, light: 0xA86400)
    static let danger  = cmDynamic(dark: 0xFF7686, light: 0xC3243A)
    static let info    = cmDynamic(dark: 0x84C8FF, light: 0x0B6BB8)

    // Metallic detail (used sparingly: hairlines, medallion-related UI).
    static let gold          = Color(nsColor: NSColor(cmHex: 0xD9B26A))
    static let goldHighlight = Color(nsColor: NSColor(cmHex: 0xF4E2AE))
    static let goldShadow    = Color(nsColor: NSColor(cmHex: 0x8E6B2E))

    // Edges and shadows.
    /// White in dark appearance, black in light appearance: for hairlines and highlights.
    static let edgeHighlight = cmDynamic(dark: NSColor.white, light: NSColor.black)
    static let shadow = Color.black

    /// Translucent tint laid over the blur material for each surface level.
    static func surfaceTint(_ level: CMSurfaceLevel) -> Color {
        switch level {
        case .base:
            return cmDynamic(dark: NSColor(white: 0.0, alpha: 0.22), light: NSColor(white: 1.0, alpha: 0.35))
        case .raised:
            return cmDynamic(dark: NSColor(white: 1.0, alpha: 0.035), light: NSColor(white: 1.0, alpha: 0.60))
        case .overlay:
            return cmDynamic(dark: NSColor(white: 1.0, alpha: 0.065), light: NSColor(white: 1.0, alpha: 0.80))
        }
    }
}

enum CMGradient {
    static let accent = LinearGradient(
        colors: [CMColor.accent, CMColor.accentDeep],
        startPoint: .top, endPoint: .bottom
    )
    static let gold = LinearGradient(
        colors: [CMColor.goldHighlight, CMColor.gold, CMColor.goldShadow],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
