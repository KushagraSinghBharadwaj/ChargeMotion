import AppKit
import SceneKit

/// Node hierarchy (every parent is a physical pivot):
///
///   root ── mount (static bracket + pin)
///        └─ pivot1 (swings about the mount pin)
///             ├─ chain links (interlocked, alternating axes)
///             └─ pivot2 (swings about the swivel eyelet)
///                  ├─ eyelet + upper barrel   (do not spin)
///                  └─ spin (yaw about the vertical axis)
///                       ├─ lower barrel + bail ring
///                       └─ tilt (pitch about the coin centre)
///                            └─ coin (lathe body + raised lettering)
final class MedallionRig {
    let root = SCNNode()
    let pivot1 = SCNNode()
    let pivot2 = SCNNode()
    let spin = SCNNode()
    let tilt = SCNNode()
    static let pivot2Y = -1.065          // chain bottom, in pivot1 space
    static let coinCentreY = -1.25       // coin centre, in pivot2/spin space
}

enum MedallionModelBuilder {
    static func build(palette: KoiPalette) -> MedallionRig {
        let m = KoiMaterials(palette: palette)
        let rig = MedallionRig()
        rig.root.name = "medallion.root"

        // ---- Mount: bracket plate + horizontal pin the first link hangs from.
        let mount = SCNNode()
        let plate = SCNBox(width: 0.46, height: 0.16, length: 0.07, chamferRadius: 0.02)
        plate.materials = [m.darkTitanium]
        let pn = SCNNode(geometry: plate)
        pn.position = v3(0, 0.12, 0)
        mount.addChildNode(pn)
        let pin = SCNCylinder(radius: 0.035, height: 0.16)
        pin.materials = [m.polishedGold]
        let pinNode = SCNNode(geometry: pin)
        pinNode.eulerAngles = v3(.pi / 2, 0, 0)               // axis Z
        mount.addChildNode(pinNode)
        for sx in [-0.16, 0.16] {
            let screw = SCNCylinder(radius: 0.022, height: 0.02)
            screw.materials = [m.brushedGold]
            let sn = SCNNode(geometry: screw)
            sn.eulerAngles = v3(.pi / 2, 0, 0)
            sn.position = v3(sx, 0.12, 0.04)
            mount.addChildNode(sn)
        }
        rig.root.addChildNode(mount)
        rig.root.addChildNode(rig.pivot1)

        // ---- Chain: 6 elongated links, alternating Z / X axes so they interlock.
        for i in 0..<6 {
            let torus = SCNTorus(ringRadius: 0.07, pipeRadius: 0.018)
            torus.ringSegmentCount = 24
            torus.pipeSegmentCount = 10
            torus.materials = [m.silver]
            let tn = SCNNode(geometry: torus)
            tn.eulerAngles = i % 2 == 0 ? v3(.pi / 2, 0, 0) : v3(0, 0, .pi / 2)   // axis Z (ring in XY) / axis X (ring in YZ)
            let holder = SCNNode()
            holder.scale = v3(1, 1.5, 1)                                          // elongate vertically
            holder.position = v3(0, -0.07 - 0.17 * Double(i), 0)
            holder.addChildNode(tn)
            rig.pivot1.addChildNode(holder)
        }

        // ---- Swivel: eyelet catches the last link; upper barrel static, lower barrel spins with the coin.
        rig.pivot2.position = v3(0, MedallionRig.pivot2Y, 0)
        rig.pivot1.addChildNode(rig.pivot2)
        let eyelet = SCNTorus(ringRadius: 0.045, pipeRadius: 0.014)
        eyelet.materials = [m.polishedGold]
        let en = SCNNode(geometry: eyelet)
        en.eulerAngles = v3(.pi / 2, 0, 0)
        en.position = v3(0, 0.05, 0)
        rig.pivot2.addChildNode(en)
        let upper = SCNCylinder(radius: 0.045, height: 0.10)
        upper.materials = [m.titanium]
        let un = SCNNode(geometry: upper)
        un.position = v3(0, -0.03, 0)
        rig.pivot2.addChildNode(un)

        rig.pivot2.addChildNode(rig.spin)
        let lower = SCNCylinder(radius: 0.045, height: 0.10)
        lower.materials = [m.titanium]
        let ln = SCNNode(geometry: lower)
        ln.position = v3(0, -0.11, 0)
        rig.spin.addChildNode(ln)
        let collar = SCNTorus(ringRadius: 0.048, pipeRadius: 0.01)
        collar.materials = [m.polishedGold]
        let cn = SCNNode(geometry: collar)
        cn.position = v3(0, -0.06, 0)
        rig.spin.addChildNode(cn)
        let bail = SCNTorus(ringRadius: 0.06, pipeRadius: 0.022)
        bail.materials = [m.polishedGold]
        let bn = SCNNode(geometry: bail)
        bn.eulerAngles = v3(.pi / 2, 0, 0)
        bn.position = v3(0, -0.2, 0)
        rig.spin.addChildNode(bn)

        rig.tilt.position = v3(0, MedallionRig.coinCentreY, 0)
        rig.spin.addChildNode(rig.tilt)
        rig.tilt.addChildNode(makeCoin(m: m))
        return rig
    }

    // MARK: Coin

