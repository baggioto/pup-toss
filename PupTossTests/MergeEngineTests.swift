import CoreGraphics
import Testing
@testable import PupToss

struct MergeEngineTests {
    let pup = NogginKind(breed: .shiba, tier: .pup)

    private func pieces(_ kind: NogginKind, at points: [(CGFloat, CGFloat)]) -> [MergePiece] {
        points.enumerated().map { MergePiece(id: $0.offset, kind: kind, position: CGPoint(x: $0.element.0, y: $0.element.1)) }
    }

    @Test func twoNearbyMatchesMergeAtTheirCentre() {
        let groups = MergeEngine.groups(in: pieces(pup, at: [(0, 0), (40, 10)]))
        #expect(groups.count == 1)
        #expect(groups.first?.ids == [0, 1])
        #expect(abs((groups.first?.centroid.x ?? 0) - 20) < 0.001)
        #expect(abs((groups.first?.centroid.y ?? 0) - 5) < 0.001)
    }

    @Test func aLonePieceDoesNotMerge() {
        #expect(MergeEngine.groups(in: pieces(pup, at: [(0, 0)])).isEmpty)
    }

    @Test func differentBreedsDoNotMerge() {
        var mixed = pieces(pup, at: [(0, 0)])
        mixed.append(MergePiece(id: 1, kind: NogginKind(breed: .pug, tier: .pup), position: CGPoint(x: 40, y: 0)))
        #expect(MergeEngine.groups(in: mixed).isEmpty)
    }

    @Test func differentTiersDoNotMerge() {
        var mixed = pieces(pup, at: [(0, 0)])
        mixed.append(MergePiece(id: 1, kind: NogginKind(breed: .shiba, tier: .goodBoy), position: CGPoint(x: 50, y: 0)))
        #expect(MergeEngine.groups(in: mixed).isEmpty)
    }

    @Test func separatePairsMergeSeparately() {
        let groups = MergeEngine.groups(in: pieces(pup, at: [(0, 0), (40, 0), (300, 0), (340, 0)]))
        #expect(groups.map(\.ids) == [[0, 1], [2, 3]])
    }

    @Test func chainOfNeighboursCountsAsOneGroup() {
        // Each piece is near the next, but the ends are 150 apart.
        let groups = MergeEngine.groups(in: pieces(pup, at: [(0, 0), (50, 0), (100, 0), (150, 0)]))
        #expect(groups.map(\.ids) == [[0, 1, 2, 3]])
    }

    @Test func piecesBeyondTheGapDoNotMerge() {
        // Edges 56 apart with radius 22 each: 100 > 22 + 22 + 14.
        #expect(MergeEngine.groups(in: pieces(pup, at: [(0, 0), (100, 0)])).isEmpty)
    }

    @Test func goodBoyPairPopsIntoATopDog() {
        let goodBoy = NogginKind(breed: .husky, tier: .goodBoy)
        let groups = MergeEngine.groups(in: pieces(goodBoy, at: [(0, 0), (70, 0)]))
        #expect(groups.first?.pops == true)
    }

    @Test func goodBoysUseTheWiderGap() {
        let goodBoy = NogginKind(breed: .pug, tier: .goodBoy)
        // Centres 83 apart = edges 21 apart: just within the Good Boy gap.
        #expect(MergeEngine.groups(in: pieces(goodBoy, at: [(0, 0), (83, 0)])).count == 1)
        #expect(MergeEngine.groups(in: pieces(goodBoy, at: [(0, 0), (84, 0)])).isEmpty)
    }

    @Test func pupsKeepTheNarrowerGap() {
        // Centres 59 apart = edges 15 apart: just beyond the Pup gap.
        #expect(MergeEngine.groups(in: pieces(pup, at: [(0, 0), (58, 0)])).count == 1)
        #expect(MergeEngine.groups(in: pieces(pup, at: [(0, 0), (59, 0)])).isEmpty)
    }

    @Test func pupPairStaysOnTheLawn() {
        let groups = MergeEngine.groups(in: pieces(pup, at: [(0, 0), (40, 0)]))
        #expect(groups.first?.pops == false)
    }
}

struct ScoringTests {
    private func group(_ tier: Tier, count: Int) -> MergeGroup {
        MergeGroup(kind: NogginKind(breed: .pug, tier: tier), ids: Array(0..<count), centroid: .zero)
    }

    @Test func mergePointsByTier() {
        #expect(Scoring.points(for: group(.pup, count: 2), chain: 1) == 30)
        #expect(Scoring.points(for: group(.goodBoy, count: 2), chain: 1) == 500)
    }

    @Test func extraPiecesAddHalfEach() {
        #expect(Scoring.points(for: group(.pup, count: 3), chain: 1) == 45)
        #expect(Scoring.points(for: group(.pup, count: 4), chain: 1) == 60)
    }

    @Test func chainMultiplies() {
        // Chain multipliers run ×1, ×2, ×4, ×7, ×11.
        #expect(Scoring.points(for: group(.pup, count: 2), chain: 3) == 120)
        #expect(Scoring.points(for: group(.goodBoy, count: 2), chain: 2) == 1000)
        #expect((1...5).map(Scoring.chainMultiplier) == [1, 2, 4, 7, 11])
    }

    @Test func sandMergesPayDouble() {
        #expect(Scoring.points(for: group(.pup, count: 2), chain: 1, bonus: 2) == 60)
    }
}
