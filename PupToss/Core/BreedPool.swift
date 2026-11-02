import Foundation

/// Which breeds can turn up in a round: a fixed starting set, plus breeds that join as the score
/// passes milestones.
nonisolated struct BreedPool: Codable, Equatable, Sendable {
    nonisolated struct Unlock: Codable, Equatable, Sendable {
        var score: Int
        var breed: Breed
    }

    var starting: [Breed]
    var unlocks: [Unlock]

    static let standard = BreedPool(
        starting: [.stray, .iggy, .shiba, .husky],
        unlocks: [Unlock(score: 500, breed: .pug), Unlock(score: 1_500, breed: .dalmatian)]
    )

    /// Breeds in play at `score`.
    func available(at score: Int) -> [Breed] {
        starting + unlocks.filter { score >= $0.score }.map(\.breed)
    }

    /// Breeds that join when the score moves from `old` to `new`.
    func unlocked(from old: Int, to new: Int) -> [Breed] {
        unlocks.filter { old < $0.score && new >= $0.score }.map(\.breed)
    }

    /// The next breed still to join and the score it needs, if any.
    func nextUnlock(after score: Int) -> Unlock? {
        unlocks.filter { score < $0.score }.min { $0.score < $1.score }
    }
}