    private static func makeCoin(m: KoiMaterials) -> SCNNode {
        // Profile in (radius, z): back, bevelled rim, stepped inner field with an engraved groove.
        let prof: [KoiMesh.LathePoint] = [
            .init(r: 0.00, z: -0.07, smooth: false, group: 2),
            .init(r: 0.90, z: -0.07, smooth: false, group: 0),
            .init(r: 0.965, z: -0.055, smooth: true, group: 0),
            .init(r: 1.00, z: -0.02, smooth: true, group: 0),
            .init(r: 1.00, z: 0.055, smooth: false, group: 0),
            .init(r: 0.965, z: 0.09, smooth: true, group: 0),
            .init(r: 0.91, z: 0.10, smooth: true, group: 0),
            .init(r: 0.89, z: 0.085, smooth: false, group: 0),
            .init(r: 0.885, z: 0.045, smooth: false, group: 1),
            .init(r: 0.85, z: 0.045, smooth: false, group: 1),
            .init(r: 0.845, z: 0.034, smooth: false, group: 1),
            .init(r: 0.80, z: 0.034, smooth: false, group: 1),
            .init(r: 0.795, z: 0.045, smooth: false, group: 1),
            .init(r: 0.00, z: 0.045, smooth: false, group: 1),
        ]
        let body = KoiMesh.lathe(profile: prof, segments: 96, groupCount: 3)
        body.materials = [m.polishedGold, m.field, m.field]
        let coin = SCNNode(geometry: body)
        coin.name = "medallion.coin"

        let fieldZ = 0.045
        let font = NSFont(name: "Optima-Bold", size: 10) ?? NSFont.boldSystemFont(ofSize: 10)

        // Front lettering: MADE BY / KUSHAGRA / SINGH / BHARADWAJ (raised 0.03 above the field, below the rim).
        let lines: [(String, Double, Double)] = [("MADE BY", 0.62, 0.50), ("KUSHAGRA", 1.18, 0.25),
                                                  ("SINGH", 0.80, -0.02), ("BHARADWAJ", 1.22, -0.30)]
        for (s, w, y) in lines {
            let t = raisedText(s, width: CGFloat(w), height: 0.030, font: font, material: m.polishedGold)
            t.position = v3(0, y, fieldZ)
            coin.addChildNode(t)
        }
        // Ornaments: rules + diamonds.
        for (y, w) in [(0.385, 0.62), (-0.46, 0.9)] {
            let rule = SCNBox(width: CGFloat(w), height: 0.012, length: 0.022, chamferRadius: 0.004)
            rule.materials = [m.brushedGold]
            let rn = SCNNode(geometry: rule)
            rn.position = v3(0, y, fieldZ + 0.011)
            coin.addChildNode(rn)
            for sx in [-w / 2 - 0.05, w / 2 + 0.05] {
                let d = SCNBox(width: 0.045, height: 0.045, length: 0.024, chamferRadius: 0.006)
                d.materials = [m.polishedGold]
                let dn = SCNNode(geometry: d)
                dn.eulerAngles = v3(0, 0, .pi / 4)
                dn.position = v3(sx, y, fieldZ + 0.012)
                coin.addChildNode(dn)
            }
        }
        // Beaded ring on the step between rim and field (flattened into one mesh).
        let beads = SCNNode()
        let bead = SCNSphere(radius: 0.012)
        bead.segmentCount = 8
        bead.materials = [m.brushedGold]
        for k in 0..<84 {
            let a = 2 * Double.pi * Double(k) / 84
            let n = SCNNode(geometry: bead)
            n.position = v3(0.868 * cos(a), 0.868 * sin(a), fieldZ + 0.004)
            beads.addChildNode(n)
        }
        coin.addChildNode(beads.flattenedClone())

        // Back face: gear emblem + CHARGEMOTION (mirrored so it reads correctly when flipped).
        let back = SCNNode()
        back.eulerAngles = v3(0, .pi, 0)
        back.position = v3(0, 0, -0.07)
        let emblem = KoiMesh.gear(teeth: 16, outerRadius: 0.34, depth: 0.04, tooth: m.polishedGold, hub: m.darkTitanium)
        emblem.position = v3(0, 0.2, 0)
        back.addChildNode(emblem)
        let bt = raisedText("CHARGEMOTION", width: 1.2, height: 0.03, font: font, material: m.polishedGold)
        bt.position = v3(0, -0.36, 0)
        back.addChildNode(bt)
        coin.addChildNode(back)
        return coin
    }

    /// Real extruded 3D text, scaled to a target width, centred, base resting at z = 0.
    private static func raisedText(_ s: String, width: CGFloat, height: CGFloat, font: NSFont, material: SCNMaterial) -> SCNNode {
        let text = SCNText(string: s, extrusionDepth: 1)
        text.font = font
        text.flatness = 0.04
        text.materials = [material]
        let node = SCNNode(geometry: text)
        let (mn0, mx0) = node.boundingBox
        let scale = width / max(0.001, CGFloat(mx0.x - mn0.x))
        text.extrusionDepth = height / scale
        text.chamferRadius = 0.0045 / scale
        node.scale = SCNVector3(scale, scale, scale)
        let (mn, mx) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z)
        return node
    }
}
