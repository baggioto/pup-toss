import Foundation
import Observation

/// The only state shared between the scene and SwiftUI. The scene writes it; views observe it.
@Observable
final class GameModel {
    static let maxFouls = 3
    private static let bestKey = "bestScore"

    private(set) var score = 0
    private(set) var best: Int
    var chain = 0
    private(set) var fouls = 0
    private(set) var throwsMade = 0
    private(set) var merges = 0
    private(set) var pops = 0
    private(set) var upcoming: [NogginKind] = []
    private(set) var isGameOver = false
    private(set) var isNewBest = false
    private(set) var goals = GoalTracker()
    /// The latest finished goal; `id` changes each time so views can celebrate it.
    private(set) var completedGoal: CompletedGoal?
    /// On the last foul, or with a crowded lawn: the scene warns and adds slow motion to the throw.
    var isLastChance = false
    private var generated = 0

    struct CompletedGoal: Equatable {
        let id: Int
        let goal: Goal
    }

    init() {
        best = UserDefaults.standard.integer(forKey: Self.bestKey)
        reset()
    }

    func reset() {
        score = 0
        chain = 0
        fouls = 0
        throwsMade = 0
        merges = 0
        pops = 0
        isGameOver = false
        isNewBest = false
        goals = GoalTracker(order: Goal.allCases.shuffled())
        completedGoal = nil
        isLastChance = false
        generated = 0
        upcoming = (0..<3).map { _ in nextKind() }
    }

    func takeNext() -> NogginKind {
        let kind = upcoming.removeFirst()
        upcoming.append(nextKind())
        return kind
    }

    /// Counts a merge toward the current goal, awarding its bonus when it completes.
    @discardableResult
    func recordMerge(into tier: Tier) -> Goal? {
        guard let done = goals.recordMerge(into: tier, chain: chain) else { return nil }
        score += done.bonus
        completedGoal = CompletedGoal(id: (completedGoal?.id ?? 0) + 1, goal: done)
        return done
    }

    func throwEnded() {
        goals.throwEnded()
    }

    func recordThrow() {
        throwsMade += 1
    }

    func award(_ points: Int, popped: Bool) {
        score += points
        if popped { pops += 1 } else { merges += 1 }
    }

    /// Returns true when this foul ends the game.
    func recordFoul() -> Bool {
        fouls += 1
        return fouls >= Self.maxFouls
    }

    func finish() {
        isGameOver = true
        commitBest()
    }

    /// Saves the score as the personal best if it beats it. Also called when quitting mid-round.
    func commitBest() {
        if score > best {
            best = score
            isNewBest = true
            UserDefaults.standard.set(best, forKey: Self.bestKey)
        }
    }

    /// Only Pups are thrown; bigger tiers exist only through merging. From the sixth piece on, a
    /// special turns up now and then: Wild Pup 6%, Bone 4%, Bulldog 4%.
    private func nextKind() -> NogginKind {
        generated += 1
        if generated > 5 {
            let roll = Double.random(in: 0..<1)
            if roll < 0.06 { return .special(.wild) }
            if roll < 0.10 { return .special(.bone) }
            if roll < 0.14 { return .special(.bulldog) }
        }
        return NogginKind(breed: Breed.allCases.randomElement() ?? .shiba, tier: .pup)
    }
}
