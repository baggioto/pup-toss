import CoreGraphics
import Testing
@testable import PupToss

struct SandReachTests {
    let pup = NogginKind(breed: .iggy, tier: .pup)

    @Test func sandGivesExtraMergeReach() {
        // Edges 30 apart: beyond the 14 pt Pup gap, within it plus a 24 pt sand bonus.
        let apart = [MergePiece(id: 0, kind: pup, position: .zero), MergePiece(id: 1, kind: pup, position: CGPoint(x: 74, y: 0))]
        #expect(MergeEngine.groups(in: apart).isEmpty)
        var inSand = apart
        inSand[0].gapBonus = 24
        #expect(MergeEngine.groups(in: inSand).count == 1)
    }
}

struct BreedBagTests {
    let breeds: [Breed] = [.stray, .iggy, .shiba, .husky]

    @Test func everyBreedTurnsUpOncePerBag() {
        var bag = BreedBag()
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<5 {
            let round = (0..<breeds.count).map { _ in bag.draw(available: breeds, lonely: [], bias: 0, using: &generator) }
            #expect(Set(round) == Set(breeds))
        }
    }

    @Test func fullBiasAlwaysDealsALonelyBreed() {
        var bag = BreedBag()
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            #expect(bag.draw(available: breeds, lonely: [.husky], bias: 1, using: &generator) == .husky)
        }
    }

    @Test func lonelyBreedsNotInPlayAreIgnored() {
        var bag = BreedBag()
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            #expect(bag.draw(available: breeds, lonely: [.pug], bias: 1, using: &generator) != .pug)
        }
    }
}

struct BowlTests {
    let physics = RollingPhysics()
    let open = CGRect(x: -2000, y: -2000, width: 4000, height: 4000)

    @Test func bowlPullsTowardItsCenterAndFadesThere() {
        let features = LawnFeatures(bowl: .init(center: CGPoint(x: 0, y: 300), strength: 70))
        let far = features.push(at: CGPoint(x: 0, y: 0))
        #expect(far.dy > 69 && far.dy < 71)
        #expect(features.push(at: CGPoint(x: 0, y: 300)).length < 0.001)
        #expect(features.push(at: CGPoint(x: 0, y: 225)).length < 40)
    }

    @Test func aimLineBendsTowardTheBowl() {
        let features = LawnFeatures(bowl: .init(center: CGPoint(x: 200, y: 300), strength: 120))
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 700), spin: 0, radius: 0,
                                       bounds: open, features: features)
        #expect((path.last?.x ?? 0) > 10)
    }

    @Test func restingPiecesIgnoreTheBowl() {
        var velocity = CGVector.zero
        var spin: CGFloat = 0
        physics.step(velocity: &velocity, spin: &spin, dt: 1.0 / 120.0, push: CGVector(dx: 70, dy: 0))
        #expect(velocity == .zero)
    }
}

struct PressureTests {
    @Test func straysArriveMoreOftenAsTheScoreGrows() {
        #expect(Pressure.strayInterval(score: 0, base: 5) == 5)
        #expect(Pressure.strayInterval(score: 1_500, base: 5) == 4)
        #expect(Pressure.strayInterval(score: 100_000, base: 5) == 2)
        #expect(Pressure.strayInterval(score: 0, base: 0) == 0)
    }

    @Test func windBendsTheAimLine() {
        var features = LawnFeatures()
        features.wind = CGVector(dx: 120, dy: 0)
        let path = RollingPhysics().predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 700), spin: 0, radius: 0,
                                                bounds: CGRect(x: -2000, y: -2000, width: 4000, height: 4000), features: features)
        #expect((path.last?.x ?? 0) > 20)
    }
}
