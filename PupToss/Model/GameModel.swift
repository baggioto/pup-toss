import Foundation
import Observation

/// The only state shared between the scene and SwiftUI. The scene writes it; views observe it.
@Observable
final class GameModel {
    static let maxFouls = 3
    private static let bestKey = "bestScore"
    private static let soundKey = "soundOn"
    private static let tuningKey = "tuning"

    let breeds = BreedPool.standard

    private(set) var score = 0
    private(set) var best: Int
    var chain = 0
    /// When the current chain runs out unless another merge lands (drives the badge's meter).
    var chainDeadline: Date?
    /// The chain length the badge's meter counts down from, in seconds.
    var chainWindow: TimeInterval { TimeInterval(tuning.chainWindow) }
    static let maxWhistles = 3
    /// Earned by reaching a ×4 chain. Tap to arm, then tap the lawn to call nearby dogs.
    private(set) var whistles = 0
    var isWhistleArmed = false
    /// Breeds with a Pup on the lawn that has no partner; the queue leans toward them.
    var lonelyBreeds: [Breed] = []
    private var bag = BreedBag()
    private(set) var fouls = 0
    private(set) var throwsMade = 0
    private(set) var merges = 0
    private(set) var pops = 0
    private(set) var upcoming: [NogginKind] = []
    /// Which upcoming pieces are Mystery Pups, shown as "?" until they land.
    private(set) var upcomingMystery: [Bool] = []
    private(set) var isGameOver = false
    private(set) var isNewBest = false
    private(set) var goals = GoalTracker()
    /// The latest finished goal; `id` changes each time so views can celebrate it.
    private(set) var completedGoal: CompletedGoal?
    /// The latest breed to join the round; `id` changes each time so views can announce it.
    private(set) var newBreed: NewBreed?
    private var generated = 0

    /// Sound effects on or off, remembered between launches.
    var isSoundOn: Bool {
        didSet { UserDefaults.standard.set(isSoundOn, forKey: Self.soundKey) }
    }

    /// Live physics and merge values. Debug builds remember tuning-panel changes between launches.
    var tuning: Tuning {
        didSet {
            #if DEBUG
            if let data = try? JSONEncoder().encode(tuning) { UserDefaults.standard.set(data, forKey: Self.tuningKey) }
            #endif
        }
    }

    struct CompletedGoal: Equatable {
        let id: Int
        let goal: Goal
    }

    struct NewBreed: Equatable {
        let id: Int
        let breed: Breed
    }

    init() {
        best = UserDefaults.standard.integer(forKey: Self.bestKey)
        isSoundOn = UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true
        tuning = .standard
        #if DEBUG
        if let data = UserDefaults.standard.data(forKey: Self.tuningKey),
           let saved = try? JSONDecoder().decode(Tuning.self, from: data) {
            tuning = saved
        }
        // `-tuning '{"friction":480}'` overrides individual values for this launch (for test runs).
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-tuning"), arguments.indices.contains(flag + 1),
           let overrides = try? JSONSerialization.jsonObject(with: Data(arguments[flag + 1].utf8)) as? [String: Any],
           var merged = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(Tuning.standard))) as? [String: Any] {
            merged.merge(overrides) { $1 }
            if let data = try? JSONSerialization.data(withJSONObject: merged),
               let custom = try? JSONDecoder().decode(Tuning.self, from: data) {
                tuning = custom
            }
        }
        #endif
        reset()
    }

    var availableBreeds: [Breed] { breeds.available(at: score) }

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
        newBreed = nil
        chainDeadline = nil
        whistles = 0
        isWhistleArmed = false
        lonelyBreeds = []
        bag = BreedBag()
        generated = 0
        upcoming = []
        upcomingMystery = []
        for _ in 0..<3 { queueNext() }
    }

    /// The next piece for the slingshot, and whether it's a Mystery Pup.
    func takeNext() -> (kind: NogginKind, mystery: Bool) {
        let next = (upcoming.removeFirst(), upcomingMystery.removeFirst())
        queueNext()
        return next
    }

    private func queueNext() {
        let kind = nextKind()
        upcoming.append(kind)
        // From the ninth piece, an ordinary Pup sometimes arrives as a mystery.
        upcomingMystery.append(generated > 8 && kind.special == nil && Double.random(in: 0..<1) < Double(tuning.mysteryChance))
    }

    /// Counts a merge toward the current goal, awarding its bonus when it completes.
    @discardableResult
    func recordMerge(into tier: Tier) -> Goal? {
        guard let done = goals.recordMerge(into: tier, chain: chain) else { return nil }
        addScore(done.bonus)
        completedGoal = CompletedGoal(id: (completedGoal?.id ?? 0) + 1, goal: done)
        return done
    }

    func throwEnded() {
        goals.throwEnded()
    }

    /// Adds a Whistle, up to the maximum. Returns whether one was added.
    @discardableResult
    func earnWhistle() -> Bool {
        guard whistles < Self.maxWhistles else { return false }
        whistles += 1
        return true
    }

    func useWhistle() {
        whistles = max(0, whistles - 1)
        isWhistleArmed = false
    }

    func recordThrow() {
        throwsMade += 1
    }

    func award(_ points: Int, popped: Bool) {
        addScore(points)
        if popped { pops += 1 } else { merges += 1 }
    }

    private func addScore(_ points: Int) {
        let old = score
        score += points
        if let breed = breeds.unlocked(from: old, to: score).last {
            newBreed = NewBreed(id: (newBreed?.id ?? 0) + 1, breed: breed)
        }
    }

    // MARK: Saving

    /// The model's half of a saved round; the scene adds the lawn.
    func snapshot(pieces: [SavedGame.Piece], loaded: NogginKind?, features: LawnFeatures) -> SavedGame {
        SavedGame(score: score, fouls: fouls, throwsMade: throwsMade, merges: merges, pops: pops,
                  upcoming: upcoming, generated: generated, goals: goals,
                  pieces: pieces, loaded: loaded, features: features, whistles: whistles)
    }

    func restore(_ game: SavedGame) {
        reset()
        score = game.score
        fouls = game.fouls
        throwsMade = game.throwsMade
        merges = game.merges
        pops = game.pops
        upcoming = game.upcoming
        upcomingMystery = Array(repeating: false, count: game.upcoming.count)
        generated = game.generated
        goals = game.goals
        whistles = game.whistles ?? 0
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

    /// Only Pups of the breeds in play are thrown; bigger tiers exist only through merging. From the sixth piece on, a
    /// special turns up now and then: Wild Pup 6%, Bone 4%, Bulldog 4%.
    private func nextKind() -> NogginKind {
        generated += 1
        if generated > 5 {
            let roll = Double.random(in: 0..<1)
            if roll < 0.06 { return .special(.wild) }
            if roll < 0.10 { return .special(.bone) }
            if roll < 0.14 { return .special(.bulldog) }
        }
        var generator = SystemRandomNumberGenerator()
        let breed = bag.draw(available: availableBreeds, lonely: lonelyBreeds, bias: Double(tuning.queueBias), using: &generator)
        return NogginKind(breed: breed, tier: .pup)
    }
}
