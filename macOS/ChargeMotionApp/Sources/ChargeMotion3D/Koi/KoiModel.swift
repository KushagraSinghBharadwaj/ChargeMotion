import AppKit
import SceneKit

/// Body proportions. The fish lies along X (head at +X), Y is up, Z is the fish's width.
enum KoiProportions {
    static let length = 3.0
    /// Normalised spine positions (0 = nose, 1 = tail stock) where body plates are cut.
    static let segmentBounds: [Double] = [0, 0.20, 0.34, 0.47, 0.60, 0.72, 0.84, 1.0]

    /// 0...1 thickness envelope: blunt rounded nose, fat shoulders, slim tail stock.
    static func env(_ t: Double) -> Double {
        if t < 0.32 { return pow(sin(t / 0.32 * .pi / 2), 0.6) }
        let s = (t - 0.32) / 0.68
        return 0.84 * pow(1 - s, 0.8) + 0.16
    }
    static func halfWidth(_ t: Double) -> Double { 0.40 * env(t) }
    static func halfHeight(_ t: Double) -> Double { 0.36 * env(t) }
    static func x(_ t: Double) -> Double { length * (0.5 - t) }
}

/// One articulated fin: optional flap hinge + rays, each ray a chain of hinged plates.
final class KoiFinRig {
    let flap: SCNNode?
    let rays: [[SCNNode]]
    let side: Double
    init(flap: SCNNode?, rays: [[SCNNode]], side: Double) { self.flap = flap; self.rays = rays; self.side = side }
}

/// Every node the animation controller drives (pivots live at the joints).
final class KoiRig {
    let swimmer: SCNNode
    var segments: [SCNNode] = []
    var peduncle = SCNNode()
    var tailRays: [[SCNNode]] = []
    var pectoral: [KoiFinRig] = []
    var pelvic: [KoiFinRig] = []
    var dorsal: KoiFinRig?
    var anal: KoiFinRig?
    var barbels: [[SCNNode]] = []
    var gears: [(node: SCNNode, ratio: Double, phase: Double)] = []
    var glow: SCNMaterial?
    init(swimmer: SCNNode) { self.swimmer = swimmer }
}

enum KoiModelBuilder {
    typealias P = KoiProportions

