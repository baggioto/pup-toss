import SpriteKit

/// The fork, band and pouch. The pouch is a damped spring around the rest point (the node's
/// origin); a loaded Noggin rides the pouch until it passes the rest point on a shot.
final class Slingshot: SKNode {
    static let maxPull: CGFloat = 84
    static let minPull: CGFloat = 16
    /// Launch speed per point of pull.
    static let launchScale: CGFloat = 12
    /// Pull angle allowed either side of straight back, in radians.
    static let maxAngle: CGFloat = 70 * .pi / 180

    private(set) var pull: CGVector = .zero
    private var pouchVelocity: CGVector = .zero
    private var mode = Mode.idle
    private(set) weak var loaded: NogginNode?

    /// Called the moment the pouch releases the Noggin, with its launch velocity and spin.
    var onLaunch: ((NogginNode, CGVector, CGFloat) -> Void)?

    private enum Mode {
        case idle
        case held
        case firing(direction: CGVector, velocity: CGVector, spin: CGFloat, elapsed: TimeInterval)
    }

    private let leftPost = CGPoint(x: -50, y: 0)
    private let rightPost = CGPoint(x: 50, y: 0)
    private let backBand = SKShapeNode()
    private let frontBand = SKShapeNode()
    private let pouch = SKShapeNode()

    override init() {
        super.init()
        buildFork()
        for band in [backBand, frontBand] {
            band.strokeColor = UIColor(hex: 0xB5482E)
            band.lineCap = .round
            addChild(band)
        }
        backBand.zPosition = 0.2
        frontBand.zPosition = 0.2
        pouch.fillColor = UIColor(hex: 0x6B3B1F)
        pouch.strokeColor = .ink
        pouch.lineWidth = 2
        pouch.zPosition = 0.4
        addChild(pouch)
        redraw()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Clamps a raw drag offset to the allowed pull length and angle (pulling back = downward).
    static func clampedPull(_ raw: CGVector) -> CGVector {
        let length = min(raw.length, maxPull)
        guard length > 0 else { return .zero }
        let angle = min(max(atan2(raw.dx, -raw.dy), -maxAngle), maxAngle)
        return CGVector(dx: sin(angle) * length, dy: -cos(angle) * length)
    }

    func load(_ noggin: NogginNode) {
        loaded = noggin
        mode = .idle
        noggin.position = position + pull
    }

    func beginHold() {
        mode = .held
        pouchVelocity = .zero
    }

    func setPull(_ newPull: CGVector) {
        pull = newPull
        redraw()
    }

    func release() {
        mode = .idle
    }

    func fire(velocity: CGVector, spin: CGFloat) {
        mode = .firing(direction: pull.normalized, velocity: velocity, spin: spin, elapsed: 0)
    }

    func update(dt: CGFloat) {
        switch mode {
        case .held:
            break
        case .idle:
            spring(stiffness: 600, damping: 14, dt: dt)
        case let .firing(direction, velocity, spin, elapsed):
            // Stiffness = launchScale² makes the pouch reach launch speed as it passes the rest point.
            spring(stiffness: Self.launchScale * Self.launchScale, damping: 0, dt: dt)
            mode = .firing(direction: direction, velocity: velocity, spin: spin, elapsed: elapsed + dt)
            if pull.dot(direction) <= 0 || elapsed > 0.5 {
                mode = .idle
                if let noggin = loaded {
                    loaded = nil
                    noggin.position = position
                    onLaunch?(noggin, velocity, spin)
                }
            }
        }
        loaded?.position = position + pull
        redraw()
    }

    private func spring(stiffness: CGFloat, damping: CGFloat, dt: CGFloat) {
        let acceleration = pull * -stiffness - pouchVelocity * damping
        pouchVelocity += acceleration * dt
        pull += pouchVelocity * dt
        if case .idle = mode, pull.length < 0.05, pouchVelocity.length < 0.5 {
            pull = .zero
            pouchVelocity = .zero
        }
    }

    private func redraw() {
        let pouchPoint = CGPoint(x: pull.dx, y: pull.dy)
        let stretch = min(1, pull.length / Self.maxPull)
        let width = 6 - 3 * stretch
        for (band, post) in [(backBand, leftPost), (frontBand, rightPost)] {
            let path = CGMutablePath()
            path.move(to: post)
            path.addLine(to: pouchPoint)
            band.path = path
            band.lineWidth = width
        }
        let across = pull.length > 1 ? pull.normalized.perpendicular : CGVector(dx: 1, dy: 0)
        let half = across * 20
        let back = pull.length > 1 ? pull.normalized * 6 : CGVector(dx: 0, dy: -6)
        let path = CGMutablePath()
        path.move(to: pouchPoint + half)
        path.addQuadCurve(to: pouchPoint + half * -1, control: pouchPoint + back * 2.2)
        path.closeSubpath()
        pouch.path = path
    }

    private func buildFork() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -78))
        path.addLine(to: CGPoint(x: 0, y: -34))
        path.move(to: leftPost)
        path.addQuadCurve(to: CGPoint(x: 0, y: -34), control: CGPoint(x: -44, y: -30))
        path.addQuadCurve(to: rightPost, control: CGPoint(x: 44, y: -30))
        let outline = SKShapeNode(path: path)
        outline.strokeColor = .ink
        outline.lineWidth = 15
        outline.lineCap = .round
        let wood = SKShapeNode(path: path)
        wood.strokeColor = UIColor(hex: 0xA8692F)
        wood.lineWidth = 9
        wood.lineCap = .round
        for post in [leftPost, rightPost] {
            let knob = SKShapeNode(circleOfRadius: 8)
            knob.position = post
            knob.fillColor = UIColor(hex: 0xC9772F)
            knob.strokeColor = .ink
            knob.lineWidth = 3
            knob.zPosition = 2.6
            addChild(knob)
        }
        addChild(outline)
        addChild(wood)
    }
}
