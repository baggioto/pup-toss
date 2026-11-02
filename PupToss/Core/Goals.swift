import Foundation

/// One bonus objective at a time during a round.
nonisolated enum Goal: CaseIterable, Sendable {
    case chainOfThree
    case popTopDog
    case threeMergesInOneThrow
    case fourGoodBoys

    var title: String {
        switch self {
        case .chainOfThree: "Reach a ×3 chain"
        case .popTopDog: "Pop a Top Dog"
        case .threeMergesInOneThrow: "3 merges in one throw"
        case .fourGoodBoys: "Make 4 Good Boys"
        }
    }

    /// Fits the small pill under the top bar.
    var shortTitle: String {
        switch self {
        case .chainOfThree: "×3 chain"
        case .popTopDog: "Pop a Top Dog"
        case .threeMergesInOneThrow: "3 merges, 1 throw"
        case .fourGoodBoys: "4 Good Boys"
        }
    }

    var bonus: Int {
        switch self {
        case .chainOfThree, .threeMergesInOneThrow, .fourGoodBoys: 300
        case .popTopDog: 500
        }
    }

    var target: Int {
        switch self {
        case .chainOfThree, .threeMergesInOneThrow: 3
        case .popTopDog: 1
        case .fourGoodBoys: 4
        }
    }

    /// Progress on these goals starts over with every throw.
    var resetsEachThrow: Bool { self == .chainOfThree || self == .threeMergesInOneThrow }
}

nonisolated struct GoalTracker: Sendable {
    private let order: [Goal]
    private var index = 0
    private var mergesThisThrow = 0
    private(set) var progress = 0

    var current: Goal { order[index] }

    init(order: [Goal] = Goal.allCases) {
        precondition(!order.isEmpty)
        self.order = order
    }

    /// Records a merge that made a piece of `tier`. Returns the goal it completed, if any; the next
    /// goal then becomes current.
    mutating func recordMerge(into tier: Tier, chain: Int) -> Goal? {
        mergesThisThrow += 1
        switch current {
        case .chainOfThree: progress = max(progress, chain)
        case .popTopDog: if tier == .topDog { progress += 1 }
        case .threeMergesInOneThrow: progress = max(progress, mergesThisThrow)
        case .fourGoodBoys: if tier == .goodBoy { progress += 1 }
        }
        guard progress >= current.target else { return nil }
        let done = current
        index = (index + 1) % order.count
        progress = 0
        return done
    }

    mutating func throwEnded() {
        mergesThisThrow = 0
        if current.resetsEachThrow { progress = 0 }
    }
}
