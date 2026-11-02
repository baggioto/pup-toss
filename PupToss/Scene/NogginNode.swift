import SpriteKit

nonisolated enum PhysicsCategory {
    static let noggin: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
}

final class NogginNode: SKNode {
    let kind: NogginKind
    /// Kept separate from the body so squish and pop-in never change the collision shape.
    let art: SKSpriteNode
    /// Lives on the scene's shadow layer so it doesn't spin with the head.
    let shadow: SKShapeNode
    var isMerging = false
    /// Velocity going into the latest physics step, used to measure impact strength.
    var lastVelocity: CGVector = .zero
    /// Grass flecks kicked up behind a fast roll; owned and positioned by the scene.
    var trail: SKEmitterNode?
    /// When this Noggin last left a skid mark, to space them out.
    var lastSkid: TimeInterval = 0
    /// Crossed a puddle; shakes itself dry when it comes to rest.
    var isWet = false
    /// Turns since this Noggin arrived without merging; bored dogs fall asleep.
    var idleTurns = 0
    /// Asleep: heavy, can't merge, until a hard hit wakes it.
    private(set) var isAsleep = false
    /// A Mystery Pup hides its breed under a "?" until it lands.
    private(set) var isMystery = false
    private var mysteryMask: SKSpriteNode?

    /// The resting face: calm (blinks now and then), happy (a match is close by) or nervous
    /// (stretched tight in the slingshot). Short reactions play over it and then return to it.
    enum Mood { case calm, happy, nervous, asleep }

    var mood = Mood.calm {
        didSet { if mood != oldValue { showMood() } }
    }

    private var moodExpression: NogginExpression {
        switch mood {
        case .calm: .normal
        case .happy: .happy
        case .nervous: .wince
        case .asleep: .blink
        }
    }

    var radius: CGFloat { kind.radius }

    init(kind: NogginKind) {
        self.kind = kind
        art = SKSpriteNode(texture: NogginArt.texture(for: kind))
        shadow = SKShapeNode(circleOfRadius: kind.radius * 1.02)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        super.init()
        addChild(art)
        showMood()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func activatePhysics(velocity: CGVector, spin: CGFloat, bounce: CGFloat = Tuning.standard.nogginBounce) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.restitution = bounce
        body.friction = 0.35
        body.linearDamping = 0
        body.angularDamping = 0
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.noggin
        body.collisionBitMask = PhysicsCategory.noggin | PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.noggin | PhysicsCategory.wall
        physicsBody = body
        body.velocity = velocity
        body.angularVelocity = spin
        lastVelocity = velocity
    }

    func squish(_ intensity: CGFloat) {
        let amount = 0.06 + 0.16 * intensity
        let squash = SKAction.scaleX(to: 1 + amount, y: 1 - amount, duration: 0.05)
        squash.timingMode = .easeOut
        let rebound = SKAction.scaleX(to: 1 - amount * 0.5, y: 1 + amount * 0.5, duration: 0.07)
        rebound.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1, duration: 0.09)
        settle.timingMode = .easeOut
        art.run(.sequence([squash, rebound, settle]), withKey: "squish")
    }

    /// Plays `expression` for `duration`, then returns to the mood's face.
    func react(_ expression: NogginExpression, for duration: TimeInterval) {
        art.removeAction(forKey: "face")
        art.texture = NogginArt.texture(for: kind, expression: expression)
        art.run(.sequence([.wait(forDuration: duration), faceLoop()]), withKey: "face")
        if expression == .dizzy {
            let wobble = SKAction.sequence([
                .rotate(toAngle: 0.18, duration: 0.12), .rotate(toAngle: -0.18, duration: 0.24),
                .rotate(toAngle: 0.1, duration: 0.2), .rotate(toAngle: 0, duration: 0.16),
            ])
            art.run(wobble, withKey: "wobble")
        }
    }

    private func showMood() {
        art.removeAction(forKey: "face")
        art.run(faceLoop(), withKey: "face")
    }

    /// The mood's face; a calm face also blinks every few seconds.
    private func faceLoop() -> SKAction {
        let rest = SKAction.setTexture(NogginArt.texture(for: kind, expression: moodExpression))
        guard mood == .calm else { return rest }
        let blink = SKAction.sequence([
            .wait(forDuration: 3.5, withRange: 4),
            .setTexture(NogginArt.texture(for: kind, expression: .blink)),
            .wait(forDuration: 0.11),
            rest,
        ])
        return .sequence([rest, .repeatForever(blink)])
    }

    func fallAsleep() {
        guard !isAsleep else { return }
        isAsleep = true
        mood = .asleep
        physicsBody?.mass *= 3
        let z = SKLabelNode(text: "z")
        z.name = "zees"
        z.fontName = "AvenirNext-Heavy"
        z.fontSize = 14 + radius * 0.2
        z.fontColor = .white
        z.zPosition = 2
        let start = CGPoint(x: radius * 0.6, y: radius * 0.7)
        z.position = start
        z.alpha = 0
        z.run(.repeatForever(.sequence([
            .move(to: start, duration: 0),
            .fadeIn(withDuration: 0.1),
            .group([.moveBy(x: 10, y: 22, duration: 1), .fadeOut(withDuration: 1)]),
            .wait(forDuration: 0.2),
        ])))
        addChild(z)
    }

    func wakeUp() {
        guard isAsleep else { return }
        isAsleep = false
        idleTurns = 0
        physicsBody?.mass /= 3
        childNode(withName: "zees")?.removeFromParent()
        mood = .calm
        react(.dizzy, for: 0.9)
    }

    func hideAsMystery() {
        isMystery = true
        let mask = SKSpriteNode(texture: NogginArt.mysteryTexture(radius: radius))
        mask.zPosition = 1
        art.addChild(mask)
        mysteryMask = mask
    }

    /// Lifts the "?" with a little puff to show the real breed.
    func revealMystery() {
        guard isMystery, let mask = mysteryMask else { return }
        isMystery = false
        mysteryMask = nil
        mask.run(.sequence([.group([.scale(to: 1.4, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        popIn()
    }

    func popIn() {
        art.setScale(0.3)
        let grow = SKAction.scale(to: 1.18, duration: 0.12)
        grow.timingMode = .easeOut
        let dip = SKAction.scale(to: 0.94, duration: 0.08)
        dip.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1, duration: 0.08)
        settle.timingMode = .easeOut
        art.run(.sequence([grow, dip, settle]), withKey: "squish")
    }
}
