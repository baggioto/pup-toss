import CoreGraphics

/// How a patch of ground changes rolling: multipliers on grass friction and drag.
nonisolated struct Surface: Equatable, Sendable {
    var friction: CGFloat
    var drag: CGFloat

    static let grass = Surface(friction: 1, drag: 1)
    /// Grabs Noggins and slows them hard.
    static let sand = Surface(friction: 2.4, drag: 2)
    /// Slick: Noggins slide much further.
    static let puddle = Surface(friction: 0.3, drag: 0.35)
}

/// The round's sand patches, puddles and rocks.
nonisolated struct LawnFeatures: Sendable {
    nonisolated struct Patch: Sendable {
        var center: CGPoint
        var radius: CGFloat
        var surface: Surface
    }

    nonisolated struct Rock: Sendable {
        var center: CGPoint
        var radius: CGFloat
    }

    var patches: [Patch] = []
    var rocks: [Rock] = []

    static let none = LawnFeatures()

    func surface(at point: CGPoint) -> Surface {
        patches.first { $0.center.distance(to: point) <= $0.radius }?.surface ?? .grass
    }

    /// 1–2 sand patches, 1 puddle and 1–2 rocks, kept apart from each other, inside `lawn` and above `minY`
    /// (so the launch zone stays clear).
    static func random<G: RandomNumberGenerator>(in lawn: CGRect, above minY: CGFloat, using generator: inout G) -> LawnFeatures {
        var features = LawnFeatures()
        var placed: [(CGPoint, CGFloat)] = []

        func place(radius: ClosedRange<CGFloat>) -> (CGPoint, CGFloat)? {
            for _ in 0..<60 {
                let r = CGFloat.random(in: radius, using: &generator)
                let xRange = (lawn.minX + r + 12)...(lawn.maxX - r - 12)
                let yRange = (minY + r + 40)...(lawn.maxY - r - 12)
                guard !xRange.isEmpty, !yRange.isEmpty else { return nil }
                let center = CGPoint(x: CGFloat.random(in: xRange, using: &generator),
                                     y: CGFloat.random(in: yRange, using: &generator))
                if placed.allSatisfy({ $0.0.distance(to: center) > $0.1 + r + 28 }) {
                    placed.append((center, r))
                    return (center, r)
                }
            }
            return nil
        }

        for _ in 0..<Int.random(in: 1...2, using: &generator) {
            if let (c, r) = place(radius: 40...56) { features.patches.append(Patch(center: c, radius: r, surface: .sand)) }
        }
        if let (c, r) = place(radius: 38...50) { features.patches.append(Patch(center: c, radius: r, surface: .puddle)) }
        for _ in 0..<Int.random(in: 1...2, using: &generator) {
            if let (c, r) = place(radius: 15...21) { features.rocks.append(Rock(center: c, radius: r)) }
        }
        return features
    }
}
