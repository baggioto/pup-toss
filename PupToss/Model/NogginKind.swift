import CoreGraphics

nonisolated enum Breed: String, CaseIterable, Sendable {
    case shiba, pug, dalmatian, husky

    var displayName: String { rawValue.capitalized }
}

nonisolated enum Tier: Int, CaseIterable, Sendable {
    case pup = 1, goodBoy, topDog

    /// The tier a pair of these merges into; `nil` for the top tier.
    var next: Tier? { Tier(rawValue: rawValue + 1) }

    var radius: CGFloat {
        switch self {
        case .pup: 22
        case .goodBoy: 31
        case .topDog: 41
        }
    }

    /// Edge-to-edge distance within which pieces of this tier count as near enough to merge.
    var mergeGap: CGFloat {
        switch self {
        case .pup: 14
        case .goodBoy, .topDog: 21
        }
    }

    var displayName: String {
        switch self {
        case .pup: "Pup"
        case .goodBoy: "Good Boy"
        case .topDog: "Top Dog"
        }
    }
}

nonisolated struct NogginKind: Hashable, Sendable {
    var breed: Breed
    var tier: Tier

    var radius: CGFloat { tier.radius }
}
