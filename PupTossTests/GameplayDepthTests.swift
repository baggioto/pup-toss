import CoreGraphics
import Testing
@testable import PupToss

struct WildPupTests {
    private func piece(_ id: Int, _ kind: NogginKind, _ x: CGFloat, _ y: CGFloat = 0) -> MergePiece {
        MergePiece(id: id, kind: kind, position: CGPoint(x: x, y: y))
    }

    let shiba = NogginKind(breed: .shiba, tier: .pup)
    let pug = NogginKind(breed: .pug, tier: .pup)
    let wild = NogginKind.special(.wild)

    @Test func wildPupMergesWithAnyBreed() {
        let groups = MergeEngine.groups(in: [piece(0, wild, 0), piece(1, pug, 44)])
        #expect(groups.count == 1)
        #expect(groups.first?.kind == pug)
        #expect(groups.first?.usesWild == true)
    }

    @Test func twoWildPupsAloneDoNotMerge() {
        #expect(MergeEngine.groups(in: [piece(0, wild, 0), piece(1, wild, 44)]).isEmpty)
    }

    @Test func wildPupJoinsTheBiggerGroup() {
        // A Shiba pair on the left, a lone Pug on the right; the wild sits between them.
        let pieces = [piece(0, shiba, -88), piece(1, shiba, -44), piece(2, wild, 0), piece(3, pug, 44)]
        let groups = MergeEngine.groups(in: pieces)
        #expect(groups.count == 1)
        #expect(groups.first?.kind == shiba)
        #expect(groups.first?.ids == [0, 1, 2])
    }

    @Test func wildPupDoesNotJoinGoodBoys() {
        let goodBoy = NogginKind(breed: .pug, tier: .goodBoy)
        #expect(MergeEngine.groups(in: [piece(0, wild, 0), piece(1, goodBoy, 50)]).isEmpty)
    }

    @Test func bonesAndBulldogsNeverMerge() {
        let pieces = [piece(0, .special(.bone), 0), piece(1, .special(.bone), 30),
                      piece(2, .special(.bulldog), 200), piece(3, .special(.bulldog), 260)]
        #expect(MergeEngine.groups(in: pieces).isEmpty)
    }
}

struct LawnTests {
    let physics = RollingPhysics()
    let open = CGRect(x: -2000, y: -2000, width: 4000, height: 4000)

    private func distance(on surface: Surface) -> CGFloat {
        let center = CGPoint.zero
        let features = LawnFeatures(patches: [.init(center: center, radius: 5000, surface: surface)])
        let path = physics.predictPath(from: center, velocity: CGVector(dx: 0, dy: 800), spin: 0, radius: 0,
                                       bounds: open, features: features)
        return path.last?.y ?? 0
    }

    @Test func sandSlowsAndPuddlesSlide() {
        let grass = distance(on: .grass)
        #expect(distance(on: .sand) < grass * 0.7)
        #expect(distance(on: .puddle) > grass * 1.5)
    }

    @Test func surfaceLookupFallsBackToGrass() {
        let features = LawnFeatures(patches: [.init(center: .zero, radius: 10, surface: .sand)])
        #expect(features.surface(at: CGPoint(x: 5, y: 0)) == .sand)
        #expect(features.surface(at: CGPoint(x: 50, y: 0)) == .grass)
    }

    @Test func randomFeaturesStayInsideAndAboveTheLaunchZone() {
        var generator = SystemRandomNumberGenerator()
        let lawn = CGRect(x: 16, y: 40, width: 358, height: 676)
        for _ in 0..<50 {
            let features = LawnFeatures.random(in: lawn, above: 236, using: &generator)
            for patch in features.patches {
                #expect(lawn.insetBy(dx: patch.radius, dy: patch.radius).contains(patch.center))
                #expect(patch.center.y - patch.radius > 236)
            }
            for rock in features.rocks {
                #expect(rock.center.y - rock.radius > 236)
            }
        }
    }
}

struct AimBounceTests {
    let physics = RollingPhysics()

    @Test func aimLineBouncesOnceOffTheHedge() {
        let bounds = CGRect(x: -100, y: -100, width: 200, height: 200)
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 1000), spin: 0, radius: 20, bounds: bounds)
        #expect(path.contains { abs($0.y - 80) < 0.001 })
        #expect((path.last?.y ?? 80) < 79)
    }

    @Test func aimLineBouncesOffRocks() {
        let rock = LawnFeatures.Rock(center: CGPoint(x: 0, y: 100), radius: 10)
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 700), spin: 0, radius: 10,
                                       bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000),
                                       features: LawnFeatures(rocks: [rock]))
        let highest = path.map(\.y).max() ?? 0
        #expect(abs(highest - 80) < 0.001)
        #expect((path.last?.y ?? 80) < highest)
    }
}

struct GoalTrackerTests {
    @Test func chainGoalCompletesAtThree() {
        var tracker = GoalTracker(order: [.chainOfThree, .popTopDog])
        #expect(tracker.recordMerge(into: .goodBoy, chain: 1) == nil)
        #expect(tracker.recordMerge(into: .goodBoy, chain: 2) == nil)
        #expect(tracker.recordMerge(into: .goodBoy, chain: 3) == .chainOfThree)
        #expect(tracker.current == .popTopDog)
    }

    @Test func perThrowGoalsResetBetweenThrows() {
        var tracker = GoalTracker(order: [.threeMergesInOneThrow])
        _ = tracker.recordMerge(into: .goodBoy, chain: 1)
        _ = tracker.recordMerge(into: .goodBoy, chain: 1)
        tracker.throwEnded()
        #expect(tracker.progress == 0)
        #expect(tracker.recordMerge(into: .goodBoy, chain: 1) == nil)
    }

    @Test func goodBoyGoalCountsAcrossThrows() {
        var tracker = GoalTracker(order: [.fourGoodBoys, .chainOfThree])
        for _ in 0..<3 {
            _ = tracker.recordMerge(into: .goodBoy, chain: 1)
            tracker.throwEnded()
        }
        #expect(tracker.progress == 3)
        #expect(tracker.recordMerge(into: .topDog, chain: 1) == nil)
        #expect(tracker.recordMerge(into: .goodBoy, chain: 1) == .fourGoodBoys)
    }

    @Test func popGoalNeedsATopDog() {
        var tracker = GoalTracker(order: [.popTopDog])
        #expect(tracker.recordMerge(into: .goodBoy, chain: 1) == nil)
        #expect(tracker.recordMerge(into: .topDog, chain: 1) == .popTopDog)
    }
}
