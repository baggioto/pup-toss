import CoreGraphics
import Foundation
import Testing
@testable import PupToss

struct BreedPoolTests {
    let pool = BreedPool.standard

    @Test func startsWithTheChosenFour() {
        #expect(Set(pool.available(at: 0)) == [.stray, .iggy, .shiba, .husky])
    }

    @Test func pugAndDalmatianJoinAtTheirMilestones() {
        #expect(pool.available(at: 499).contains(.pug) == false)
        #expect(pool.available(at: 500).contains(.pug))
        #expect(pool.available(at: 1_499).contains(.dalmatian) == false)
        #expect(Set(pool.available(at: 1_500)) == Set(Breed.allCases))
    }

    @Test func unlockFiresOnceWhenCrossingAMilestone() {
        #expect(pool.unlocked(from: 450, to: 520) == [.pug])
        #expect(pool.unlocked(from: 520, to: 600).isEmpty)
        #expect(pool.unlocked(from: 0, to: 2_000) == [.pug, .dalmatian])
    }

    @Test func nextUnlockReportsWhatIsLeft() {
        #expect(pool.nextUnlock(after: 0)?.breed == .pug)
        #expect(pool.nextUnlock(after: 600)?.breed == .dalmatian)
        #expect(pool.nextUnlock(after: 2_000) == nil)
    }
}

struct TuningTests {
    @Test func defaultsMatchTheShippedValues() {
        let tuning = Tuning.standard
        #expect(tuning.gaps == MergeGaps.standard)
        #expect(tuning.rolling.friction == tuning.friction)
        #expect(tuning.rolling.drag == tuning.drag)
        #expect(tuning.sand == Surface.sand)
        #expect(tuning.puddle == Surface.puddle)
    }

    @Test func widerGapsMergeFartherPieces() {
        let kind = NogginKind(breed: .stray, tier: .pup)
        let pieces = [MergePiece(id: 0, kind: kind, position: .zero), MergePiece(id: 1, kind: kind, position: CGPoint(x: 70, y: 0))]
        #expect(MergeEngine.groups(in: pieces).isEmpty)
        #expect(MergeEngine.groups(in: pieces, gaps: MergeGaps(pup: 30, goodBoy: 21)).count == 1)
    }

    @Test func retunedLawnKeepsTheLayout() {
        let features = LawnFeatures(patches: [
            .init(center: .zero, radius: 40, surface: .sand, ground: .sand),
            .init(center: CGPoint(x: 200, y: 0), radius: 40, surface: .puddle, ground: .puddle),
        ])
        let tuned = features.with(sand: Surface(friction: 4, drag: 2), puddle: Surface(friction: 0.1, drag: 0.35))
        #expect(tuned.surface(at: .zero).friction == 4)
        #expect(tuned.surface(at: CGPoint(x: 200, y: 0)).friction == 0.1)
        #expect(tuned.patches.map(\.center) == features.patches.map(\.center))
    }
}

struct SavedGameTests {
    @Test func savedGameRoundTripsThroughJSON() throws {
        let model = GameModel()
        model.award(120, popped: false)
        let features = LawnFeatures(patches: [.init(center: CGPoint(x: 100, y: 400), radius: 45, surface: .sand, ground: .sand)],
                                    rocks: [.init(center: CGPoint(x: 250, y: 500), radius: 18)])
        let pieces = [SavedGame.Piece(kind: NogginKind(breed: .iggy, tier: .goodBoy), position: CGPoint(x: 120, y: 520)),
                      SavedGame.Piece(kind: .special(.wild), position: CGPoint(x: 300, y: 610))]
        let saved = model.snapshot(pieces: pieces, loaded: NogginKind(breed: .stray, tier: .pup), features: features)

        let decoded = try JSONDecoder().decode(SavedGame.self, from: JSONEncoder().encode(saved))
        #expect(decoded.score == 120)
        #expect(decoded.pieces.map(\.kind) == pieces.map(\.kind))
        #expect(decoded.pieces.map(\.position) == pieces.map(\.position))
        #expect(decoded.loaded == NogginKind(breed: .stray, tier: .pup))
        #expect(decoded.features.rocks.first?.radius == 18)
        #expect(decoded.goals.current == saved.goals.current)

        let restored = GameModel()
        restored.restore(decoded)
        #expect(restored.score == 120)
        #expect(restored.merges == 1)
        #expect(restored.upcoming == saved.upcoming)
    }

    @Test func crossingAMilestoneAnnouncesTheNewBreed() {
        let model = GameModel()
        model.award(480, popped: false)
        #expect(model.newBreed == nil)
        model.award(30, popped: false)
        #expect(model.newBreed?.breed == .pug)
        #expect(model.availableBreeds.contains(.pug))
    }
}
