import AppKit
import SceneKit

/// Owns the koi SCNScene: model, lighting, shadow-catcher floor, camera rig, and the per-frame
/// update (`renderer(_:updateAtTime:)`) that runs animation + camera. One scene is built once per view.
public final class MechanicalKoiScene: NSObject, SCNSceneRendererDelegate {
    public let scene = SCNScene()
    let interaction = KoiInteractionController()
    let cameraNode = SCNNode()

    private let rig: KoiRig
    private let animator: KoiAnimationController
    private let targetNode = SCNNode()
    private let keyLight = SCNNode()
    private let fillLight = SCNNode()
    private let floorMaterial = SCNMaterial()
    private let lastTime = Atomic(0.0)
    private let reducedMotion = Atomic(false)
    private let aspect = Atomic(1.6)
    private let fov: Double = 32

    public init(palette: KoiPalette = KoiPalette(), quality: KoiRenderQuality = .balanced) {
        rig = KoiModelBuilder.build(palette: palette)
        animator = KoiAnimationController(rig: rig)
        super.init()

        // Transparent background so the SwiftUI card shows through.
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = KoiTextures.studioEnvironment()
        scene.lightingEnvironment.intensity = 1.3

        let koiRoot = SCNNode()
        koiRoot.name = "koi.root"
        koiRoot.position = v3(0.55, 0, 0)               // centres body + tail on the orbit target
        koiRoot.addChildNode(rig.swimmer)
        scene.rootNode.addChildNode(koiRoot)

        // Key light (casts the soft shadow), cool fill, warm rim.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1100
        key.temperature = 5600
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowMapSize = CGSize(width: quality.shadowMapSize, height: quality.shadowMapSize)
        key.shadowSampleCount = quality.shadowSamples
        key.shadowRadius = 7
        key.shadowColor = NSColor(white: 0, alpha: 0.55)
        key.maximumShadowDistance = 14
        key.automaticallyAdjustsShadowProjection = true
        keyLight.light = key
        keyLight.eulerAngles = v3(-0.95, 0.55, 0)
        scene.rootNode.addChildNode(keyLight)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 260
        fill.color = NSColor(srgbRed: 0.7, green: 0.8, blue: 1.0, alpha: 1)
        fillLight.light = fill
        fillLight.position = v3(-4, 1.5, 4)
        scene.rootNode.addChildNode(fillLight)

        let rim = SCNLight()
        rim.type = .omni
        rim.intensity = 520
        rim.color = NSColor(srgbRed: 1.0, green: 0.78, blue: 0.5, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = v3(3, 2.5, -4)
        scene.rootNode.addChildNode(rimNode)

        // Shadow catcher: draws only the koi's shadow, nothing else.
        let floor = SCNFloor()
        floor.reflectivity = 0
        floorMaterial.lightingModel = .shadowOnly
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = v3(0, -1.35, 0)
        scene.rootNode.addChildNode(floorNode)

        // Camera orbits `targetNode`; a look-at constraint keeps it centred.
        let cam = SCNCamera()
        cam.fieldOfView = CGFloat(fov)
        cam.zNear = 0.1
        cam.zFar = 60
        cameraNode.camera = cam
        let look = SCNLookAtConstraint(target: targetNode)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        scene.rootNode.addChildNode(targetNode)
        scene.rootNode.addChildNode(cameraNode)
        applyPose(.init(yaw: KoiInteractionController.defaultYaw, pitch: KoiInteractionController.defaultPitch, zoom: 1, energy: 1))
        applyAppearance(isDark: true)
    }

    // MARK: Main-thread API

    func updateViewport(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        aspect.set(Double(size.width / size.height))
    }
    func setReducedMotion(_ on: Bool) { reducedMotion.set(on) }
    func resetClock() { lastTime.set(0) }                 // avoids a big dt after a pause

    func applyAppearance(isDark: Bool) {
        scene.lightingEnvironment.intensity = isDark ? 1.3 : 1.6
        keyLight.light?.intensity = isDark ? 1100 : 1300
        keyLight.light?.shadowColor = NSColor(white: 0, alpha: isDark ? 0.55 : 0.32)
    }

    /// Releases GPU/scene resources. Safe to call more than once.
    func tearDown() {
        scene.rootNode.enumerateHierarchy { node, _ in
            node.removeAllActions()
            node.geometry = nil
            node.light = nil
            node.camera = nil
            node.constraints = nil
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
        let reduce = reducedMotion.get()
        let pose = interaction.step(dt: dt, reduceMotion: reduce)
        animator.update(dt: dt, energy: pose.energy, motion: reduce ? 0.35 : 1.0)
        applyPose(pose)
    }

    /// Distance that keeps the whole fish (incl. swinging tail) in frame at any window aspect.
    private func fitDistance() -> Double {
        let t = tan(fov * .pi / 360)
        let halfH = 1.0, halfW = 2.5
        return max(halfH / t, halfW / (t * aspect.get())) * 1.08
    }

    private func applyPose(_ p: KoiInteractionController.Pose) {
        let d = fitDistance() / p.zoom
        let cp = cos(p.pitch)
        cameraNode.position = v3(d * cp * sin(p.yaw), d * sin(p.pitch), d * cp * cos(p.yaw))
    }
}
