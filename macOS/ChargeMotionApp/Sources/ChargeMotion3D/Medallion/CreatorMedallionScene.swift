import AppKit
import SceneKit

/// Hanging creator medallion scene.
///
/// Motion model (integrated per frame with semi-implicit Euler, no timers):
///  - Chain pendulum (pivot1, about the mount pin) coupled to a second, faster pendulum (pivot2,
///    about the swivel eyelet). Both exist per axis (side-to-side Z, front-back X) and are lightly
///    damped, driven by a very small "breeze" force so the badge never sits dead still.
///  - Yaw (spin about the vertical axis) is a damped spring toward the front-facing pose (+ a slow
///    ±16° sway), so the engraved name is always readable once the badge settles. Dragging spins
///    it freely, releasing lets it swing back; double-click flicks a full flip to show the back.
///  - Hover leans the face toward the cursor and nudges the pendulum.
public final class CreatorMedallionScene: NSObject, SCNSceneRendererDelegate {
    public let scene = SCNScene()
    let cameraNode = SCNNode()

    private struct Input {
        var hover = false, dragging = false
        var hx = 0.0, hy = 0.0
        var dyaw = 0.0, dpitch = 0.0
        var impulseZ = 0.0, impulseX = 0.0
        var flip = false
    }
    private let input = Atomic(Input())
    private let rig: MedallionRig
    private let keyLight = SCNNode()
    private let aspect = Atomic(0.55)
    private let lastTime = Atomic(0.0)
    private let reducedMotion = Atomic(false)
    private let fov = 30.0
    private let centreY = -1.58

    // Physics state (render thread only)
    private var clock = 0.0
    private var th1z = 0.5, w1z = -0.4, th2z = 0.0, w2z = 0.0
    private var th1x = 0.0, w1x = 0.0, th2x = 0.0, w2x = 0.0
    private var yaw = 0.0, yawVel = 0.0
    private var dragPitch = 0.0, pitch = 0.0, hoverBlend = 0.0

    public init(palette: KoiPalette = KoiPalette(), quality: KoiRenderQuality = .balanced) {
        rig = MedallionModelBuilder.build(palette: palette)
        super.init()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = KoiTextures.studioEnvironment()
        scene.lightingEnvironment.intensity = 1.35
        scene.rootNode.addChildNode(rig.root)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1000
        key.temperature = 5600
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowMapSize = CGSize(width: quality.shadowMapSize, height: quality.shadowMapSize)
        key.shadowSampleCount = quality.shadowSamples
        key.shadowRadius = 6
        key.shadowColor = NSColor(white: 0, alpha: 0.5)
        key.maximumShadowDistance = 12
        keyLight.light = key
        keyLight.eulerAngles = v3(-0.45, 0.6, 0)
        scene.rootNode.addChildNode(keyLight)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 300
        fill.color = NSColor(srgbRed: 0.75, green: 0.82, blue: 1.0, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = v3(-3, centreY + 1, 4)
        scene.rootNode.addChildNode(fillNode)

        // Shadow-only wall behind the badge: the swinging shadow sells the depth.
        let wall = SCNPlane(width: 12, height: 12)
        let wm = SCNMaterial()
        wm.lightingModel = .shadowOnly
        wall.materials = [wm]
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = v3(0, centreY, -1.3)
        scene.rootNode.addChildNode(wallNode)

        let cam = SCNCamera()
        cam.fieldOfView = CGFloat(fov)
        cam.zNear = 0.1
        cam.zFar = 40
        cameraNode.camera = cam
        cameraNode.position = v3(0, centreY, 9)
        scene.rootNode.addChildNode(cameraNode)
        rig.root.opacity = 0                                  // fades in on first frame
        applyAppearance(isDark: true)
    }

    // MARK: Main-thread API

    func updateViewport(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        aspect.set(Double(size.width / size.height))
    }
    func setReducedMotion(_ on: Bool) { reducedMotion.set(on) }
    func resetClock() { lastTime.set(0) }

    func hover(nx: Double, ny: Double) { input.mutate { $0.hover = true; $0.hx = KoiMath.clamp(nx, -1, 1); $0.hy = KoiMath.clamp(ny, -1, 1) } }
    func endHover() { input.mutate { $0.hover = false } }
    func beginDrag() { input.mutate { $0.dragging = true } }
    func endDrag() { input.mutate { $0.dragging = false } }
    func drag(dx: Double, dy: Double) { input.mutate { $0.dyaw += dx * 0.012; $0.dpitch += -dy * 0.006 } }
    func tap(nx: Double) { input.mutate { $0.impulseZ += -nx * 0.9; $0.impulseX += 0.25 } }
    func flip() { input.mutate { $0.flip = true } }

    func applyAppearance(isDark: Bool) {
        scene.lightingEnvironment.intensity = isDark ? 1.35 : 1.6
        keyLight.light?.shadowColor = NSColor(white: 0, alpha: isDark ? 0.5 : 0.3)
    }

    func tearDown() {
        scene.rootNode.enumerateHierarchy { node, _ in
            node.removeAllActions(); node.geometry = nil; node.light = nil; node.camera = nil
        }
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        scene.lightingEnvironment.contents = nil
        scene.background.contents = nil
    }

    // MARK: Per-frame (render thread)

    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let prev = lastTime.get()
        lastTime.set(time)
        let dt = prev == 0 ? 1.0 / 60 : KoiMath.clamp(time - prev, 0, 1.0 / 20)
        step(dt: dt, motion: reducedMotion.get() ? 0.3 : 1.0)
        fitCamera()
    }

