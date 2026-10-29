import CoreGraphics
import Testing
@testable import PupToss

struct RollingPhysicsTests {
    let physics = RollingPhysics()
    let dt: CGFloat = 1.0 / 120.0

    @Test func throwComesToAFullStop() {
        var velocity = CGVector(dx: 0, dy: 1000)
        var spin: CGFloat = 0
        var time: CGFloat = 0
        while velocity.length > 0, time < 10 {
            physics.step(velocity: &velocity, spin: &spin, dt: dt)
            time += dt
        }
        #expect(velocity.length == 0)
        #expect(time < 3)
    }

    @Test func positiveSpinCurvesLeft() {
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 600), spin: 6, radius: 0,
                                       bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000))
        #expect((path.last?.x ?? 0) < -10)
    }

    @Test func noSpinGoesStraight() {
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 600), spin: 0, radius: 0,
                                       bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000))
        #expect(abs(path.last?.x ?? 1) < 0.001)
        #expect((path.last?.y ?? 0) > 100)
    }

    @Test func spinFadesToZero() {
        var velocity = CGVector.zero
        var spin: CGFloat = 9
        for _ in 0..<240 { physics.step(velocity: &velocity, spin: &spin, dt: dt) }
        #expect(spin == 0)
    }

    @Test func predictedPathStopsAtTheBounds() {
        let bounds = CGRect(x: -100, y: -100, width: 200, height: 200)
        let path = physics.predictPath(from: .zero, velocity: CGVector(dx: 0, dy: 1000), spin: 0, radius: 20, bounds: bounds)
        #expect(abs((path.last?.y ?? 0) - 80) < 0.001)
    }
}

struct CurveGestureTests {
    @Test func straightPullHasNoBend() {
        #expect(CurveGesture.bend(of: [.zero, CGVector(dx: 0, dy: -40), CGVector(dx: 0, dy: -80)]) == 0)
    }

    @Test func pullBowedRightBendsPositive() {
        let path = [CGVector.zero, CGVector(dx: 10, dy: -20), CGVector(dx: 15, dy: -40), CGVector(dx: 10, dy: -60), CGVector(dx: 0, dy: -80)]
        let bend = CurveGesture.bend(of: path)
        #expect(bend > 0.5 && bend < 0.6)
    }

    @Test func bendIsClampedToOne() {
        let path = [CGVector.zero, CGVector(dx: 80, dy: -10), CGVector(dx: 0, dy: -40)]
        #expect(CurveGesture.bend(of: path) == 1)
    }

    @Test func slingshotClampsLengthAndAngle() {
        let pull = Slingshot.clampedPull(CGVector(dx: 500, dy: 0))
        #expect(abs(pull.length - Slingshot.maxPull) < 0.001)
        #expect(pull.dy < 0)
    }
}
