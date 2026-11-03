import CoreGraphics
import Testing
@testable import PupToss

/// Cases where a Wild Pup's choice of partner should be the obvious one.
struct WildPupChoiceTests {
    let wild = NogginKind.special(.wild)
    let husky = NogginKind(breed: .husky, tier: .pup)
    let shiba = NogginKind(breed: .shiba, tier: .pup)

    private func piece(_ id: Int, _ kind: NogginKind, _ x: CGFloat, _ y: CGFloat = 0) -> MergePiece {
        MergePiece(id: id, kind: kind, position: CGPoint(x: x, y: y))
    }

    /// The wild is pressed right against a lone Husky, with a Shiba pair just within reach on the
    /// other side. It should pair with the Husky it's touching, not jump to the farther Shibas.
    @Test func wildPairsWithThePupItIsTouching() {
        let pieces = [piece(0, wild, 0), piece(1, husky, 44),
                      piece(2, shiba, -56), piece(3, shiba, -100)]
        let groups = MergeEngine.groups(in: pieces)
        let wildGroup = groups.first { $0.ids.contains(0) }
        #expect(wildGroup?.kind == husky)
        #expect(wildGroup?.ids == [0, 1])
        // The Shiba pair still merges on its own.
        #expect(groups.contains { $0.ids == [2, 3] && $0.kind == shiba })
    }

    /// A lone Pup next to the wild should get the merge rather than a pair that merges anyway.
    @Test func wildPrefersAPupThatWouldOtherwiseBeLeftAlone() {
        let pieces = [piece(0, wild, 0), piece(1, husky, 50),
                      piece(2, shiba, -50), piece(3, shiba, -94)]
        let groups = MergeEngine.groups(in: pieces)
        #expect(groups.first { $0.ids.contains(0) }?.kind == husky)
        #expect(groups.count == 2)
    }
}
