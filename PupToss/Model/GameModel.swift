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
        upcoming = (0..<3).map { _ in Self.randomKind() }
    }

    func takeNext() -> NogginKind {
        let kind = upcoming.removeFirst()
        upcoming.append(Self.randomKind())
        return kind
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
        if score > best {
            best = score
            isNewBest = true
            UserDefaults.standard.set(best, forKey: Self.bestKey)
        }
    }

    /// Only Pups are thrown; bigger tiers exist only through merging.
    private static func randomKind() -> NogginKind {
        NogginKind(breed: Breed.allCases.randomElement() ?? .shiba, tier: .pup)
    }
}
