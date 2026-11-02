import CoreGraphics

/// Every number that shapes how the game feels, in one place so the debug tuning panel can change
/// them live. The defaults are the shipped values.
nonisolated struct Tuning: Codable, Equatable, Sendable {
    // Rolling
    var friction: CGFloat = 360
    var drag: CGFloat = 0.7
    var curve: CGFloat = 11
    var maxSpin: CGFloat = 9
    /// Multiplies launch speed.
    var power: CGFloat = 1

    // Bounces
    var nogginBounce: CGFloat = 0.62
    var hedgeBounce: CGFloat = 0.55
    var rockBounce: CGFloat = 0.8

    // Merging
    var pupGap: CGFloat = 14
    var goodBoyGap: CGFloat = 21
    /// Pieces slower than this merge while the rest of the lawn is still moving.
    var mergeSpeed: CGFloat = 30

    // Specials and lawn
    var bonePull: CGFloat = 1
    var bulldogWeight: CGFloat = 4
    var sandFriction: CGFloat = 2.4
    var puddleFriction: CGFloat = 0.3

    static let standard = Tuning()

    var gaps: MergeGaps { MergeGaps(pup: pupGap, goodBoy: goodBoyGap) }

    var rolling: RollingPhysics {
        var physics = RollingPhysics()
        physics.friction = friction
        physics.drag = drag
        physics.curve = curve
        return physics
    }

    var sand: Surface { Surface(friction: sandFriction, drag: Surface.sand.drag) }
    var puddle: Surface { Surface(friction: puddleFriction, drag: Surface.puddle.drag) }
}

/// Edge-to-edge distances within which pieces count as near enough to merge, per tier.
nonisolated struct MergeGaps: Codable, Equatable, Sendable {
    var pup: CGFloat
    var goodBoy: CGFloat

    static let standard = MergeGaps(pup: Tier.pup.mergeGap, goodBoy: Tier.goodBoy.mergeGap)

    func gap(for tier: Tier) -> CGFloat {
        tier == .pup ? pup : goodBoy
    }
}
