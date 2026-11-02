import CoreGraphics

nonisolated enum Breed: String, CaseIterable, Sendable {
    case shiba, pug, dalmatian, husky, stray, iggy

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

/// Rare pieces that turn up in the throw queue.
nonisolated enum Special: String, CaseIterable, Sendable {
    /// Merges with a Pup of any breed and becomes that breed's Good Boy.
    case wild
    /// Draws nearby Noggins toward it after it lands; eaten at the end of the turn.
    case bone
    /// A heavy head that ploughs through the lawn; never merges, trots off at the end of the turn.
    case bulldog

    var displayName: String {
        switch self {
        case .wild: "Wild Pup"
        case .bone: "Bone"
        case .bulldog: "Bulldog"
        }
    }
}

nonisolated struct NogginKind: Hashable, Sendable {
    var breed: Breed
    var tier: Tier
    var special: Special? = nil

    /// A special piece. Its breed is a placeholder and never used for matching.
    static func special(_ special: Special) -> NogginKind {
        NogginKind(breed: .shiba, tier: .pup, special: special)
    }

    var radius: CGFloat {
        switch special {
        case .bone: 16
        case .bulldog: 30
        case .wild, nil: tier.radius
        }
    }

    var isWild: Bool { special == .wild }
    /// Bones and Bulldogs stay out of merges and leave the lawn at the end of the turn.
    var isVisitor: Bool { special == .bone || special == .bulldog }
}
