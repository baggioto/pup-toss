import CoreGraphics

/// Grass friction, curve and spin decay. SpriteKit only resolves collisions; this runs every
/// step for every moving Noggin, and the aiming preview runs the exact same code.
nonisolated struct RollingPhysics: Sendable {
    /// Constant deceleration from the grass, in pt/s².
    var friction: CGFloat = 360
    /// Speed-proportional drag, per second.
    var drag: CGFloat = 0.7
    /// Sideways acceleration per rad/s of spin, in pt/s². Constant while speed drops, so throws hook late.
    var curve: CGFloat = 11
    var spinFriction: CGFloat = 1.5
    var spinDrag: CGFloat = 0.6
    /// Spin dies this many times faster once the Noggin has stopped moving.
    var restingSpinMultiplier: CGFloat = 8
    /// Below this speed curve no longer applies and the piece counts as still.
    var restSpeed: CGFloat = 5

    func step(velocity: inout CGVector, spin: inout CGFloat, dt: CGFloat, surface: Surface = .grass) {
        var v = velocity
        if v.length > restSpeed {
            // Positive (counter-clockwise) spin pushes to the left of travel.
            v += v.normalized.perpendicular * (curve * spin * dt)
        }
        let speed = v.length
        if speed > 0 {
            let slowed = max(0, speed - friction * surface.friction * dt) / (1 + drag * surface.drag * dt)
            v = v * (slowed / speed)
        }
        velocity = v

        let spinLoss = spinFriction * (v.length == 0 ? restingSpinMultiplier : 1)
        let w = max(0, abs(spin) - spinLoss * dt) / (1 + spinDrag * dt)
        spin = spin < 0 ? -w : w
    }

    /// Path a throw follows, ignoring other Noggins. It feels the lawn's sand and puddles, bounces
    /// up to `bounces` times off `bounds` or rocks, and ends where it stops or at the next contact.
    func predictPath(
        from start: CGPoint,
        velocity: CGVector,
        spin: CGFloat,
        radius: CGFloat,
        bounds: CGRect,
        features: LawnFeatures = .none,
        bounces: Int = 1,
        restitution: CGFloat = 0.6,
        dt: CGFloat = 1.0 / 120.0,
        maxTime: CGFloat = 6
    ) -> [CGPoint] {
        let inner = bounds.insetBy(dx: radius, dy: radius)
        var p = start, v = velocity, w = spin, t: CGFloat = 0
        var bouncesLeft = bounces
        var points = [start]
        while t < maxTime {
            step(velocity: &v, spin: &w, dt: dt, surface: features.surface(at: p))
            if v.length == 0 { break }
            var next = p + v * dt

            if !inner.contains(next) {
                guard bouncesLeft > 0 else {
                    points.append(next.clamped(to: inner))
                    break
                }
                bouncesLeft -= 1
                if next.x < inner.minX || next.x > inner.maxX { v.dx = -v.dx * restitution }
                if next.y < inner.minY || next.y > inner.maxY { v.dy = -v.dy * restitution }
                w *= 0.5
                next = next.clamped(to: inner)
            } else if let rock = features.rocks.first(where: { $0.center.distance(to: next) < $0.radius + radius }) {
                let normal = (next - rock.center).normalized
                let contact = rock.center + normal * (rock.radius + radius)
                guard bouncesLeft > 0 else {
                    points.append(contact)
                    break
                }
                bouncesLeft -= 1
                v = v - normal * ((1 + restitution) * v.dot(normal))
                w *= 0.5
                next = contact
            }

            p = next
            points.append(p)
            t += dt
        }
        return points
    }
}

nonisolated enum CurveGesture {
    /// How strongly a pull-back path bows to one side of the straight line from rest to the final
    /// pull, from -1 to 1. Positive = the path bowed counter-clockwise of that line.
    static func bend(of path: [CGVector]) -> CGFloat {
        guard let end = path.last, end.length > 1 else { return 0 }
        let axis = end.normalized
        var strongest: CGFloat = 0
        for point in path {
            let offset = axis.cross(point)
            if abs(offset) > abs(strongest) { strongest = offset }
        }
        return max(-1, min(1, strongest / (end.length * 0.35)))
    }
}
