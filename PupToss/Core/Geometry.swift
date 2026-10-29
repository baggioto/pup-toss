import CoreGraphics

nonisolated extension CGVector {
    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }

    static func += (lhs: inout CGVector, rhs: CGVector) {
        lhs = lhs + rhs
    }

    var length: CGFloat { hypot(dx, dy) }

    var normalized: CGVector {
        let l = length
        return l > 0 ? self * (1 / l) : .zero
    }

    /// The vector rotated 90° counter-clockwise.
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }

    func dot(_ other: CGVector) -> CGFloat { dx * other.dx + dy * other.dy }

    /// Positive when `other` lies counter-clockwise (to the left) of `self`.
    func cross(_ other: CGVector) -> CGFloat { dx * other.dy - dy * other.dx }
}

nonisolated extension CGPoint {
    static func + (point: CGPoint, vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }

    func distance(to other: CGPoint) -> CGFloat { (self - other).length }

    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(x, rect.minX), rect.maxX), y: min(max(y, rect.minY), rect.maxY))
    }
}
