import AppKit
import SceneKit

// MARK: - Animation

/// Drives the koi rig procedurally every frame (no SCNAction timers, no extra threads).
///
/// Swimming = a travelling sine wave down the spine: each body plate yaws about its own joint
/// with increasing amplitude and a fixed phase lag toward the tail, so the body undulates as an
/// articulated chain rather than rotating as a rigid object. The tail rays continue the wave and
/// bend out of plane with a further per-hinge lag. Fins flap/ripple on their own slower phase.
final class KoiAnimationController {
    private let rig: KoiRig
    private var phase = 0.0
    private var clock = 0.0
    private var gearAngle = 0.0
    private let lag = 0.72

    init(rig: KoiRig) { self.rig = rig }

    /// - Parameters: `energy` scales tail-beat speed (click burst), `motion` scales amplitude (Reduce Motion).
    func update(dt: Double, energy: Double, motion: Double) {
        clock += dt
        phase += dt * 2 * .pi * 0.62 * energy
        gearAngle += dt * 0.9 * energy

        let n = rig.segments.count
        for (i, seg) in rig.segments.enumerated() {
            let f = Double(i + 1) / Double(n)
            let amp = (0.018 + 0.085 * f * f) * motion
            seg.eulerAngles.y = CGFloat(amp * sin(phase - Double(i) * lag))
        }
        let tailPhase = phase - Double(n) * lag
        rig.peduncle.eulerAngles.y = CGFloat(0.12 * motion * sin(tailPhase - 0.2))
        let tc = max(1, rig.tailRays.count - 1)
        for (i, ray) in rig.tailRays.enumerated() {
            let c = Double(i) / Double(tc) * 2 - 1
            for (j, seg) in ray.enumerated() {
                let a = (0.10 + 0.075 * Double(j)) * (1 - 0.25 * abs(c)) * motion
                seg.eulerAngles.y = CGFloat(a * sin(tailPhase - 0.55 - 0.5 * Double(j)))
            }
        }

        for fin in rig.pectoral {
            let flap = 0.30 * sin(phase * 0.5 + (fin.side > 0 ? 0 : .pi * 0.5)) - 0.10
            fin.flap?.eulerAngles.x = CGFloat(-fin.side * flap * motion)
            ripple(fin, phase: phase * 0.5, amp: 0.10 * motion, lag: 0.5)
        }
        for fin in rig.pelvic {
            let flap = 0.22 * sin(phase * 0.5 + 1.2 + (fin.side > 0 ? 0 : .pi * 0.5)) - 0.12
            fin.flap?.eulerAngles.x = CGFloat(-fin.side * flap * motion)
            ripple(fin, phase: phase * 0.5 + 1.2, amp: 0.08 * motion, lag: 0.5)
        }
        if let d = rig.dorsal { ripple(d, phase: phase - 2 * lag, amp: 0.09 * motion, lag: 0.35) }
        if let a = rig.anal { ripple(a, phase: phase - 5 * lag, amp: 0.09 * motion, lag: 0.35) }

        for (k, chain) in rig.barbels.enumerated() {
            for (j, joint) in chain.enumerated() {
                let off = Double(k) * 1.3
                joint.eulerAngles.y = CGFloat(0.28 * motion * sin(clock * 1.9 + Double(j) * 0.7 + off))
                joint.eulerAngles.z = CGFloat(0.12 * motion * sin(clock * 1.3 + Double(j) * 0.5 + off))
            }
        }

        for g in rig.gears { g.node.eulerAngles.z = CGFloat(g.phase + gearAngle * g.ratio) }

        // Whole-body drift: gentle bob, roll about the swim axis, slight nose pitch.
        rig.swimmer.position.y = CGFloat(0.045 * motion * sin(clock * 0.55))
        rig.swimmer.eulerAngles = v3(0.035 * motion * sin(clock * 0.37 + 0.7), 0, 0.028 * motion * sin(clock * 0.5 + 1.0))

        rig.glow?.emission.intensity = CGFloat(1.0 + 0.3 * sin(clock * 1.8))
    }

