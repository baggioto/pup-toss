import CoreGraphics

/// How the lawn gets harder as the score climbs.
nonisolated enum Pressure {
    /// Throws between stray arrivals: `base` at first, one fewer per 1,500 points, never fewer
    /// than 2. A `base` of 0 turns strays off (returns 0).
    static func strayInterval(score: Int, base: CGFloat) -> Int {
        guard base >= 1 else { return 0 }
        return max(2, Int(base) - score / 1_500)
    }
}