    static func build(palette: KoiPalette) -> KoiRig {
        let m = KoiMaterials(palette: palette)
        let swimmer = SCNNode()
        swimmer.name = "koi.swimmer"
        let rig = KoiRig(swimmer: swimmer)
        rig.glow = m.glow

        let b = P.segmentBounds
        let bodyMats = [m.scaledGold, m.scaledChampagne, m.scaledSilver]
        var parent = swimmer

        // ---- Body: chain of articulated armour plates, each rotating about its front joint.
        for i in 0..<(b.count - 1) {
            let t0 = b[i], t1 = b[i + 1], tm = (t0 + t1) / 2
            let segLen = P.x(t0) - P.x(t1)
            let node = SCNNode()
            node.name = "koi.segment.\(i)"
            node.position = i == 0 ? v3(P.x(0), 0, 0) : v3(-(P.x(b[i - 1]) - P.x(t0)), 0, 0)
            parent.addChildNode(node)
            parent = node
            rig.segments.append(node)

            let rings: [KoiMesh.LoftRing] = (0..<7).map { r in
                let u = Double(r) / 6, t = t0 + (t1 - t0) * u
                let bulge = 1 + 0.05 * sin(Double.pi * u)              // each plate domes between seams
                return KoiMesh.LoftRing(x: Float(P.x(t) - P.x(t0)), hw: Float(P.halfWidth(t) * bulge), hh: Float(P.halfHeight(t) * bulge))
            }
            let geo = KoiMesh.loft(rings: rings, radial: 28, uRepeat: 2.6,
                                   vStart: Float(t0 * P.length / 0.9), vEnd: Float(t1 * P.length / 0.9))
            geo.materials = [bodyMats[i % 3]]
            node.addChildNode(SCNNode(geometry: geo))

            if i > 0 {   // dark ball joint hides the gap when the plate yaws, amber seam ring glows in the groove
                let hw = P.halfWidth(t0), hh = P.halfHeight(t0)
                let ball = SCNSphere(radius: CGFloat(min(hw, hh) * 0.92))
                ball.segmentCount = 20
                ball.materials = [m.darkTitanium]
                node.addChildNode(SCNNode(geometry: ball))
                let ring = SCNTorus(ringRadius: CGFloat(hw * 0.985), pipeRadius: 0.013)
                ring.ringSegmentCount = 40
                ring.pipeSegmentCount = 8
                ring.materials = [m.glow]
                let ringNode = SCNNode(geometry: ring)
                ringNode.eulerAngles = v3(0, 0, .pi / 2)                // torus axis Y -> X
                let holder = SCNNode()
                holder.scale = v3(1, hh / hw, 1)                         // circle -> body ellipse
                holder.addChildNode(ringNode)
                node.addChildNode(holder)
            }

            // Dorsal armour strip (koi "hi" pattern: vermilion on alternate plates).
            let plate = SCNBox(width: CGFloat(segLen * 0.62), height: 0.034, length: CGFloat(P.halfWidth(tm) * 0.42), chamferRadius: 0.012)
            plate.materials = [i % 2 == 1 ? m.vermilion : m.polishedGold]
            let pn = SCNNode(geometry: plate)
            pn.position = v3(P.x(tm) - P.x(t0), P.halfHeight(tm) * 1.045, 0)
            node.addChildNode(pn)
        }

        // ---- Head details (rigidly on the head plates).
        let head = rig.segments[0], gillSeg = rig.segments[1]
        for side in [1.0, -1.0] {
            head.addChildNode(makeEye(side: side, m: m))
            gillSeg.addChildNode(makeGill(side: side, m: m))
            let bar = makeBarbel(side: side, m: m)
            head.addChildNode(bar.root)
            rig.barbels.append(bar.joints)
        }

        // ---- Exposed gear trains (internal mechanism visible through side windows).
        for (segIdx, size) in [(2, 1.0), (4, 0.85)] {
            for side in [1.0, -1.0] {
                addGears(to: rig.segments[segIdx], segIndex: segIdx, side: side, scale: size, m: m, rig: rig)
            }
        }

        // ---- Fins.
        // Dorsal (vertical fan on seg 2).
        let dorsalFan = makeFan(rayCount: 7, spread: 1.0, center: .pi / 2 + 0.45, length: { 0.82 - 0.085 * Double($0) },
                                segments: 3, baseRadius: 0.04, thickness: 0.012, mats: [m.polishedGold, m.vermilion], pin: m.darkTitanium)
        let d0 = b[2], dm = 0.40
        dorsalFan.node.position = v3(P.x(dm) - P.x(d0), P.halfHeight(dm) * 0.98, 0)
        rig.segments[2].addChildNode(dorsalFan.node)
        rig.dorsal = KoiFinRig(flap: nil, rays: dorsalFan.rays, side: 1)

        // Anal fin (vertical fan hanging from seg 5).
        let analFan = makeFan(rayCount: 5, spread: 0.7, center: -.pi / 2 - 0.45, length: { 0.52 - 0.04 * abs(Double($0) - 2) },
                              segments: 3, baseRadius: 0.03, thickness: 0.010, mats: [m.silver, m.vermilion], pin: m.darkTitanium)
        let a0 = b[5], am = 0.78
        analFan.node.position = v3(P.x(am) - P.x(a0), -P.halfHeight(am) * 0.9, 0)
        rig.segments[5].addChildNode(analFan.node)
        rig.anal = KoiFinRig(flap: nil, rays: analFan.rays, side: 1)

        // Pectoral + pelvic (horizontal fans on a flap hinge).
        for side in [1.0, -1.0] {
            let pec = makeSideFin(side: side, rays: 6, spread: 0.95, tilt: 0.75, base: 0.04, len: { 0.62 - 0.05 * abs(Double($0) - 2.5) },
                                  mats: [m.silver, m.polishedGold], m: m)
            let tp = 0.27
            pec.root.position = v3(P.x(tp) - P.x(b[1]), -P.halfHeight(tp) * 0.45, side * P.halfWidth(tp) * 0.9)
            rig.segments[1].addChildNode(pec.root)
            rig.pectoral.append(pec.rig)

            let pel = makeSideFin(side: side, rays: 5, spread: 0.8, tilt: 0.5, base: 0.03, len: { 0.40 - 0.03 * abs(Double($0) - 2) },
                                  mats: [m.silver, m.vermilion], m: m)
            let tq = 0.53
            pel.root.position = v3(P.x(tq) - P.x(b[3]), -P.halfHeight(tq) * 0.86, side * 0.13)
            rig.segments[3].addChildNode(pel.root)
            rig.pelvic.append(pel.rig)
        }

        // Caudal (tail) fan: wide articulated fan with 4 hinges per ray.
        let last = rig.segments[b.count - 2]
        let ped = rig.peduncle
        ped.position = v3(-(P.x(b[b.count - 2]) - P.x(1.0)), 0, 0)
        last.addChildNode(ped)
        let hub = SCNSphere(radius: 0.075)
        hub.materials = [m.darkTitanium]
        ped.addChildNode(SCNNode(geometry: hub))
        let tail = makeFan(rayCount: 9, spread: 1.75, center: .pi,
                           length: { 0.72 + 0.46 * cos((Double($0) - 4) / 4 * .pi / 2) },
                           segments: 4, baseRadius: 0.09, thickness: 0.012,
                           mats: [m.polishedGold, m.vermilion], pin: m.darkTitanium)
        ped.addChildNode(tail.node)
        rig.tailRays = tail.rays

        return rig
    }

