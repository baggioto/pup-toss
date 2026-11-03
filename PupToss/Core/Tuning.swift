import CoreGraphics

/// Every number that shapes how the game feels, in one place so the debug tuning panel can change
/// them live. The defaults are the shipped values, tuned for a swift game: Noggins stop fast
/// (friction 560, drag 1.1) with extra throw power (1.25×) so a full pull still reaches the top
/// hedge, merges start early and animate quickly, and events come often. Measured with the
/// aiming autoplay: about 1.2 s from release to a settled lawn, against 1.4 s before.
nonisolated struct Tuning: Codable, Equatable, Sendable {
    // Rolling
    var friction: CGFloat = 560
    var drag: CGFloat = 1.1
    var curve: CGFloat = 11
    var maxSpin: CGFloat = 9
    /// Multiplies launch speed.
    var power: CGFloat = 1.25

    // Bounces
    var nogginBounce: CGFloat = 0.62
    var hedgeBounce: CGFloat = 0.55
    var rockBounce: CGFloat = 0.8

    // Merging
    var pupGap: CGFloat = 14
    var goodBoyGap: CGFloat = 21
    /// Pieces slower than this merge while the rest of the lawn is still moving.
    var mergeSpeed: CGFloat = 80
    /// How long two Noggins take to pull together and merge, in seconds.
    var mergeDuration: CGFloat = 0.14
    /// How long the lawn must stay still before the turn ends, in seconds.
    var settleWait: CGFloat = 0.15

    // Specials and lawn
    var bonePull: CGFloat = 1
    var bulldogWeight: CGFloat = 4
    var sandFriction: CGFloat = 2.4
    var puddleFriction: CGFloat = 0.3
    /// Extra merge reach for pieces in sand, in pt.
    var sandGapBonus: CGFloat = 24
    /// Score multiplier for merges that happen in sand.
    var sandScore: CGFloat = 2
    /// How far a wet Noggin's shake-off reaches, in pt.
    var shakeReach: CGFloat = 130
    /// The bowl's pull toward the middle of the upper lawn, in pt/s².
    var bowl: CGFloat = 70

    // Chains and a lively lawn
    /// Share of the merged pieces' motion the new piece keeps (0 = appears at rest).
    var momentum: CGFloat = 0.8
    /// How much a merge's shockwave steers neighbours toward their own matches (0 = pushes straight out).
    var matchmaker: CGFloat = 0.5
    /// Merges within this many seconds of each other keep the chain going.
    var chainWindow: CGFloat = 2.5
    /// Seconds between idle scoots while aiming (0 = off).
    var scootInterval: CGFloat = 3.5
    /// How far beyond merge range an idle dog will scoot toward a match, in pt. A scoot only closes
    /// half the gap, so the player still has to finish the merge.
    var magnetRange: CGFloat = 60
    /// Turns without merging before a Noggin falls asleep (0 = never).
    var boredTurns: CGFloat = 21
    /// Chance the next Pup is a breed with a lonely Pup on the lawn.
    var queueBias: CGFloat = 0.35

    // Pressure
    /// Throws between stray Pups wandering in at the start (0 = off); shortens as the score grows.
    var strayEvery: CGFloat = 4
    /// Chance a turn has a gust of wind (from the 6th throw).
    var gustChance: CGFloat = 0.3
    /// Typical gust strength, in pt/s².
    var gustStrength: CGFloat = 110
    /// Chance per turn of a squirrel dashing across (from the 9th throw).
    var squirrelChance: CGFloat = 0.12
    /// Chance a Pup arrives as a Mystery Pup (from the 9th piece).
    var mysteryChance: CGFloat = 0.12

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
