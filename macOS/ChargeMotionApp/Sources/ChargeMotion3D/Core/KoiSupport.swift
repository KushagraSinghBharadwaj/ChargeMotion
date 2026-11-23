import AppKit
import SceneKit

/// Small math helpers (namespaced so they can't collide with host-app helpers).
enum KoiMath {
    static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
    static func easeOutCubic(_ t: Double) -> Double { 1 - pow(1 - clamp(t, 0, 1), 3) }
    static func easeOutBack(_ t: Double) -> Double {
        let x = clamp(t, 0, 1), c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
    static func wrapAngle(_ a: Double) -> Double {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x > .pi { x -= 2 * .pi } else if x < -.pi { x += 2 * .pi }
        return x
    }
    /// Frame-rate independent exponential smoothing.
    static func damp(_ current: Double, to target: Double, rate: Double, dt: Double) -> Double {
        current + (target - current) * (1 - exp(-rate * dt))
    }
}

/// Lock-protected box. Input events arrive on the main thread, SceneKit's
/// per-frame callback runs on the render thread; this keeps shared state safe.
final class Atomic<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    init(_ v: Value) { value = v }
    func get() -> Value { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ v: Value) { lock.lock(); value = v; lock.unlock() }
    @discardableResult
    func mutate<R>(_ body: (inout Value) -> R) -> R { lock.lock(); defer { lock.unlock() }; return body(&value) }
}

@inline(__always)
func v3(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
    SCNVector3(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
}

/// Render quality presets (MSAA, shadow map size, frame cap).
public enum KoiRenderQuality: Sendable {
    case low, balanced, high
    var antialiasing: SCNAntialiasingMode {
        switch self {
        case .low: return .none
        case .balanced: return .multisampling2X
        case .high: return .multisampling4X
        }
    }
    var shadowMapSize: CGFloat {
        switch self { case .low: return 512; case .balanced: return 1024; case .high: return 2048 }
    }
    var shadowSamples: Int {
        switch self { case .low: return 2; case .balanced: return 4; case .high: return 8 }
    }
    var framesPerSecond: Int { self == .low ? 30 : 60 }
}

/// ChargeMotion-flavoured metallic palette using the shared ChargeMotion design tokens.
public struct KoiPalette {
    public var gold = NSColor(cmHex: 0xD9B26A)
    public var champagne = NSColor(cmHex: 0xF4E2AE)
    public var silver = NSColor(cmHex: 0xC8D1CC)
    public var titanium = NSColor(cmHex: 0x7C8982)
    public var darkTitanium = NSColor(cmHex: 0x202A25)
    public var vermilion = NSColor(srgbRed: 0.80, green: 0.17, blue: 0.09, alpha: 1)
    public var glow = NSColor(cmHex: 0x7CFFB8)
    public init() {}
}

/// Procedural textures (CoreGraphics only: thread-safe, no asset files needed).
enum KoiTextures {
    private static let cs = CGColorSpace(name: CGColorSpace.sRGB)!

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [min(1, max(0, r)), min(1, max(0, g)), min(1, max(0, b)), a])!
    }

    static func bitmap(_ w: Int, _ h: Int, draw: (CGContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        draw(ctx)
        return ctx.makeImage()
    }

    /// Dark studio lat-long map with soft-boxes: gives metals something to reflect.
    static func studioEnvironment() -> CGImage? {
        let w = 1024, h = 512
        return bitmap(w, h) { ctx in
            let bg = CGGradient(colorsSpace: cs,
                                colors: [rgb(0.015, 0.015, 0.02), rgb(0.11, 0.11, 0.13), rgb(0.035, 0.035, 0.05)] as CFArray,
                                locations: [0, 0.55, 1])!
            ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: 0, y: CGFloat(h)), options: [])
            func box(_ r: CGRect, _ c: CGColor, _ rad: CGFloat = 26) {
                ctx.setFillColor(c)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil))
                ctx.fillPath()
            }
            box(CGRect(x: 90, y: 290, width: 260, height: 140), rgb(1, 1, 1))              // key soft-box
            box(CGRect(x: 610, y: 320, width: 320, height: 90), rgb(1.0, 0.86, 0.62))      // warm strip
            box(CGRect(x: 400, y: 70, width: 190, height: 70), rgb(0.62, 0.78, 1.0))       // cool floor bounce
            box(CGRect(x: 0, y: 455, width: 1024, height: 22), rgb(0.9, 0.9, 0.95), 10)    // overhead strip
            box(CGRect(x: 770, y: 150, width: 70, height: 200), rgb(1.0, 0.8, 0.5))        // gold rim card
            box(CGRect(x: 240, y: 170, width: 60, height: 120), rgb(0.8, 0.85, 1.0))       // side card
        }
    }

    /// Overlapping-scale tile (seamless at 8x8 scales), tinted per metal.
    static func scalePattern(tint: NSColor) -> CGImage? {
        let t = tint.usingColorSpace(.sRGB) ?? tint
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        t.getRed(&r, green: &g, blue: &b, alpha: &a)
        return bitmap(256, 256) { ctx in
            ctx.setFillColor(rgb(r * 0.22, g * 0.22, b * 0.22))
            ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let cell: CGFloat = 32, radius: CGFloat = 19
            let grad = CGGradient(colorsSpace: cs,
                                  colors: [rgb(r * 1.1, g * 1.1, b * 1.1), rgb(r * 0.58, g * 0.58, b * 0.58)] as CFArray,
                                  locations: [0, 1])!
            for row in -1...8 {
                for col in -1...8 {
                    let cx = CGFloat(col) * cell + (row % 2 == 0 ? 0 : cell / 2) + cell / 2
                    let cy = CGFloat(row) * cell + cell / 2
                    let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                    ctx.saveGState()
                    ctx.addEllipse(in: rect)
                    ctx.clip()
                    ctx.drawRadialGradient(grad, startCenter: CGPoint(x: cx, y: cy + 5), startRadius: 1,
                                           endCenter: CGPoint(x: cx, y: cy), endRadius: radius, options: [])
                    ctx.restoreGState()
                    ctx.setStrokeColor(rgb(r * 0.16, g * 0.16, b * 0.16))
                    ctx.setLineWidth(1.6)
                    ctx.strokeEllipse(in: rect)
                }
            }
        }
    }
}

