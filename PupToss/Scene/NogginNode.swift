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

    var radius: CGFloat { kind.radius }

    init(kind: NogginKind) {
        self.kind = kind
        art = SKSpriteNode(texture: NogginArt.texture(for: kind))
        shadow = SKShapeNode(circleOfRadius: kind.radius * 1.02)
        shadow.fillColor = UIColor(white: 0, alpha: 0.18)
        shadow.strokeColor = .clear
        super.init()
        addChild(art)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func activatePhysics(velocity: CGVector, spin: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.restitution = 0.62
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