    // MARK: Head parts

    private static func makeEye(side: Double, m: KoiMaterials) -> SCNNode {
        let eye = SCNNode()
        let te = 0.11
        eye.position = v3(P.x(te) - P.x(0), P.halfHeight(te) * 0.32, side * P.halfWidth(te) * 0.93)
        eye.eulerAngles = v3(0, side > 0 ? 0.3 : .pi - 0.3, 0)          // faces outward, slightly forward
        let ball = SCNSphere(radius: 0.074)
        ball.segmentCount = 24
        ball.materials = [m.blackGlass]
        eye.addChildNode(SCNNode(geometry: ball))
        let bezel = SCNTorus(ringRadius: 0.078, pipeRadius: 0.014)
        bezel.materials = [m.polishedGold]
        let bn = SCNNode(geometry: bezel)
        bn.eulerAngles = v3(.pi / 2, 0, 0)
        bn.position = v3(0, 0, 0.05)
        eye.addChildNode(bn)
        let iris = SCNCylinder(radius: 0.052, height: 0.008)
        iris.materials = [m.glow]
        let irisNode = SCNNode(geometry: iris)
        irisNode.eulerAngles = v3(.pi / 2, 0, 0)
        irisNode.position = v3(0, 0, 0.066)
        eye.addChildNode(irisNode)
        let pupil = SCNCylinder(radius: 0.022, height: 0.008)
        pupil.materials = [m.blackGlass]
        let pn = SCNNode(geometry: pupil)
        pn.eulerAngles = v3(.pi / 2, 0, 0)
        pn.position = v3(0, 0, 0.071)
        eye.addChildNode(pn)
        return eye
    }

    private static func makeGill(side: Double, m: KoiMaterials) -> SCNNode {
        let s = SCNSphere(radius: 0.5)
        s.segmentCount = 20
        s.materials = [m.titanium]
        let n = SCNNode(geometry: s)
        let tg = 0.245
        n.scale = v3(0.30, 0.46, 0.07)
        n.position = v3(P.x(tg) - P.x(P.segmentBounds[1]), -P.halfHeight(tg) * 0.1, side * P.halfWidth(tg) * 0.94)
        let rim = SCNTorus(ringRadius: 0.5, pipeRadius: 0.035)
        rim.materials = [m.polishedGold]
        let rn = SCNNode(geometry: rim)
        rn.eulerAngles = v3(.pi / 2, 0, 0)
        n.addChildNode(rn)
        return n
    }

    private static func makeBarbel(side: Double, m: KoiMaterials) -> (root: SCNNode, joints: [SCNNode]) {
        let root = SCNNode()
        root.position = v3(-0.12, -0.07, side * 0.10)
        root.eulerAngles = v3(0, -side * 0.5, 0)
        var parent = root
        var joints: [SCNNode] = []
        for j in 0..<3 {
            let joint = SCNNode()
            joint.position = v3(j == 0 ? 0 : 0.075, 0, 0)
            parent.addChildNode(joint)
            let cap = SCNCapsule(capRadius: 0.011, height: 0.09)
            cap.materials = [m.polishedGold]
            let cn = SCNNode(geometry: cap)
            cn.eulerAngles = v3(0, 0, -.pi / 2)                          // capsule axis Y -> +X
            cn.position = v3(0.04, 0, 0)
            joint.addChildNode(cn)
            let bead = SCNSphere(radius: 0.016)
            bead.segmentCount = 10
            bead.materials = [m.darkTitanium]
            joint.addChildNode(SCNNode(geometry: bead))
            joints.append(joint)
            parent = joint
        }
        return (root, joints)
    }

    // MARK: Gears