/// All PBR materials, built once per scene and shared by every node.
final class KoiMaterials {
    let polishedGold: SCNMaterial
    let brushedGold: SCNMaterial
    let silver: SCNMaterial
    let titanium: SCNMaterial
    let darkTitanium: SCNMaterial
    let vermilion: SCNMaterial
    let glow: SCNMaterial
    let blackGlass: SCNMaterial
    let field: SCNMaterial
    let scaledGold: SCNMaterial
    let scaledChampagne: SCNMaterial
    let scaledSilver: SCNMaterial

    static func pbr(_ color: Any, metal: Double, rough: Double) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metal
        m.roughness.contents = rough
        return m
    }

    private static func scaled(_ tint: NSColor, rough: Double) -> SCNMaterial {
        let m = pbr(KoiTextures.scalePattern(tint: tint) ?? tint, metal: 1.0, rough: rough)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 8
        return m
    }

    init(palette p: KoiPalette) {
        polishedGold = Self.pbr(p.gold, metal: 1, rough: 0.20)
        brushedGold = Self.pbr(p.gold, metal: 1, rough: 0.42)
        silver = Self.pbr(p.silver, metal: 1, rough: 0.17)
        titanium = Self.pbr(p.titanium, metal: 1, rough: 0.33)
        darkTitanium = Self.pbr(p.darkTitanium, metal: 0.9, rough: 0.45)
        field = Self.pbr(NSColor(srgbRed: 0.17, green: 0.18, blue: 0.21, alpha: 1), metal: 1, rough: 0.40)
        vermilion = Self.pbr(p.vermilion, metal: 0.85, rough: 0.26)
        blackGlass = Self.pbr(NSColor(white: 0.01, alpha: 1), metal: 0.2, rough: 0.03)
        let g = Self.pbr(NSColor(white: 0.05, alpha: 1), metal: 0, rough: 0.5)
        g.emission.contents = p.glow
        g.emission.intensity = 1.1
        glow = g
        scaledGold = Self.scaled(p.gold, rough: 0.30)
        scaledChampagne = Self.scaled(p.champagne, rough: 0.32)
        scaledSilver = Self.scaled(p.silver, rough: 0.28)
    }
}
