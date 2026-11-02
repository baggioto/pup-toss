import CoreGraphics

/// How a patch of ground changes rolling: multipliers on grass friction and drag.
nonisolated struct Surface: Equatable, Codable, Sendable {
    var friction: CGFloat
    var drag: CGFloat

    static let grass = Surface(friction: 1, drag: 1)
    /// Grabs Noggins and slows them hard.
    static let sand = Surface(friction: 2.4, drag: 2)
    /// Slick: Noggins slide much further.
    static let puddle = Surface(friction: 0.3, drag: 0.35)
}

/// The round's sand patches, puddles and rocks.
nonisolated struct LawnFeatures: Codable, Sendable {
    nonisolated enum Ground: String, Codable, Sendable { case sand, puddle }

    nonisolated struct Patch: Codable, Sendable {
        var center: CGPoint
        var radius: CGFloat
        var surface: Surface
        /// What the patch is drawn as and re-tuned as; `nil` for test patches.
        var ground: Ground? = nil
    }

    nonisolated struct Rock: Codable, Sendable {
        var center: CGPoint
        var radius: CGFloat
    }

    /// A gentle slope that draws rolling Noggins toward the middle of the upper lawn.
    nonisolated struct Bowl: Codable, Sendable {
        var center: CGPoint
        /// Pull in pt/s² at full reach; it fades within `radius` so pieces don't jiggle at the centre.
        var strength: CGFloat
        var radius: CGFloat = 150
    }

    var patches: [Patch] = []
    var rocks: [Rock] = []
    var bowl: Bowl?
    /// This turn's gust, in pt/s². Like the bowl, it only pushes moving Noggins.
    var wind: CGVector = .zero

    static let none = LawnFeatures()

    /// The same layout with sand, puddles and the bowl re-tuned (for live tuning).
    func with(sand: Surface, puddle: Surface, bowlStrength: CGFloat? = nil) -> LawnFeatures {
        var copy = self
        if let bowlStrength { copy.bowl?.strength = bowlStrength }
        copy.patches = patches.map { patch in
            var patch = patch
            switch patch.ground {
            case .sand: patch.surface = sand
            case .puddle: patch.surface = puddle
            case nil: break
            }
            return patch
        }
        return copy
    }

    /// The bowl's pull plus the wind at `point`, in pt/s².
    func push(at point: CGPoint) -> CGVector {
        guard let bowl else { return wind }
        let offset = bowl.center - point
        return offset.normalized * (bowl.strength * min(1, offset.length / bowl.radius)) + wind
    }

    func ground(at point: CGPoint) -> Ground? {
        patches.first { $0.center.distance(to: point) <= $0.radius }?.ground
    }

    func isSand(at point: CGPoint) -> Bool { ground(at: point) == .sand }

    func surface(at point: CGPoint) -> Surface {
        patches.first { $0.center.distance(to: point) <= $0.radius }?.surface ?? .grass
    }

    /// 1–2 sand patches, 1 puddle and 1–2 rocks, kept apart from each other, inside `lawn` and above `minY`
    /// (so the launch zone stays clear).
    static func random<G: RandomNumberGenerator>(in lawn: CGRect, above minY: CGFloat, using generator: inout G) -> LawnFeatures {
        var features = LawnFeatures()
        features.bowl = Bowl(center: CGPoint(x: lawn.midX, y: (minY + lawn.maxY) / 2), strength: 70)
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
            if let (c, r) = place(radius: 40...56) { features.patches.append(Patch(center: c, radius: r, surface: .sand, ground: .sand)) }
        }
        if let (c, r) = place(radius: 38...50) { features.patches.append(Patch(center: c, radius: r, surface: .puddle, ground: .puddle)) }
        for _ in 0..<Int.random(in: 1...2, using: &generator) {
            if let (c, r) = place(radius: 15...21) { features.rocks.append(Rock(center: c, radius: r)) }
        }
        return features
    }
}