    private func step(dt: Double, motion: Double) {
        clock += dt
        let inp = input.mutate { (i: inout Input) -> Input in
            let c = i
            i.dyaw = 0; i.dpitch = 0; i.impulseZ = 0; i.impulseX = 0; i.flip = false
            return c
        }
        hoverBlend = KoiMath.damp(hoverBlend, to: inp.hover ? 1 : 0, rate: 5, dt: dt)

        // --- coupled pendulums (side-to-side Z and front-back X) ---
        w1z += inp.impulseZ; w1x += inp.impulseX
        let fz = (0.30 * sin(clock * 0.55) + 0.18 * sin(clock * 1.07 + 1.3)) * motion + inp.hx * 0.9 * hoverBlend
        let fx = 0.18 * sin(clock * 0.43 + 0.8) * motion
        let k1 = 5.8, c1 = 0.42, k2 = 9.0, c2 = 0.6
        func integrate(_ th1: inout Double, _ w1: inout Double, _ th2: inout Double, _ w2: inout Double, force: Double) {
            let a1 = -k1 * th1 - c1 * w1 + 1.3 * th2 + force
            w1 += a1 * dt; th1 += w1 * dt
            let a2 = -k2 * th2 - c2 * w2 - 0.55 * a1
            w2 += a2 * dt; th2 += w2 * dt
            th1 = KoiMath.clamp(th1, -0.7, 0.7); th2 = KoiMath.clamp(th2, -0.8, 0.8)
        }
        integrate(&th1z, &w1z, &th2z, &w2z, force: fz)
        integrate(&th1x, &w1x, &th2x, &w2x, force: fx)

        // --- yaw spin ---
        if inp.flip { yawVel += 9.0 }
        if inp.dragging {
            yaw += inp.dyaw
            yawVel = KoiMath.damp(yawVel, to: inp.dyaw / max(dt, 1e-3), rate: 20, dt: dt)
            dragPitch = KoiMath.clamp(dragPitch + inp.dpitch, -0.5, 0.5)
        } else {
            let sway = 0.28 * sin(clock * 0.5) * motion
            let target = inp.hover ? inp.hx * 0.5 : sway
            let err = KoiMath.wrapAngle(yaw - target)
            yawVel += (-4.2 * err - 2.0 * yawVel) * dt
            yaw += yawVel * dt
            dragPitch = KoiMath.damp(dragPitch, to: 0, rate: 2.5, dt: dt)
        }
        yaw = KoiMath.wrapAngle(yaw)
        pitch = KoiMath.damp(pitch, to: dragPitch + (inp.hover ? -inp.hy * 0.32 : 0), rate: 8, dt: dt)

        // --- appear transition: fade + overshoot scale, with the initial swing already in th1z ---
        let p = KoiMath.clamp((clock - 0.1) / 1.2, 0, 1)
        rig.root.opacity = CGFloat(KoiMath.easeOutCubic(p))
        let s = 0.85 + 0.15 * KoiMath.easeOutBack(p)
        rig.root.scale = v3(s, s, s)

        rig.pivot1.eulerAngles = v3(th1x, 0, th1z)
        rig.pivot2.eulerAngles = v3(th2x, 0, th2z)
        rig.spin.eulerAngles = v3(0, yaw, 0)
        rig.tilt.eulerAngles = v3(pitch, 0, 0)
    }

    /// Keeps the full hanging assembly in frame at any view size.
    private func fitCamera() {
        let t = tan(fov * .pi / 360)
        let halfH = 1.95, halfW = 1.2
        let d = max(halfH / t, halfW / (t * aspect.get())) * 1.06
        cameraNode.position = v3(0, centreY, d)
    }
}
