import AppKit
import SceneKit
import simd

/// Procedural geometry. Everything here is real indexed triangle geometry
/// (no images, no 2D shapes standing in for 3D).
enum KoiMesh {

    // MARK: Raw geometry assembly

    static func make(positions: [SIMD3<Float>], normals: [SIMD3<Float>], uvs: [SIMD2<Float>], elements: [[UInt32]]) -> SCNGeometry {
        let n = positions.count
        let vData = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let nData = normals.withUnsafeBufferPointer { Data(buffer: $0) }
        let tData = uvs.withUnsafeBufferPointer { Data(buffer: $0) }
        let vSrc = SCNGeometrySource(data: vData, semantic: .vertex, vectorCount: n, usesFloatComponents: true,
                                     componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
                                     dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let nSrc = SCNGeometrySource(data: nData, semantic: .normal, vectorCount: n, usesFloatComponents: true,
                                     componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
                                     dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let tSrc = SCNGeometrySource(data: tData, semantic: .texcoord, vectorCount: n, usesFloatComponents: true,
                                     componentsPerVector: 2, bytesPerComponent: MemoryLayout<Float>.size,
                                     dataOffset: 0, dataStride: MemoryLayout<SIMD2<Float>>.stride)
        let els = elements.map { SCNGeometryElement(indices: $0, primitiveType: .triangles) }
        return SCNGeometry(sources: [vSrc, nSrc, tSrc], elements: els)
    }

    // MARK: Loft (koi body segments)

    struct LoftRing { var x: Float; var hw: Float; var hh: Float }

    /// Lofts elliptical rings placed along -X (head at +X). One smooth-shaded plate.
    static func loft(rings: [LoftRing], radial: Int, uRepeat: Float, vStart: Float, vEnd: Float) -> SCNGeometry {
        let cols = radial + 1
        var pos = [SIMD3<Float>](), uv = [SIMD2<Float>]()
        for (ri, r) in rings.enumerated() {
            let v = vStart + (vEnd - vStart) * Float(ri) / Float(max(1, rings.count - 1))
            for k in 0...radial {
                let a = 2 * Float.pi * Float(k) / Float(radial)
                pos.append(SIMD3(r.x, r.hh * cos(a), r.hw * sin(a)))
                uv.append(SIMD2(uRepeat * Float(k) / Float(radial), v))
            }
        }
        var idx = [UInt32]()
        for ri in 0..<(rings.count - 1) {
            for k in 0..<radial {
                let a = UInt32(ri * cols + k), b = a + 1, c = a + UInt32(cols), d = c + 1
                idx += [a, c, b, b, c, d]            // CCW seen from outside (rings step toward -X)
            }
        }
        var nrm = [SIMD3<Float>](repeating: .zero, count: pos.count)
        for t in stride(from: 0, to: idx.count, by: 3) {
            let i0 = Int(idx[t]), i1 = Int(idx[t + 1]), i2 = Int(idx[t + 2])
            let n = simd_cross(pos[i1] - pos[i0], pos[i2] - pos[i0])      // area weighted
            nrm[i0] += n; nrm[i1] += n; nrm[i2] += n
        }
        for ri in 0..<rings.count {                  // close the UV seam smoothly
            let a = ri * cols, b = a + radial
            let s = nrm[a] + nrm[b]
            nrm[a] = s; nrm[b] = s
        }
        for i in 0..<nrm.count {
            let l = simd_length(nrm[i])
            nrm[i] = l > 1e-8 ? nrm[i] / l : SIMD3(1, 0, 0)
        }
        return make(positions: pos, normals: nrm, uvs: uv, elements: [idx])
    }

    // MARK: Lathe (medallion body: real bevels, steps and grooves)

    struct LathePoint {
        var r: Float
        var z: Float
        var smooth: Bool = false      // blend normals with the previous segment
        var group: Int = 0            // material slot of the segment STARTING at this point
    }

    /// Revolves an (r, z) profile around Z. Hard edges stay crisp, `smooth` points are blended.
    static func lathe(profile p: [LathePoint], segments: Int, groupCount: Int) -> SCNGeometry {
        func segNormal(_ i: Int) -> SIMD2<Float> {
            let dr = p[i + 1].r - p[i].r, dz = p[i + 1].z - p[i].z
            let l = (dr * dr + dz * dz).squareRoot()
            return l > 1e-8 ? SIMD2(dz / l, -dr / l) : SIMD2(0, 1)
        }
        let rMax = p.map { $0.r }.max() ?? 1
        var pos = [SIMD3<Float>](), nrm = [SIMD3<Float>](), uv = [SIMD2<Float>]()
        var groups = [[UInt32]](repeating: [], count: groupCount)
        for i in 0..<(p.count - 1) {
            var n0 = segNormal(i), n1 = segNormal(i)
            if p[i].smooth && i > 0 { let s = n0 + segNormal(i - 1); n0 = simd_normalize(s) }
            if p[i + 1].smooth && i + 2 < p.count { let s = n1 + segNormal(i + 1); n1 = simd_normalize(s) }
            let base = UInt32(pos.count)
            for k in 0...segments {
                let th = 2 * Float.pi * Float(k) / Float(segments)
                let c = cos(th), s = sin(th)
                for (pt, n) in [(p[i], n0), (p[i + 1], n1)] {
                    pos.append(SIMD3(pt.r * c, pt.r * s, pt.z))
                    nrm.append(simd_normalize(SIMD3(n.x * c, n.x * s, n.y)))
                    uv.append(SIMD2(0.5 + 0.5 * pt.r * c / rMax, 0.5 + 0.5 * pt.r * s / rMax))
                }
            }
            for k in 0..<segments {
                let a = base + UInt32(k * 2), b = a + 2, c = a + 1, d = a + 3   // a,b ring0 (k,k+1); c,d ring1
                groups[min(p[i].group, groupCount - 1)] += [a, b, c, b, d, c]
            }
        }
        return make(positions: pos, normals: nrm, uvs: uv, elements: groups)
    }

    // MARK: Gear

    /// Extruded gear with a hub. Axis = Z.
    static func gear(teeth: Int, outerRadius ro: CGFloat, depth: CGFloat, tooth: SCNMaterial, hub: SCNMaterial) -> SCNNode {
        let ri = ro * 0.82, step = 2 * CGFloat.pi / CGFloat(teeth)
        let path = NSBezierPath()
        for i in 0..<teeth {
            let a = CGFloat(i) * step
            let pts: [(CGFloat, CGFloat)] = [(a, ri), (a + step * 0.12, ro), (a + step * 0.38, ro), (a + step * 0.5, ri)]
            for (j, q) in pts.enumerated() {
                let pt = NSPoint(x: cos(q.0) * q.1, y: sin(q.0) * q.1)
                if i == 0 && j == 0 { path.move(to: pt) } else { path.line(to: pt) }
            }
        }
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: depth)
        shape.chamferRadius = depth * 0.15
        shape.materials = [tooth]
        let node = SCNNode(geometry: shape)
        let cap = SCNCylinder(radius: ro * 0.3, height: depth * 1.5)
        cap.radialSegmentCount = 16
        cap.materials = [hub]
        let capNode = SCNNode(geometry: cap)
        capNode.eulerAngles = v3(.pi / 2, 0, 0)
        node.addChildNode(capNode)
        return node
    }

    // MARK: Articulated fin plate

    /// Tapered fin-ray plate with a pointed tip, lying in the XY plane, extruded along Z.
    static func blade(length l: CGFloat, w0: CGFloat, w1: CGFloat, thickness t: CGFloat) -> SCNGeometry {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: -w0 / 2))
        path.line(to: NSPoint(x: l * 0.9, y: -w1 / 2))
        path.line(to: NSPoint(x: l, y: -w1 * 0.2))
        path.line(to: NSPoint(x: l, y: w1 * 0.2))
        path.line(to: NSPoint(x: l * 0.9, y: w1 / 2))
        path.line(to: NSPoint(x: 0, y: w0 / 2))
        path.close()
        let s = SCNShape(path: path, extrusionDepth: t)
        s.chamferRadius = t * 0.22
        return s
    }
}