    private static func addGears(to seg: SCNNode, segIndex: Int, side: Double, scale: Double, m: KoiMaterials, rig: KoiRig) {
        let t0 = P.segmentBounds[segIndex], t1 = P.segmentBounds[segIndex + 1]
        let tg = t0 + (t1 - t0) * 0.35
        let xl = P.x(tg) - P.x(t0)
        let z = side * P.halfWidth(tg) * 0.965
        let housing = SCNCylinder(radius: CGFloat(0.125 * scale), height: 0.03)
        housing.materials = [m.darkTitanium]
        let hn = SCNNode(geometry: housing)
        hn.eulerAngles = v3(.pi / 2, 0, 0)
        hn.position = v3(xl - 0.07 * scale, 0, z)
        seg.addChildNode(hn)

        let big = KoiMesh.gear(teeth: 12, outerRadius: CGFloat(0.10 * scale), depth: 0.035, tooth: m.polishedGold, hub: m.darkTitanium)
        big.position = v3(xl - 0.04 * scale, 0, z + side * 0.02)
        let small = KoiMesh.gear(teeth: 8, outerRadius: CGFloat(0.066 * scale), depth: 0.035, tooth: m.silver, hub: m.darkTitanium)
        small.position = v3(xl - 0.04 * scale - 0.166 * scale, -0.01, z + side * 0.02)
        seg.addChildNode(big)
        seg.addChildNode(small)
        rig.gears.append((big, side, 0))                                  // mirrored per side so both read as meshing
        rig.gears.append((small, -side * 1.5, .pi / 8))                   // counter-rotates at 12:8 ratio
    }

    // MARK: Fans of hinged plates

    /// A fan of rays; each ray is a chain of plates hinged on Y-axis pins so it can bend out of the fan plane.
    private static func makeFan(rayCount: Int, spread: Double, center: Double, length: (Int) -> Double, segments: Int,
                                baseRadius: Double, thickness: Double, mats: [SCNMaterial], pin: SCNMaterial)
        -> (node: SCNNode, rays: [[SCNNode]]) {
        let fan = SCNNode()
        var rays: [[SCNNode]] = []
        let dphi = rayCount > 1 ? spread / Double(rayCount - 1) : spread
        let pinGeo = SCNCylinder(radius: 0.011, height: 1)
        pinGeo.radialSegmentCount = 10
        pinGeo.materials = [pin]

        for i in 0..<rayCount {
            let phi = center - spread / 2 + dphi * Double(i)
            let rayRoot = SCNNode()
            rayRoot.eulerAngles = v3(0, 0, phi)
            rayRoot.position = v3(0, 0, i % 2 == 0 ? 0 : thickness * 1.2)       // alternate layers = overlapping fan
            fan.addChildNode(rayRoot)

            let total = length(i), segLen = total / Double(segments)
            var r0 = baseRadius
            var parentNode = rayRoot
            var chain: [SCNNode] = []
            for j in 0..<segments {
                let r1 = r0 + segLen
                let w0 = min(0.24, max(0.02, r0 * dphi * 0.94)), w1 = min(0.24, max(0.022, r1 * dphi * 0.94))
                let seg = SCNNode()
                seg.position = v3(j == 0 ? baseRadius : segLen, 0, 0)
                parentNode.addChildNode(seg)
                let blade = KoiMesh.blade(length: CGFloat(segLen), w0: CGFloat(w0), w1: CGFloat(w1), thickness: CGFloat(thickness))
                blade.materials = [mats[i % mats.count]]
                seg.addChildNode(SCNNode(geometry: blade))
                let pn = SCNNode(geometry: pinGeo)
                pn.scale = v3(1, w0 * 1.02, 1)
                pn.position = v3(0, 0, thickness * 0.5)
                seg.addChildNode(pn)
                chain.append(seg)
                parentNode = seg
                r0 = r1
            }
            rays.append(chain)
        }
        let hub = SCNCylinder(radius: 0.035, height: 0.05)
        hub.radialSegmentCount = 14
        hub.materials = [pin]
        let hn = SCNNode(geometry: hub)
        hn.eulerAngles = v3(.pi / 2, 0, 0)
        fan.addChildNode(hn)
        return (fan, rays)
    }

    /// Pectoral/pelvic fin: horizontal fan on a flap hinge that runs fore-aft (world X).
    private static func makeSideFin(side: Double, rays: Int, spread: Double, tilt: Double, base: Double,
                                    len: (Int) -> Double, mats: [SCNMaterial], m: KoiMaterials)
        -> (root: SCNNode, rig: KoiFinRig) {
        let root = SCNNode()
        let flap = SCNNode()
        root.addChildNode(flap)
        let plane = SCNNode()
        plane.eulerAngles = v3(-.pi / 2, 0, 0)          // fan XY plane -> world XZ (horizontal)
        flap.addChildNode(plane)
        let fan = makeFan(rayCount: rays, spread: spread, center: .pi + side * tilt, length: len, segments: 3,
                          baseRadius: base, thickness: 0.010, mats: mats, pin: m.darkTitanium)
        plane.addChildNode(fan.node)
        return (root, KoiFinRig(flap: flap, rays: fan.rays, side: side))
    }
}