    private func ripple(_ fin: KoiFinRig, phase: Double, amp: Double, lag: Double) {
        for ray in fin.rays {
            for (j, seg) in ray.enumerated() {
                seg.eulerAngles.y = CGFloat(amp * Double(j + 1) / 2 * sin(phase - lag * Double(j)))
            }
        }
    }
}

// MARK: - Interaction

/// Orbit / zoom state. Input events (main thread) and the frame step (render thread) share it
/// through a lock. The user's input never stops the swim animation: it only moves the camera.
/// After a pause the view drifts again (turntable) and pitch eases back to its default.
final class KoiInteractionController {
    struct Pose { var yaw: Double; var pitch: Double; var zoom: Double; var energy: Double }

    static let defaultYaw = 0.45
    static let defaultPitch = 0.20

    private struct State {
        var yaw = KoiInteractionController.defaultYaw
        var pitch = KoiInteractionController.defaultPitch
        var zoom = 1.0
        var zoomTarget = 1.0
        var yawVel = 0.0
        var dragging = false
        var pendingYaw = 0.0
        var pendingPitch = 0.0
        var clock = 0.0
        var lastInteraction = -100.0
        var burstUntil = -1.0
        var resetting = false
    }
    private let state = Atomic(State())

    // Main-thread API
    func beginDrag() { state.mutate { $0.dragging = true; $0.yawVel = 0; $0.resetting = false; $0.lastInteraction = $0.clock } }
    func endDrag() { state.mutate { $0.dragging = false; $0.lastInteraction = $0.clock } }
    func drag(dx: Double, dy: Double) {
        state.mutate { $0.pendingYaw += -dx * 0.0075; $0.pendingPitch += dy * 0.006; $0.lastInteraction = $0.clock }
    }
    func zoom(multiplyBy f: Double) {
        state.mutate { $0.zoomTarget = KoiMath.clamp($0.zoomTarget * f, 0.5, 2.4); $0.lastInteraction = $0.clock }
    }
    func nudge(yaw: Double, pitch: Double) {
        state.mutate { $0.pendingYaw += yaw; $0.pendingPitch += pitch; $0.lastInteraction = $0.clock }
    }
    func resetView() { state.mutate { $0.resetting = true; $0.zoomTarget = 1; $0.yawVel = 0; $0.lastInteraction = $0.clock } }
    func pulse() { state.mutate { $0.burstUntil = $0.clock + 1.6 } }

    // Render-thread step
    func step(dt: Double, reduceMotion: Bool) -> Pose {
        state.mutate { s in
            s.clock += dt
            if s.pendingYaw != 0 || s.pendingPitch != 0 {
                s.yaw += s.pendingYaw
                s.pitch += s.pendingPitch
                if dt > 0 { s.yawVel = KoiMath.damp(s.yawVel, to: s.pendingYaw / dt, rate: 30, dt: dt) }
                s.pendingYaw = 0; s.pendingPitch = 0
                s.resetting = false
            } else if !s.dragging {
                s.yaw += s.yawVel * dt
                s.yawVel *= exp(-2.8 * dt)
            }
            let idle = s.clock - s.lastInteraction
            if !s.dragging && !reduceMotion {
                s.yaw += 0.085 * KoiMath.clamp((idle - 2.0) / 2.0, 0, 1) * dt          // slow turntable drift
            }
            if !s.dragging && idle > 6 {
                s.pitch = KoiMath.damp(s.pitch, to: KoiInteractionController.defaultPitch, rate: 0.8, dt: dt)
            }
            if s.resetting {
                s.yaw += KoiMath.wrapAngle(KoiInteractionController.defaultYaw - s.yaw) * (1 - exp(-6 * dt))
                s.pitch = KoiMath.damp(s.pitch, to: KoiInteractionController.defaultPitch, rate: 6, dt: dt)
            }
            s.yaw = KoiMath.wrapAngle(s.yaw)
            s.pitch = KoiMath.clamp(s.pitch, -1.15, 1.3)
            s.zoom = KoiMath.damp(s.zoom, to: s.zoomTarget, rate: 8, dt: dt)
            let remaining = s.burstUntil - s.clock
            let energy = remaining > 0 ? 1 + 0.9 * remaining / 1.6 : 1
            return Pose(yaw: s.yaw, pitch: s.pitch, zoom: s.zoom, energy: energy)
        }
    }
}
