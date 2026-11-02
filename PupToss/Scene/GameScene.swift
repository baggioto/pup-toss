import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum Phase { case aiming, rolling, resolving, gameOver }

    static let sceneSize = CGSize(width: 390, height: 844)

    private let model: GameModel
    private var tuning: Tuning { model.tuning }
    private var rolling: RollingPhysics { model.tuning.rolling }
    /// The round's layout as generated; `features` is it with the current sand and puddle tuning.
    private var baseFeatures = LawnFeatures.none
    private var appliedTuning = Tuning.standard
    private var pendingRestore: SavedGame?
    /// Matching Noggins that touched since the last frame; they merge whatever their speed.
    private var pendingContacts: Set<ObjectIdentifier> = []
    private var lastMergeTime: Date?
    private var sinceScoot: TimeInterval = 0
    private var nextScoot: TimeInterval = 1.4
    /// A Whistle call moves the lawn without a throw; the loaded Noggin stays in the slingshot.
    private var whistleTurn = false
    private let walls = SKNode()
    private let sound = SoundEngine.shared
    private let lawnRect = CGRect(x: 16, y: 40, width: 358, height: 676)
    private let foulY: CGFloat = 236
    /// The top of the area strays, squirrels and the wind arrow use, below the top hedge.
    private var upperY: CGFloat { lawnRect.maxY - 70 }
    private let foulLine = SKShapeNode()
    private let launchZone = SKSpriteNode(color: UIColor(white: 0, alpha: 0.08), size: .zero)
    private var throwsSinceStray = 0
    private var windIndicator: SKNode?
    private var windLeaves: SKEmitterNode?
    private var squirrelRunning = false
    private let anchor = CGPoint(x: 195, y: 148)
    private let rollingStep: CGFloat = 1.0 / 120.0

    private let shadowLayer = SKNode()
    /// Sand, puddles and rocks: on the lawn, under everything else.
    private let featureLayer = SKNode()
    /// "Almost a match" hint lines, under the pieces.
    private let hintLayer = SKNode()
    private var hintLines: [SKShapeNode] = []
    private var features = LawnFeatures.none
    private let cameraNode = SKCameraNode()
    /// Skid marks: above the lawn, under the shadows.
    private let marksLayer = SKNode()
    private let pieceLayer = SKNode()
    private let aimLayer = SKNode()
    private let fxLayer = SKNode()
    private let slingshot = Slingshot()
    private var aimDots: [SKShapeNode] = []
    private let aimRing = SKShapeNode(circleOfRadius: 1)

    private var pieces: [NogginNode] = []
    private var loaded: NogginNode?
    private var phase = Phase.aiming
    private var clock: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var rollingDebt: CGFloat = 0
    private var stillTime: TimeInterval = 0
    private var sinceMergeCheck: TimeInterval = 0
    /// Merges whose animation hasn't finished; the turn can't end while any are running.
    private var activeMerges = 0
    private let mergeCheckInterval: TimeInterval = 0.1
    private var scheduled: [(time: TimeInterval, action: () -> Void)] = []

    private var dragStart: CGPoint?
    private var dragPath: [CGVector] = []

    private var lastHaptic: TimeInterval = 0
    private let haptics = Haptics()
    private var sinceMoodCheck: TimeInterval = 0
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)

    /// The piece thrown this turn.
    private weak var thrown: NogginNode?
    /// After a Bone lands, nearby Noggins rush toward it until `until`.
    private var boneLure: (bone: NogginNode, until: TimeInterval)?
    /// Slow motion for the last-chance throw: armed on release, active as the throw slows down.
    private var dramaArmed = false
    private var dramaActive = false
    private var dramaEnds: TimeInterval = 0
    private var timeScale: CGFloat = 1
    private let notifyHaptic = UINotificationFeedbackGenerator()

    init(model: GameModel) {
        self.model = model
        super.init(size: Self.sceneSize)
        scaleMode = .aspectFill
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard pieceLayer.parent == nil else { return }
        backgroundColor = UIColor(hex: 0x3F8A47)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        buildLawn()

        featureLayer.zPosition = 0.4
        marksLayer.zPosition = 0.8
        shadowLayer.zPosition = 1
        hintLayer.zPosition = 2.5
        slingshot.zPosition = 2
        pieceLayer.zPosition = 3
        aimLayer.zPosition = 5
        fxLayer.zPosition = 6
        for layer in [featureLayer, marksLayer, shadowLayer, hintLayer, pieceLayer, aimLayer, fxLayer] { addChild(layer) }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode

        slingshot.position = anchor
        slingshot.onLaunch = { [weak self] noggin, velocity, spin in
            self?.launch(noggin, velocity: velocity, spin: spin)
        }
        addChild(slingshot)
        buildAimGuide()
        if let pending = pendingRestore {
            pendingRestore = nil
            restore(pending)
        } else {
            startRound()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-debugGoodBoys") { debugSpawnGoodBoys() }
        if ProcessInfo.processInfo.arguments.contains("-debugChain") { debugSpawnChain() }
        if ProcessInfo.processInfo.arguments.contains("-debugLawn") { debugSpawnLawn() }
        if ProcessInfo.processInfo.arguments.contains("-debugHUD") {
            // A long score with a chain showing, for checking the top bar layout.
            model.award(128_450, popped: false)
            model.chain = 4
        }
        #endif
    }

    #if DEBUG
    private func debugSpawnGoodBoys() {
        for (x, y) in [(CGFloat(160), CGFloat(450)), (230, 450), (195, 510)] {
            let node = NogginNode(kind: NogginKind(breed: .shiba, tier: .goodBoy))
            node.position = CGPoint(x: x, y: y)
            add(node)
            node.activatePhysics(velocity: .zero, spin: 0, bounce: tuning.nogginBounce)
            pieces.append(node)
        }
        phase = .rolling
    }

    /// Two Pups whose merge lands a Good Boy near an existing Good Boy (about 120 pt away with `-far`).
    private func debugSpawnChain() {
        let far = ProcessInfo.processInfo.arguments.contains("-far")
        let layout: [(Tier, CGFloat, CGFloat)] = [(.pup, 175, 470), (.pup, 215, 470),
                                                  (.goodBoy, far ? 315 : 275, 470)]
        for (tier, x, y) in layout {
            let node = NogginNode(kind: NogginKind(breed: .husky, tier: tier))
            node.position = CGPoint(x: x, y: y)
            add(node)
            node.activatePhysics(velocity: .zero, spin: 0, bounce: tuning.nogginBounce)
            pieces.append(node)
        }
        phase = .rolling
    }

    /// Resting pieces with two near-miss pairs and a Wild Pup, while aiming, on a random lawn.
    private func debugSpawnLawn() {
        let layout: [(NogginKind, CGFloat, CGFloat)] = [
            (NogginKind(breed: .shiba, tier: .pup), 90, 330), (NogginKind(breed: .shiba, tier: .pup), 152, 336),
            (NogginKind(breed: .husky, tier: .goodBoy), 250, 520), (NogginKind(breed: .husky, tier: .goodBoy), 330, 560),
            (NogginKind(breed: .iggy, tier: .pup), 300, 330), (.special(.wild), 110, 600),
        ]
        for (kind, x, y) in layout {
            let node = NogginNode(kind: kind)
            node.position = CGPoint(x: x, y: y)
            add(node)
            node.activatePhysics(velocity: .zero, spin: 0, bounce: tuning.nogginBounce)
            pieces.append(node)
        }
        after(0.4) { [weak self] in self?.updateHints() }
    }

    private var autoplay: Bool { ProcessInfo.processInfo.arguments.contains("-autoplay") }

    /// Tries a spread of pulls on the aim line and takes one that lands on a match, like a player
    /// would; falls back to a random pull that clears the foul line.
    private func debugAutoThrow() {
        guard let loaded else { return }
        var fallback: (CGVector, CGFloat)?
        var best: (CGVector, CGFloat)?
        for _ in 0..<40 {
            let angle = CGFloat.random(in: -0.6...0.6)
            let length = CGFloat.random(in: 34...Slingshot.maxPull)
            let pull = CGVector(dx: sin(angle) * length, dy: -cos(angle) * length)
            let spin = CGFloat.random(in: -4...4)
            let path = rolling.predictPath(from: anchor, velocity: pull * (-Slingshot.launchScale * tuning.power), spin: spin,
                                           radius: loaded.radius, bounds: lawnRect, features: features)
            guard let end = path.last, end.y > foulY + 40 else { continue }
            if fallback == nil { fallback = (pull, spin) }
            if completesGroup(loaded.kind, at: end) {
                best = (pull, spin)
                break
            }
        }
        guard let (pull, spin) = best ?? fallback else { return }
        slingshot.beginHold()
        slingshot.setPull(pull)
        slingshot.fire(velocity: pull * (-Slingshot.launchScale * tuning.power), spin: spin)
        phase = .resolving
    }

    private func debugLogTurn() {
        var report: [String] = []
        for breed in Breed.allCases {
            let boys = pieces.filter { $0.kind == NogginKind(breed: breed, tier: .goodBoy) && $0.physicsBody != nil }
            guard boys.count >= 2 else { continue }
            var closest = CGFloat.infinity
            for i in boys.indices { for j in boys.indices where j > i { closest = min(closest, boys[i].position.distance(to: boys[j].position)) } }
            report.append("\(breed.rawValue) x\(boys.count) closest=\(Int(closest)) need<=\(Int(2 * Tier.goodBoy.radius + Tier.goodBoy.mergeGap))")
        }
        let boys = pieces.filter { $0.kind.tier == .goodBoy }
        print("[turn-end] goodBoys at \(boys.map { "\(Int($0.position.x)),\(Int($0.position.y))" }) pairwise=\(boys.indices.flatMap { i in boys.indices.filter { $0 > i }.map { Int(boys[i].position.distance(to: boys[$0].position)) } })")
        let tiers = Dictionary(grouping: pieces, by: \.kind.tier).mapValues(\.count)
        let visitors = pieces.filter(\.kind.isVisitor).map { $0.kind.special?.rawValue ?? "" }
        print("[turn] throw=\(model.throwsMade) score=\(model.score) pups=\(tiers[.pup] ?? 0) goodBoys=\(tiers[.goodBoy] ?? 0) merges=\(model.merges) pops=\(model.pops) goal=\(model.goals.current) \(model.goals.progress)/\(model.goals.current.target) thrown=\(thrown?.kind.special?.rawValue ?? "pup") visitors=\(visitors) \(report)")
    }
    #endif

    func restart() {
        SaveStore.clear()
        startRound()
    }

    /// The round as it stands, for saving when the app goes to the background. `nil` once the game
    /// is over (nothing to continue).
    func snapshot() -> SavedGame? {
        guard phase != .gameOver, !model.isGameOver else { return nil }
        let resting = pieces.filter { !$0.isMerging && !$0.kind.isVisitor && $0.physicsBody != nil }
        return model.snapshot(pieces: resting.map { SavedGame.Piece(kind: $0.kind, position: $0.position, asleep: $0.isAsleep) },
                              loaded: loaded?.kind, features: baseFeatures)
    }

    /// Rebuilds a saved round. Saved mid-throw, the lawn settles and the turn finishes on resume.
    func restore(_ game: SavedGame) {
        // Not on screen yet: rebuild once the scene is set up.
        guard pieceLayer.parent != nil else {
            pendingRestore = game
            return
        }
        for node in pieces { remove(node) }
        if let loaded { remove(loaded) }
        loaded = nil
        scheduled.removeAll()
        activeMerges = 0
        boneLure = nil
        endDrama(animated: false)
        model.restore(game)
        resetPressure()
        baseFeatures = game.features
        drawFeatures()
        for piece in game.pieces {
            let node = NogginNode(kind: piece.kind)
            node.position = piece.position
            add(node)
            node.activatePhysics(velocity: .zero, spin: 0, bounce: tuning.nogginBounce)
            node.trail = Effects.grassTrail(in: shadowLayer)
            if piece.asleep == true { node.fallAsleep() }
            pieces.append(node)
        }
        if let kind = game.loaded {
            let node = NogginNode(kind: kind)
            add(node)
            node.popIn()
            loaded = node
            slingshot.load(node)
            phase = .aiming
        } else {
            stillTime = 0
            phase = .rolling
        }
    }

    // MARK: - Round flow

    private func startRound() {
        for node in pieces { remove(node) }
        if let loaded { remove(loaded) }
        loaded = nil
        scheduled.removeAll()
        activeMerges = 0
        boneLure = nil
        endDrama(animated: false)
        model.reset()
        resetPressure()
        layOutFeatures()
        loadNext()
    }

    private func resetPressure() {
        throwsSinceStray = 0
        squirrelRunning = false
        setWind(.zero)
    }

    /// A fresh arrangement of sand, puddles and rocks each round (none in the debug scenarios).
    private func layOutFeatures() {
        featureLayer.removeAllChildren()
        var generator = SystemRandomNumberGenerator()
        #if DEBUG
        let scenario = ["-debugGoodBoys", "-debugChain", "-debugHUD"].contains(where: ProcessInfo.processInfo.arguments.contains)
        baseFeatures = scenario ? .none : LawnFeatures.random(in: lawnRect, above: foulY, using: &generator)
        #else
        baseFeatures = LawnFeatures.random(in: lawnRect, above: foulY, using: &generator)
        #endif
        drawFeatures()
    }

    private func drawFeatures() {
        featureLayer.removeAllChildren()
        features = baseFeatures.with(sand: tuning.sand, puddle: tuning.puddle, bowlStrength: tuning.bowl)
        for patch in features.patches {
            featureLayer.addChild(patch.ground == .puddle ? Effects.puddle(radius: patch.radius) : Effects.sandPatch(radius: patch.radius))
            featureLayer.children.last?.position = patch.center
        }
        if let bowl = features.bowl {
            // A faint worn patch shows where the lawn dips.
            let dip = SKShapeNode(circleOfRadius: bowl.radius)
            dip.position = bowl.center
            dip.fillColor = UIColor(white: 1, alpha: 0.06)
            dip.strokeColor = UIColor(white: 1, alpha: 0.1)
            dip.lineWidth = 2
            dip.zPosition = -0.1
            featureLayer.addChild(dip)
        }
        for rock in features.rocks {
            let node = Effects.rock(radius: rock.radius)
            node.position = rock.center
            let body = SKPhysicsBody(circleOfRadius: rock.radius)
            body.isDynamic = false
            body.restitution = tuning.rockBounce
            body.friction = 0.2
            body.categoryBitMask = PhysicsCategory.wall
            node.physicsBody = body
            featureLayer.addChild(node)
        }
    }

    private func loadNext() {
        let next = model.takeNext()
        let node = NogginNode(kind: next.kind)
        if next.mystery { node.hideAsMystery() }
        add(node)
        node.popIn()
        rollGust()
        if model.throwsMade >= 8, CGFloat.random(in: 0..<1) < tuning.squirrelChance {
            after(.random(in: 1.0...2.2)) { [weak self] in self?.squirrelDash() }
        }
        loaded = node
        slingshot.load(node)
        phase = .aiming
        model.isLastChance = model.fouls == GameModel.maxFouls - 1 || pieces.count >= 18
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-debugDrama") { model.isLastChance = true }
        if autoplay { print("[camera] scale=\(String(format: "%.2f", cameraNode.xScale)) at=\(Int(cameraNode.position.x)),\(Int(cameraNode.position.y)) lastChance=\(model.isLastChance)") }
        #endif
        #if DEBUG
        // Autoplay aims for about as long as a person would, so idle scoots get their chance.
        if autoplay { after(2.5) { [weak self] in self?.debugAutoThrow() } }
        #endif
    }

    private func launch(_ node: NogginNode, velocity: CGVector, spin: CGFloat) {
        node.activatePhysics(velocity: velocity, spin: spin, bounce: tuning.nogginBounce)
        pieces.append(node)
        loaded = nil
        model.recordThrow()
        stillTime = 0
        phase = .rolling
        node.mood = .calm
        node.trail = Effects.grassTrail(in: shadowLayer)
        thrown = node
        dramaArmed = model.isLastChance
        model.isLastChance = false
        if node.kind.special == .bulldog, let body = node.physicsBody {
            // Four times the weight and a dull bounce: it ploughs through instead of rebounding.
            body.mass *= tuning.bulldogWeight
            body.restitution = 0.3
        }
    }

    /// Merges every group found among pieces slower than `maxSpeed`, plus any in `touching`
    /// (matching pieces that just bumped, which merge at any speed). Returns whether any merged.
    @discardableResult
    private func mergeCheck(maxSpeed: CGFloat, touching: Set<ObjectIdentifier> = []) -> Bool {
        let candidates = pieces.filter { node in
            guard !node.isMerging, !node.isAsleep, let body = node.physicsBody else { return false }
            return body.velocity.length < maxSpeed || touching.contains(ObjectIdentifier(node))
        }
        let groups = MergeEngine.groups(in: candidates.enumerated().map { mergePiece($0.offset, $0.element) }, gaps: tuning.gaps)
        guard !groups.isEmpty else { return false }
        advanceChain()
        for group in groups {
            merge(group.ids.map { candidates[$0] }, as: group)
        }
        stillTime = 0
        return true
    }

    /// A piece as the merge rules see it; sitting in sand gives it extra reach.
    private func mergePiece(_ id: Int, _ node: NogginNode, at position: CGPoint? = nil) -> MergePiece {
        let position = position ?? node.position
        return MergePiece(id: id, kind: node.kind, position: position,
                          gapBonus: features.isSand(at: position) ? tuning.sandGapBonus : 0)
    }

    /// Merges within the chain window of the last one extend the chain; otherwise it starts over.
    /// Long chains earn a Whistle at ×4 and shake the screen from ×3.
    private func advanceChain() {
        let now = Date()
        if let last = lastMergeTime, now.timeIntervalSince(last) <= model.chainWindow {
            model.chain += 1
        } else {
            model.chain = 1
        }
        lastMergeTime = now
        model.chainDeadline = now.addingTimeInterval(model.chainWindow)
        let chain = model.chain
        #if DEBUG
        if autoplay { print("[chain] \(chain) phase=\(phase)") }
        #endif
        guard chain >= 3 else { return }
        if !dramaActive { shakeCamera(strength: CGFloat(min(chain, 6)) * 2) }
        Effects.floatingText("×\(Scoring.chainMultiplier(chain)) COMBO!", at: CGPoint(x: lawnRect.midX, y: lawnRect.maxY - 90),
                             color: UIColor(hex: 0xFF8A3D), size: 30 + CGFloat(min(chain, 6)) * 3, in: fxLayer)
        if chain == 4, model.earnWhistle() {
            Effects.floatingText("Whistle earned!", at: CGPoint(x: lawnRect.midX, y: lawnRect.maxY - 140),
                                 color: UIColor(hex: 0xFFE27A), size: 22, in: fxLayer)
            sound.play(.unlock)
        }
    }

    private func shakeCamera(strength: CGFloat) {
        guard cameraNode.action(forKey: "shake") == nil else { return }
        var moves: [SKAction] = []
        var offset = CGVector.zero
        for _ in 0..<5 {
            let next = CGVector(dx: .random(in: -strength...strength), dy: .random(in: -strength...strength))
            moves.append(.moveBy(x: next.dx - offset.dx, y: next.dy - offset.dy, duration: 0.035))
            offset = next
        }
        moves.append(.moveBy(x: -offset.dx, y: -offset.dy, duration: 0.05))
        cameraNode.run(.sequence(moves), withKey: "shake")
    }

    private func merge(_ nodes: [NogginNode], as group: MergeGroup) {
        activeMerges += 1
        let target = group.centroid
        // The merged piece carries on with the pair's combined motion.
        let carried = nodes.reduce(CGVector.zero) { $0 + ($1.physicsBody?.velocity ?? .zero) } * (1 / CGFloat(nodes.count))
        let inSand = features.isSand(at: target)
        for node in nodes {
            node.isMerging = true
            node.physicsBody = nil
            node.mood = .happy
            node.trail?.particleBirthRate = 0
            let move = SKAction.move(to: target, duration: 0.2)
            move.timingMode = .easeIn
            node.run(.group([move, .scale(to: 0.55, duration: 0.2)]))
        }
        heavyHaptic.prepare()
        after(0.2) { [weak self] in
            guard let self else { return }
            for node in nodes { self.remove(node) }
            let points = Scoring.points(for: group, chain: self.model.chain, bonus: inSand ? Double(self.tuning.sandScore) : 1)
            if inSand {
                Effects.floatingText("Dig spot ×\(String(format: "%g", Double(self.tuning.sandScore)))!", at: target + CGVector(dx: 0, dy: 56),
                                     color: UIColor(hex: 0xF2D58A), size: 20, in: self.fxLayer)
            }
            self.model.award(points, popped: group.pops)
            let kind = NogginKind(breed: group.kind.breed, tier: group.kind.tier.next ?? .topDog)
            if let goal = self.model.recordMerge(into: kind.tier) {
                Effects.floatingText("Goal! +\(goal.bonus)", at: target + CGVector(dx: 0, dy: 70), color: UIColor(hex: 0x8EC5FF), size: 24, in: self.fxLayer)
                self.sound.play(.goal)
                self.notifyHaptic.notificationOccurred(.success)
            }
            if group.pops {
                self.celebrateTopDog(kind, at: target, points: points)
            } else {
                self.spawnMerged(kind, at: target, velocity: carried * self.tuning.momentum)
                Effects.floatingText("+\(points)", at: target + CGVector(dx: 0, dy: 30), color: .white, size: 26, in: self.fxLayer)
                self.activeMerges -= 1
            }
            if self.model.chain > 1 {
                Effects.floatingText("Chain ×\(self.model.chain)", at: target + CGVector(dx: 0, dy: -36), color: UIColor(hex: 0xFF8A3D),
                                     size: 18 + CGFloat(min(self.model.chain, 6)) * 2, in: self.fxLayer)
            }
        }
    }

    private func spawnMerged(_ kind: NogginKind, at point: CGPoint, velocity: CGVector = .zero) {
        let node = NogginNode(kind: kind)
        node.position = point.clamped(to: lawnRect.insetBy(dx: kind.radius + 2, dy: kind.radius + 2))
        add(node)
        node.activatePhysics(velocity: velocity, spin: 0, bounce: tuning.nogginBounce)
        node.popIn()
        node.react(.happy, for: 0.8)
        node.trail = Effects.grassTrail(in: shadowLayer)
        pieces.append(node)
        // Shockwaves grow with the chain.
        let boost = 1 + 0.15 * CGFloat(max(0, model.chain - 1))
        shockwave(at: node.position, reach: kind.radius * 3.2 * boost, strength: 260 * boost, sparing: kind)
        callFriends(of: node)
        Effects.confetti(at: node.position, colors: NogginArt.colors(for: kind.breed), amount: 10, in: fxLayer)
        heavyHaptic.impactOccurred(intensity: 0.7)
        sound.play(.pop, pitch: (1 + 0.08 * Float(max(0, model.chain - 1))) * Float.random(in: 0.97...1.03))
    }

    /// A Top Dog never stays on the lawn: it pops in, wiggles and hops, then bursts for the bonus.
    /// It has no physics body, so it neither blocks nor merges while it celebrates.
    private func celebrateTopDog(_ kind: NogginKind, at point: CGPoint, points: Int) {
        let node = NogginNode(kind: kind)
        node.position = point.clamped(to: lawnRect.insetBy(dx: kind.radius, dy: kind.radius))
        node.zPosition = 1
        add(node)
        node.popIn()
        node.mood = .happy
        node.addChild(Effects.crownSparkles(radius: kind.radius))
        sound.play(.bark, pitch: 0.85)
        shockwave(at: node.position, reach: 130, strength: 300, sparing: nil)
        Effects.confetti(at: node.position, colors: [UIColor(hex: 0xFFC93C), .white], amount: 8, in: fxLayer)
        heavyHaptic.impactOccurred(intensity: 1)

        let wiggle = SKAction.sequence([
            .rotate(toAngle: 0.28, duration: 0.08),
            .rotate(toAngle: -0.28, duration: 0.14),
            .rotate(toAngle: 0.18, duration: 0.1),
            .rotate(toAngle: -0.1, duration: 0.08),
            .rotate(toAngle: 0, duration: 0.06),
        ])
        let hop = SKAction.sequence([.scale(to: 1.3, duration: 0.18), .scale(to: 1.05, duration: 0.14), .scale(to: 1.2, duration: 0.14)])
        hop.timingMode = .easeInEaseOut
        let vanish = SKAction.group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)])
        node.run(.sequence([.wait(forDuration: 0.32), .group([wiggle, hop]), .wait(forDuration: 0.12), vanish]))

        after(0.9) { [weak self] in
            guard let self else { return }
            let center = node.position
            self.remove(node)
            Effects.popBurst(at: center, in: self.fxLayer)
            self.sound.play(.fanfare)
            Effects.confetti(at: center, colors: NogginArt.colors(for: kind.breed) + [UIColor(hex: 0xFFC93C)], amount: 24, in: self.fxLayer)
            Effects.floatingText("TOP DOG! +\(points)", at: center + CGVector(dx: 0, dy: 40), color: UIColor(hex: 0xFFC93C), size: 30, in: self.fxLayer)
            self.shockwave(at: center, reach: 170, strength: 380, sparing: nil)
            self.notifyHaptic.notificationOccurred(.success)
            self.activeMerges -= 1
        }
    }

    /// Jolts nearby pieces. With the matchmaker on, each one is steered toward its own nearest
    /// match (rolling just far enough to meet it) instead of straight outward. Pieces of `sparing`
    /// kind are left alone so a fresh merge doesn't blow away its own next partners; `steerOnly`
    /// leaves pieces with no match nearby where they are.
    private func shockwave(at point: CGPoint, reach: CGFloat, strength: CGFloat, sparing: NogginKind?,
                           steerOnly: Bool = false, excluding: NogginNode? = nil, showRing: Bool = true) {
        if showRing { Effects.shockRing(at: point, radius: reach, in: fxLayer) }
        for node in pieces where node.kind != sparing && node !== excluding && !node.isMerging {
            guard let body = node.physicsBody else { continue }
            let offset = node.position - point
            let distance = offset.length
            guard distance < reach, distance > 0.1 else { continue }
            let outward = offset.normalized * (strength * (1 - distance / reach))
            guard tuning.matchmaker > 0, let partner = nearestMatch(for: node, within: 220) else {
                if !steerOnly { body.velocity += outward }
                continue
            }
            let toPartner = partner.position - node.position
            let travel = max(0, toPartner.length - node.radius - partner.radius - tuning.gaps.gap(for: node.kind.tier) * 0.4)
            let friction = rolling.friction * features.surface(at: node.position).friction
            let steer = toPartner.normalized * min(520, sqrt(2 * friction * travel) * 1.12)
            body.velocity += steer * tuning.matchmaker + (steerOnly ? .zero : outward * (1 - tuning.matchmaker))
        }
    }

    private func nearestMatch(for node: NogginNode, within reach: CGFloat) -> NogginNode? {
        pieces.filter { other in
            other !== node && !other.isMerging && !other.isAsleep && other.physicsBody != nil && Self.couldMerge(node.kind, other.kind)
                && other.position.distance(to: node.position) < reach
        }
        .min { $0.position.distance(to: node.position) < $1.position.distance(to: node.position) }
    }

    /// Matching pieces within twice the merge distance roll toward a freshly merged piece, aimed to
    /// stop just inside merge range. Anything in the way still blocks them physically.
    private func callFriends(of node: NogginNode) {
        let mergeDistance = 2 * node.radius + tuning.gaps.gap(for: node.kind.tier)
        for friend in pieces where friend !== node && friend.kind == node.kind && !friend.isMerging && !friend.isAsleep {
            guard let body = friend.physicsBody else { continue }
            let offset = node.position - friend.position
            let distance = offset.length
            guard distance > mergeDistance - tuning.gaps.gap(for: node.kind.tier) * 0.5, distance < mergeDistance * 2 else { continue }
            // Travel needed to end half a gap from the new piece's edge; speed from v² = 2·friction·d,
            // padded for drag.
            let travel = distance - (2 * node.radius + tuning.gaps.gap(for: node.kind.tier) * 0.5)
            let speed = sqrt(2 * rolling.friction * travel) * 1.15
            body.velocity = offset.normalized * speed
            friend.squish(0.3)
        }
    }

    /// Bones get eaten and Bulldogs trot off at the end of the turn, so neither can foul.
    private func sendVisitorsHome() {
        for node in pieces where node.kind.isVisitor {
            node.isMerging = true
            node.physicsBody = nil
            if node.kind.special == .bone {
                Effects.floatingText("Chomp!", at: node.position + CGVector(dx: 0, dy: 26), color: .white, size: 20, in: fxLayer)
                sound.play(.chomp)
                Effects.dust(at: node.position, intensity: 0.6, color: UIColor(hex: 0xF6EBD5), in: fxLayer)
                node.run(.group([.scale(to: 0.2, duration: 0.3), .fadeOut(withDuration: 0.3)]))
            } else {
                let exitX = node.position.x < lawnRect.midX ? lawnRect.minX - 60 : lawnRect.maxX + 60
                let trot = SKAction.move(to: CGPoint(x: exitX, y: node.position.y), duration: 0.6)
                trot.timingMode = .easeIn
                let bob = SKAction.repeat(.sequence([.moveBy(x: 0, y: 5, duration: 0.08), .moveBy(x: 0, y: -5, duration: 0.08)]), count: 4)
                node.run(.group([trot, bob, .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.25)])]))
            }
            after(0.6) { [weak self] in self?.remove(node) }
        }
    }

    private func endTurn() {
        #if DEBUG
        debugLogTurn()
        #endif
        sendVisitorsHome()
        boneLure = nil
        // After a slow-motion landing, wait for the camera to glide back before the next throw.
        let cameraReturning = dramaActive || cameraNode.xScale < 0.999
        endDrama(animated: true)
        model.throwEnded()
        putBoredDogsToSleep()
        let fouled = pieces.filter { $0.position.y < foulY && !$0.isMerging }
        var gameEnds = false
        setWind(.zero)
        if !fouled.isEmpty {
            for node in fouled {
                node.isMerging = true
                node.physicsBody = nil
                node.art.color = .red
                node.art.colorBlendFactor = 0.5
                node.run(.group([.fadeOut(withDuration: 0.35), .scale(to: 0.6, duration: 0.35)]))
            }
            after(0.35) { [weak self] in
                for node in fouled { self?.remove(node) }
            }
            gameEnds = model.recordFoul()
            Effects.floatingText("Foul!", at: CGPoint(x: anchor.x, y: foulY + 30), color: UIColor(hex: 0xFF5A6E), size: 30, in: fxLayer)
            sound.play(.foul)
            notifyHaptic.notificationOccurred(.error)
        }
        if gameEnds {
            phase = .gameOver
            SaveStore.clear()
            after(0.7) { [weak self] in self?.model.finish() }
            #if DEBUG
            if autoplay { after(1.5) { [weak self] in print("[game] over"); self?.startRound() } }
            #endif
        } else if whistleTurn, loaded != nil {
            // A Whistle call is over: back to aiming with the same Noggin.
            whistleTurn = false
            phase = .aiming
        } else {
            whistleTurn = false
            phase = .resolving
            let strayArrives = maybeSendStray()
            after(fouled.isEmpty && !cameraReturning && !strayArrives ? 0.05 : 0.6) { [weak self] in self?.loadNext() }
        }
        model.lonelyBreeds = lonelyBreeds()
    }

    /// A Noggin that hasn't merged in `boredTurns` turns falls asleep: heavy, unmergeable, in the
    /// way, until a hard hit wakes it.
    private func putBoredDogsToSleep() {
        let limit = Int(tuning.boredTurns)
        for node in pieces where !node.isMerging && !node.kind.isVisitor && !node.isAsleep && node.physicsBody != nil {
            node.idleTurns += 1
            guard limit > 0, node.idleTurns >= limit else { continue }
            node.fallAsleep()
            #if DEBUG
            if autoplay { print("[event] asleep") }
            #endif
            Effects.floatingText("Zzz…", at: node.position + CGVector(dx: 0, dy: node.radius + 14), color: .white, size: 16, in: fxLayer)
        }
    }

    /// Every few throws (sooner as the score grows) a stray Pup trots onto the lawn by itself.
    /// Returns whether one is on its way.
    private func maybeSendStray() -> Bool {
        throwsSinceStray += 1
        let interval = Pressure.strayInterval(score: model.score, base: tuning.strayEvery)
        guard interval > 0, throwsSinceStray >= interval else { return false }
        throwsSinceStray = 0
        let kind = NogginKind(breed: model.availableBreeds.randomElement() ?? .stray, tier: .pup)
        #if DEBUG
        if autoplay { print("[event] stray") }
        #endif
        guard let spot = openSpot(radius: kind.radius) else { return false }
        let node = NogginNode(kind: kind)
        let fromLeft = Bool.random()
        node.position = CGPoint(x: fromLeft ? lawnRect.minX - 40 : lawnRect.maxX + 40, y: spot.y)
        add(node)
        let trot = SKAction.move(to: spot, duration: 0.6)
        trot.timingMode = .easeOut
        let bob = SKAction.repeat(.sequence([.moveBy(x: 0, y: 5, duration: 0.075), .moveBy(x: 0, y: -5, duration: 0.075)]), count: 4)
        node.run(.group([trot, bob]))
        Effects.floatingText("A stray wanders in!", at: CGPoint(x: spot.x, y: spot.y + 40), color: .white, size: 18, in: fxLayer)
        sound.play(.bark, volume: 0.7, pitch: Float.random(in: 1.05...1.25))
        after(0.6) { [weak self] in
            guard let self, node.parent != nil else { return }
            node.activatePhysics(velocity: .zero, spin: 0, bounce: self.tuning.nogginBounce)
            node.trail = Effects.grassTrail(in: self.shadowLayer)
            self.pieces.append(node)
        }
        return true
    }

    /// A free spot between the foul line and the top of the lawn, clear of other pieces and rocks.
    private func openSpot(radius: CGFloat) -> CGPoint? {
        for _ in 0..<30 {
            let point = CGPoint(x: .random(in: (lawnRect.minX + radius + 10)...(lawnRect.maxX - radius - 10)),
                                y: .random(in: (foulY + radius + 50)...(upperY - radius - 20)))
            let clear = pieces.allSatisfy { $0.position.distance(to: point) > $0.radius + radius + 12 }
                && features.rocks.allSatisfy { $0.center.distance(to: point) > $0.radius + radius + 12 }
            if clear { return point }
        }
        return nil
    }

    /// From the sixth throw, some turns bring a gust: the wind arrow and leaves show it, and it
    /// pushes every moving Noggin (and the aim line) for the whole turn.
    private func rollGust() {
        guard model.throwsMade >= 5, CGFloat.random(in: 0..<1) < tuning.gustChance else { return }
        let angle = (Bool.random() ? 0 : CGFloat.pi) + .random(in: -0.5...0.5)
        let strength = tuning.gustStrength * .random(in: 0.6...1.3)
        setWind(CGVector(dx: cos(angle) * strength, dy: sin(angle) * strength))
        #if DEBUG
        if autoplay { print("[event] gust") }
        #endif
        sound.play(.whoosh, volume: 0.7)
    }

    private func setWind(_ wind: CGVector) {
        baseFeatures.wind = wind
        features.wind = wind
        if wind == .zero {
            windIndicator?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            windIndicator = nil
            windLeaves?.particleBirthRate = 0
            return
        }
        if windIndicator == nil {
            let indicator = Effects.windIndicator()
            indicator.position = CGPoint(x: lawnRect.midX, y: upperY - 34)
            indicator.zPosition = 4
            indicator.alpha = 0
            indicator.run(.fadeIn(withDuration: 0.3))
            aimLayer.addChild(indicator)
            windIndicator = indicator
        }
        let angle = atan2(wind.dy, wind.dx)
        if let arrow = windIndicator?.childNode(withName: "arrow") {
            arrow.zRotation = angle
            arrow.setScale(0.7 + wind.length / 200)
            arrow.run(.repeatForever(.sequence([.moveBy(x: cos(angle) * 6, y: sin(angle) * 6, duration: 0.4),
                                                .moveBy(x: -cos(angle) * 6, y: -sin(angle) * 6, duration: 0.4)])), withKey: "sway")
        }
        if windLeaves == nil { windLeaves = Effects.windLeaves(across: lawnRect, in: fxLayer) }
        windLeaves?.emissionAngle = angle
        windLeaves?.particleSpeed = wind.length * 0.9
        windLeaves?.particleSpeedRange = wind.length * 0.3
        windLeaves?.particleBirthRate = 4 + wind.length / 30
    }

    /// A squirrel dashes across the upper lawn; dogs near its path chase it a short way.
    private func squirrelDash() {
        guard phase == .aiming, dragStart == nil, !squirrelRunning else { return }
        squirrelRunning = true
        #if DEBUG
        if autoplay { print("[event] squirrel") }
        #endif
        let y = CGFloat.random(in: (foulY + 90)...(upperY - 40))
        let leftToRight = Bool.random()
        let start = CGPoint(x: leftToRight ? lawnRect.minX - 40 : lawnRect.maxX + 40, y: y)
        let end = CGPoint(x: leftToRight ? lawnRect.maxX + 40 : lawnRect.minX - 40, y: y)
        let squirrel = Effects.squirrel()
        squirrel.position = start
        squirrel.xScale = leftToRight ? 1 : -1
        squirrel.zPosition = 4
        aimLayer.addChild(squirrel)
        let duration: TimeInterval = 1.3
        let hop = SKAction.repeat(.sequence([.moveBy(x: 0, y: 8, duration: 0.08), .moveBy(x: 0, y: -8, duration: 0.08)]), count: 8)
        squirrel.run(.sequence([.group([.move(to: end, duration: duration), hop]), .removeFromParent()]))
        sound.play(.squeak)

        let direction = CGVector(dx: leftToRight ? 1 : -1, dy: 0)
        for node in pieces where !node.isMerging && !node.kind.isVisitor && !node.isAsleep && node.physicsBody != nil {
            guard abs(node.position.y - y) < 110 else { continue }
            // Each dog bolts as the squirrel passes it.
            let progress = (node.position.x - start.x) / (end.x - start.x)
            after(duration * TimeInterval(min(max(progress, 0), 1))) { [weak self] in
                guard let self, let body = node.physicsBody, !node.isMerging else { return }
                let towardPath = CGVector(dx: 0, dy: (y - node.position.y) * 0.8)
                body.velocity += direction * .random(in: 180...300) + towardPath
                node.react(.happy, for: 0.7)
                if Bool.random() { self.sound.play(.bark, volume: 0.5, pitch: .random(in: 0.95...1.25)) }
            }
        }
        after(duration + 0.1) { [weak self] in self?.squirrelRunning = false }
    }

    /// Breeds with a Pup on the lawn that has no partner of its kind anywhere.
    private func lonelyBreeds() -> [Breed] {
        let pups = pieces.filter { !$0.isMerging && !$0.isAsleep && $0.kind.special == nil && $0.kind.tier == .pup }
        let counts = Dictionary(grouping: pups, by: \.kind.breed).mapValues(\.count)
        return counts.filter { $0.value == 1 }.map(\.key)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let realDt = lastUpdate == 0 ? 1.0 / 60.0 : min(1.0 / 30.0, currentTime - lastUpdate)
        lastUpdate = currentTime
        // Game time runs slower during the last-chance slow motion.
        let dt = realDt * TimeInterval(timeScale)
        clock += dt
        runScheduled()
        slingshot.update(dt: CGFloat(realDt))
        updateBoneLure(dt: dt)
        if appliedTuning != tuning { applyTuning() }

        // Rolling physics runs in fixed 1/120 s steps so throws behave the same at any frame rate.
        rollingDebt += CGFloat(dt)
        let steps = Int(rollingDebt / rollingStep)
        rollingDebt -= CGFloat(steps) * rollingStep
        for node in pieces {
            guard let body = node.physicsBody else { continue }
            var velocity = body.velocity
            var spin = body.angularVelocity
            let surface = features.surface(at: node.position)
            let push = node.kind.isVisitor ? .zero : features.push(at: node.position)
            for _ in 0..<steps {
                rolling.step(velocity: &velocity, spin: &spin, dt: rollingStep, surface: surface, push: push)
            }
            body.velocity = velocity
            body.angularVelocity = spin
            node.lastVelocity = velocity
        }

        updateTrails(dt: dt)
        updateDrama()
        sinceMoodCheck += realDt
        if sinceMoodCheck >= 0.3 {
            sinceMoodCheck = 0
            updateMoods()
            updateHints()
        }

        // Safety net for anything that escapes the hedge.
        for node in pieces where !lawnRect.insetBy(dx: -40, dy: -40).contains(node.position) {
            remove(node)
        }

        if let node = thrown, node.isMystery, let body = node.physicsBody, body.velocity.length < 160 {
            revealMystery(node)
        }
        if let deadline = model.chainDeadline, Date() > deadline {
            model.chain = 0
            model.chainDeadline = nil
        }
        updateShakeOffs()

        if phase == .rolling || phase == .aiming {
            // Matching pieces that bump merge at once; slow pieces merge as soon as they meet. This
            // also runs while aiming, so idle scoots can complete merges.
            if !pendingContacts.isEmpty {
                let touching = pendingContacts
                pendingContacts.removeAll()
                mergeCheck(maxSpeed: tuning.mergeSpeed, touching: touching)
            }
            sinceMergeCheck += dt
            if sinceMergeCheck >= mergeCheckInterval {
                sinceMergeCheck = 0
                mergeCheck(maxSpeed: tuning.mergeSpeed)
            }
        }
        if phase == .aiming { updateScoots(dt: dt) }

        if phase == .rolling {
            // The turn ends only when nothing moves, no merge is animating, and a full check finds nothing.
            if activeMerges == 0, isLawnStill() {
                stillTime += dt
                if stillTime > 0.25 {
                    stillTime = 0
                    if !mergeCheck(maxSpeed: .infinity) { endTurn() }
                }
            } else {
                stillTime = 0
            }
        }
    }

    private func revealMystery(_ node: NogginNode) {
        guard node.isMystery else { return }
        node.revealMystery()
        #if DEBUG
        if autoplay { print("[event] mystery") }
        #endif
        Effects.floatingText("It's a \(node.kind.breed.displayName)!", at: node.position + CGVector(dx: 0, dy: node.radius + 18),
                             color: .white, size: 18, in: fxLayer)
        Effects.dust(at: node.position, intensity: 0.5, color: .white, in: fxLayer)
    }

    /// A Noggin that crossed a puddle shakes itself dry when it comes to rest, nudging nearby
    /// pieces toward their matches.
    private func updateShakeOffs() {
        for node in pieces where node.isWet && !node.isMerging {
            guard let body = node.physicsBody, body.velocity.length < 15 else { continue }
            node.isWet = false
            node.react(.happy, for: 0.6)
            let shake = SKAction.sequence([.rotate(byAngle: 0.25, duration: 0.05), .rotate(byAngle: -0.5, duration: 0.08),
                                           .rotate(byAngle: 0.4, duration: 0.07), .rotate(byAngle: -0.15, duration: 0.05)])
            node.art.run(shake, withKey: "wobble")
            Effects.droplets(at: node.position, radius: node.radius, in: fxLayer)
            sound.play(.splash, volume: 0.6, pitch: 1.3)
            shockwave(at: node.position, reach: tuning.shakeReach, strength: 0, sparing: nil,
                      steerOnly: true, excluding: node, showRing: false)
            stillTime = 0
        }
    }

    /// While aiming, now and then an idle Noggin scoots: toward a match just out of reach (which can
    /// merge it right there), or a little shuffle on its own.
    private func updateScoots(dt: TimeInterval) {
        guard tuning.scootInterval > 0, activeMerges == 0, dragStart == nil else { return }
        sinceScoot += dt
        guard sinceScoot >= nextScoot else { return }
        sinceScoot = 0
        nextScoot = TimeInterval(tuning.scootInterval) * .random(in: 0.7...1.3)

        let idle = pieces.filter { node in
            guard !node.isMerging, !node.kind.isVisitor, !node.isAsleep, let body = node.physicsBody else { return false }
            return body.velocity.length < rolling.restSpeed && node.position.y > foulY + node.radius + 20
        }
        var best: (mover: NogginNode, partner: NogginNode, gap: CGFloat)?
        for (i, a) in idle.enumerated() {
            for b in idle.dropFirst(i + 1) where Self.couldMerge(a.kind, b.kind) {
                let reach = min(tuning.gaps.gap(for: a.kind.tier), tuning.gaps.gap(for: b.kind.tier))
                let gap = a.position.distance(to: b.position) - a.radius - b.radius
                guard gap > reach, gap <= reach + tuning.magnetRange else { continue }
                if best == nil || gap < best!.gap {
                    // The one farther from the foul line moves, so nobody scoots into it.
                    best = a.position.y > b.position.y ? (a, b, gap) : (b, a, gap)
                }
            }
        }
        if let best {
            let reach = tuning.gaps.gap(for: best.mover.kind.tier)
            scoot(best.mover, toward: best.partner.position, distance: best.gap - reach * 0.4)
            best.mover.react(.happy, for: 0.6)
            sound.play(.tick, volume: 0.35, pitch: 1.6)
        } else if let wanderer = idle.randomElement(), Bool.random() {
            // A small sniff around, drifting toward the middle of the lawn rather than the foul line.
            let center = features.bowl?.center ?? CGPoint(x: lawnRect.midX, y: lawnRect.midY)
            let direction = ((center - wanderer.position).normalized + CGVector(dx: .random(in: -1...1), dy: .random(in: -0.6...1))).normalized
            scoot(wanderer, toward: wanderer.position + direction * 40, distance: .random(in: 8...20))
        }
    }

    private func scoot(_ node: NogginNode, toward target: CGPoint, distance: CGFloat) {
        guard let body = node.physicsBody, distance > 1 else { return }
        let friction = rolling.friction * features.surface(at: node.position).friction
        body.velocity = (target - node.position).normalized * (sqrt(2 * friction * distance) * 1.08)
        node.squish(0.25)
    }

    /// Spends a Whistle: every Noggin within reach of `point` runs to it. The lawn then settles
    /// like a turn, but the loaded Noggin stays in the slingshot.
    private func blowWhistle(at point: CGPoint) {
        model.useWhistle()
        sound.play(.whistle)
        Effects.shockRing(at: point, radius: 60, in: fxLayer)
        Effects.shockRing(at: point, radius: 140, in: fxLayer)
        Effects.floatingText("Here, pups!", at: point + CGVector(dx: 0, dy: 40), color: .white, size: 22, in: fxLayer)
        heavyHaptic.impactOccurred(intensity: 0.6)
        for node in pieces where !node.isMerging && !node.kind.isVisitor {
            guard node.physicsBody != nil else { continue }
            let distance = node.position.distance(to: point)
            guard distance < 240 else { continue }
            scoot(node, toward: point, distance: max(0, distance - node.radius - 12))
            node.react(.happy, for: 0.8)
        }
        whistleTurn = true
        stillTime = 0
        phase = .rolling
    }

    /// Pushes tuning-panel changes into bodies that already exist.
    private func applyTuning() {
        appliedTuning = tuning
        walls.physicsBody?.restitution = tuning.hedgeBounce
        for node in featureLayer.children where node.physicsBody != nil {
            node.physicsBody?.restitution = tuning.rockBounce
        }
        for node in pieces where node.kind.special != .bulldog {
            node.physicsBody?.restitution = tuning.nogginBounce
        }
        features = baseFeatures.with(sand: tuning.sand, puddle: tuning.puddle, bowlStrength: tuning.bowl)
    }

    /// Grass flecks behind fast rolls, and skid marks where a Noggin curves hard.
    private func updateTrails(dt: TimeInterval) {
        for node in pieces {
            guard let trail = node.trail else { continue }
            guard let body = node.physicsBody else {
                trail.particleBirthRate = 0
                continue
            }
            let velocity = body.velocity
            let speed = velocity.length
            trail.position = node.position + velocity.normalized * -node.radius * 0.8
            trail.emissionAngle = atan2(-velocity.dy, -velocity.dx)
            let ground = features.ground(at: node.position)
            trail.particleBirthRate = speed > 220 && ground != .puddle ? min(90, (speed - 220) * 0.12) : 0
            trail.particleSpeed = 40 + speed * 0.08
            trail.particleColor = ground == .sand ? UIColor(hex: 0xD9B86A) : UIColor(hex: 0x3E8E3C)
            if ground == .puddle, speed > rolling.restSpeed { node.isWet = true }
            if ground == .puddle, speed > 40, clock - node.lastSkid > 0.14 {
                node.lastSkid = clock
                Effects.ripple(at: node.position, radius: node.radius, in: marksLayer)
                if speed > 160 { sound.play(.splash, volume: Float(min(1, speed / 600)), pitch: Float.random(in: 0.9...1.15)) }
            }

            if abs(body.angularVelocity) > 3.5, speed > 120, clock - node.lastSkid > 0.035 {
                node.lastSkid = clock
                Effects.skidMark(at: node.position, radius: node.radius, in: marksLayer)
            }
        }
    }

    /// Resting Noggins look happy while a match of theirs is close by.
    private func updateMoods() {
        let resting = pieces.filter { !$0.isMerging && $0.physicsBody != nil && !$0.kind.isVisitor && !$0.isAsleep }
        for node in resting {
            let reach = (2 * node.radius + tuning.gaps.gap(for: node.kind.tier)) * 1.8
            let friendNearby = resting.contains { other in
                other !== node && other.position.distance(to: node.position) < reach && Self.couldMerge(node.kind, other.kind)
            }
            node.mood = friendNearby ? .happy : .calm
        }
    }

    /// Same kind, or a Wild Pup with any ordinary Pup.
    private static func couldMerge(_ a: NogginKind, _ b: NogginKind) -> Bool {
        if a.isWild || b.isWild {
            let other = a.isWild ? b : a
            return other.special == nil && other.tier == .pup
        }
        return a.special == nil && a == b
    }

    /// While aiming, a pulsing dotted line joins matching pairs that are close but not yet close enough.
    private func updateHints() {
        var pairs: [(CGPoint, CGPoint, CGFloat)] = []
        if phase == .aiming {
            let resting = pieces.filter { !$0.isMerging && $0.physicsBody != nil && !$0.kind.isVisitor && !$0.isAsleep }
            for (i, a) in resting.enumerated() {
                for b in resting.dropFirst(i + 1) where Self.couldMerge(a.kind, b.kind) {
                    let offset = b.position - a.position
                    let gap = offset.length - a.radius - b.radius
                    let sandBonus = features.isSand(at: a.position) || features.isSand(at: b.position) ? tuning.sandGapBonus : 0
                    let mergeGap = min(tuning.gaps.gap(for: a.kind.tier), tuning.gaps.gap(for: b.kind.tier)) + sandBonus
                    guard gap > mergeGap, gap <= mergeGap + 55 else { continue }
                    let direction = offset.normalized
                    pairs.append((a.position + direction * a.radius, b.position + direction * -b.radius, gap))
                }
            }
            pairs.sort { $0.2 < $1.2 }
        }
        while hintLines.count < min(pairs.count, 6) {
            let line = SKShapeNode()
            line.strokeColor = .white
            line.lineWidth = 6
            line.lineCap = .round
            line.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
            hintLayer.addChild(line)
            hintLines.append(line)
        }
        for (i, line) in hintLines.enumerated() {
            guard i < min(pairs.count, 6) else {
                line.isHidden = true
                continue
            }
            let path = CGMutablePath()
            path.move(to: pairs[i].0)
            path.addLine(to: pairs[i].1)
            line.path = path.copy(dashingWithPhase: 0, lengths: [1, 9])
            line.isHidden = false
        }
    }

    /// After a thrown Bone comes to rest, nearby Noggins rush toward it for a moment.
    private func updateBoneLure(dt: TimeInterval) {
        if boneLure == nil, let bone = thrown, bone.kind.special == .bone, phase == .rolling,
           let body = bone.physicsBody, body.velocity.length < 60, !bone.isMerging {
            boneLure = (bone, clock + 1.6)
            Effects.floatingText("Fetch!", at: bone.position + CGVector(dx: 0, dy: 30), color: .white, size: 22, in: fxLayer)
            sound.play(.bark, volume: 0.8)
            Effects.shockRing(at: bone.position, radius: 170, in: fxLayer)
            thrown = nil
        }
        guard let lure = boneLure, clock < lure.until else { return }
        let reach: CGFloat = 180
        for node in pieces where node !== lure.bone && !node.isMerging && !node.kind.isVisitor {
            guard let body = node.physicsBody else { continue }
            let offset = lure.bone.position - node.position
            let distance = offset.length
            guard distance < reach, distance > node.radius + lure.bone.radius + 4 else { continue }
            let pull = (300 + 500 * (1 - distance / reach)) * tuning.bonePull
            body.velocity += offset.normalized * (pull * CGFloat(dt))
            node.mood = .happy
        }
    }

    /// Slow motion and a zoom on the last-chance throw as it comes in to land.
    private func updateDrama() {
        guard let node = thrown, let body = node.physicsBody else {
            if dramaActive { endDrama(animated: true) }
            return
        }
        let speed = body.velocity.length
        if dramaArmed, !dramaActive, phase == .rolling, speed < 300, speed > rolling.restSpeed {
            dramaArmed = false
            dramaActive = true
            dramaEnds = clock + 0.9
            timeScale = 0.4
            physicsWorld.speed = 0.4
            let zoom = SKAction.scale(to: 0.82, duration: 0.35)
            zoom.timingMode = .easeOut
            cameraNode.run(zoom, withKey: "zoom")
            Effects.floatingText("…", at: node.position + CGVector(dx: 0, dy: 36), color: .white, size: 26, in: fxLayer)
        }
        if dramaActive {
            let target = cameraTarget(following: node.position)
            cameraNode.position = cameraNode.position + (target - cameraNode.position) * 0.12
            if speed <= rolling.restSpeed || clock > dramaEnds { endDrama(animated: true) }
        }
    }

    private func cameraTarget(following point: CGPoint) -> CGPoint {
        let halfW = size.width * cameraNode.xScale / 2, halfH = size.height * cameraNode.yScale / 2
        return CGPoint(x: min(max(point.x, halfW), size.width - halfW), y: min(max(point.y, halfH), size.height - halfH))
    }

    private func endDrama(animated: Bool) {
        dramaArmed = false
        guard dramaActive || cameraNode.xScale != 1 else { return }
        dramaActive = false
        timeScale = 1
        physicsWorld.speed = 1
        cameraNode.removeAction(forKey: "zoom")
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if animated {
            let back = SKAction.group([.scale(to: 1, duration: 0.45), .move(to: center, duration: 0.45)])
            back.timingMode = .easeInEaseOut
            cameraNode.run(back, withKey: "zoom")
        } else {
            cameraNode.setScale(1)
            cameraNode.position = center
        }
    }

    override func didFinishUpdate() {
        for case let node as NogginNode in pieceLayer.children {
            node.shadow.position = node.position + CGVector(dx: 2.5, dy: -4)
            node.shadow.setScale(node.xScale)
            node.shadow.alpha = node.alpha
        }
    }

    private func isLawnStill() -> Bool {
        pieces.allSatisfy { node in
            guard let body = node.physicsBody else { return true }
            return body.velocity.length < rolling.restSpeed && abs(body.angularVelocity) < 0.5
        }
    }

    private func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        scheduled.append((clock + delay, action))
    }

    private func runScheduled() {
        let due = scheduled.filter { $0.time <= clock }
        guard !due.isEmpty else { return }
        scheduled.removeAll { $0.time <= clock }
        for item in due { item.action() }
    }

    private func add(_ node: NogginNode) {
        pieceLayer.addChild(node)
        shadowLayer.addChild(node.shadow)
    }

    private func remove(_ node: NogginNode) {
        pieces.removeAll { $0 === node }
        node.removeFromParent()
        node.shadow.removeFromParent()
        node.trail?.particleBirthRate = 0
        if let trail = node.trail {
            trail.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
        }
    }

    // MARK: - Aiming

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .aiming, loaded != nil, dragStart == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        if model.isWhistleArmed, model.whistles > 0, location.y > foulY + 30, lawnRect.contains(location) {
            blowWhistle(at: location)
            return
        }
        dragStart = touch.location(in: self)
        dragPath = [.zero]
        slingshot.beginHold()
        haptics.beginStretch()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = dragStart, let touch = touches.first else { return }
        let pull = Slingshot.clampedPull(touch.location(in: self) - start)
        // Coming back to rest starts a fresh path, so the curve reflects the latest pull.
        if pull.length < 6 {
            dragPath = [pull]
        } else {
            dragPath.append(pull)
            if dragPath.count > 90 { dragPath.removeFirst() }
        }
        let previous = slingshot.pull.length
        slingshot.setPull(pull)
        let stretch = pull.length / Slingshot.maxPull
        haptics.updateStretch(stretch)
        if Int(pull.length / 14) != Int(previous / 14) {
            haptics.tick(0.25 + 0.5 * stretch)
            sound.play(.tick, volume: 0.5, pitch: 0.8 + Float(stretch) * 0.7)
        }
        // A tight band makes the loaded Noggin nervous.
        loaded?.mood = stretch > 0.75 ? .nervous : .calm
        updateAim(pull)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragStart != nil else { return }
        dragStart = nil
        hideAim()
        let pull = slingshot.pull
        loaded?.mood = .calm
        if pull.length >= Slingshot.minPull {
            slingshot.fire(velocity: pull * (-Slingshot.launchScale * tuning.power), spin: spin(for: dragPath))
            haptics.snap()
            sound.play(.snap, volume: 0.6 + 0.4 * Float(pull.length / Slingshot.maxPull))
            phase = .resolving
        } else {
            haptics.endStretch()
            slingshot.release()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragStart != nil else { return }
        dragStart = nil
        hideAim()
        haptics.endStretch()
        loaded?.mood = .calm
        slingshot.release()
    }

    /// A pull that bows to one side curves the throw the opposite way.
    private func spin(for path: [CGVector]) -> CGFloat {
        CurveGesture.bend(of: path) * tuning.maxSpin
    }

    private func updateAim(_ pull: CGVector) {
        guard let loaded, pull.length >= Slingshot.minPull else {
            hideAim()
            return
        }
        let path = rolling.predictPath(
            from: anchor,
            velocity: pull * (-Slingshot.launchScale * tuning.power),
            spin: spin(for: dragPath),
            radius: loaded.radius,
            bounds: lawnRect,
            features: features
        )
        let stride = max(1, path.count / aimDots.count)
        for (i, dot) in aimDots.enumerated() {
            let index = (i + 1) * stride
            guard index < path.count - 1 else {
                dot.isHidden = true
                continue
            }
            dot.isHidden = false
            dot.position = path[index]
            dot.alpha = 0.9 - 0.6 * CGFloat(i) / CGFloat(aimDots.count)
        }
        guard let end = path.last else { return }
        aimRing.isHidden = false
        aimRing.position = end
        aimRing.setScale(loaded.radius)
        aimRing.strokeColor = !loaded.isMystery && completesGroup(loaded.kind, at: end) ? UIColor(hex: 0xFFC93C) : .white
    }

    private func completesGroup(_ kind: NogginKind, at point: CGPoint) -> Bool {
        var probe = pieces.filter { $0.physicsBody != nil && !$0.isAsleep }.enumerated().map { mergePiece($0.offset, $0.element) }
        let probeID = probe.count
        probe.append(MergePiece(id: probeID, kind: kind, position: point,
                                gapBonus: features.isSand(at: point) ? tuning.sandGapBonus : 0))
        return MergeEngine.groups(in: probe, gaps: tuning.gaps).contains { $0.ids.contains(probeID) }
    }

    private func hideAim() {
        for dot in aimDots { dot.isHidden = true }
        aimRing.isHidden = true
    }

    // MARK: - Building

    private func buildLawn() {
        let corner: CGFloat = 26
        let lawnPath = CGPath(roundedRect: lawnRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

        let mask = SKShapeNode(path: lawnPath)
        mask.fillColor = .white
        let crop = SKCropNode()
        crop.maskNode = mask
        let stripe: CGFloat = 48
        var y = lawnRect.minY
        var even = true
        while y < lawnRect.maxY {
            let band = SKSpriteNode(color: UIColor(hex: even ? 0x74C26F : 0x6BB866),
                                    size: CGSize(width: lawnRect.width, height: stripe))
            band.anchorPoint = .zero
            band.position = CGPoint(x: lawnRect.minX, y: y)
            crop.addChild(band)
            y += stripe
            even.toggle()
        }
        launchZone.size = CGSize(width: lawnRect.width, height: foulY - lawnRect.minY)
        launchZone.anchorPoint = .zero
        launchZone.position = CGPoint(x: lawnRect.minX, y: lawnRect.minY)
        crop.addChild(launchZone)
        addChild(crop)

        let foulPath = CGMutablePath()
        foulPath.move(to: CGPoint(x: lawnRect.minX + 6, y: 0))
        foulPath.addLine(to: CGPoint(x: lawnRect.maxX - 6, y: 0))
        foulLine.path = foulPath.copy(dashingWithPhase: 0, lengths: [12, 10])
        foulLine.position = CGPoint(x: 0, y: foulY)
        foulLine.strokeColor = UIColor(white: 1, alpha: 0.7)
        foulLine.lineWidth = 3
        foulLine.zPosition = 0.5
        addChild(foulLine)


        let hedgeRect = lawnRect.insetBy(dx: -5, dy: -5)
        let hedge = SKShapeNode(path: CGPath(roundedRect: hedgeRect, cornerWidth: corner + 5, cornerHeight: corner + 5, transform: nil))
        hedge.strokeColor = UIColor(hex: 0x2C6A34)
        hedge.lineWidth = 10
        hedge.fillColor = .clear
        hedge.zPosition = 0.6
        addChild(hedge)

        let body = SKPhysicsBody(edgeLoopFrom: lawnPath)
        body.restitution = tuning.hedgeBounce
        body.friction = 0.1
        body.categoryBitMask = PhysicsCategory.wall
        walls.physicsBody = body
        addChild(walls)
    }

    private func buildAimGuide() {
        for _ in 0..<26 {
            let dot = SKShapeNode(circleOfRadius: 3.5)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.isHidden = true
            aimLayer.addChild(dot)
            aimDots.append(dot)
        }
        // Unit circle scaled to the loaded Noggin's radius; keep the stroke readable at any scale.
        let ring = CGMutablePath()
        ring.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        aimRing.path = ring
        aimRing.lineWidth = 0.1
        aimRing.fillColor = UIColor(white: 1, alpha: 0.15)
        aimRing.isHidden = true
        aimLayer.addChild(aimRing)
    }
}

extension GameScene: @preconcurrency SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.node as? NogginNode
        let b = contact.bodyB.node as? NogginNode
        // Matching Noggins that bump merge on the next frame (bodies can't change mid-contact).
        for node in [a, b].compactMap({ $0 }) where node.isMystery { revealMystery(node) }
        if let a, let b, !a.isMerging, !b.isMerging, !a.isAsleep, !b.isAsleep, Self.couldMerge(a.kind, b.kind) {
            pendingContacts.insert(ObjectIdentifier(a))
            pendingContacts.insert(ObjectIdentifier(b))
        }
        let relative = (a?.lastVelocity ?? .zero) - (b?.lastVelocity ?? .zero)
        let closing = abs(relative.dot(contact.contactNormal))
        guard closing > 40 else { return }
        let intensity = min(1, closing / 700)
        for node in [a, b].compactMap({ $0 }) where !node.isMerging {
            if node.isAsleep {
                // Only a solid knock wakes a sleeper.
                if intensity > 0.5 {
                    node.wakeUp()
                    Effects.floatingText("Awake!", at: node.position + CGVector(dx: 0, dy: node.radius + 14), color: .white, size: 16, in: fxLayer)
                }
                continue
            }
            node.squish(intensity)
            // Big hits leave them dizzy; solid ones make them wince.
            if intensity > 0.8 {
                node.react(.dizzy, for: 1.2)
            } else if intensity > 0.45 {
                node.react(.wince, for: 0.35)
            }
        }
        let dustColor = (a != nil && b != nil) ? UIColor.white : UIColor(hex: 0x2C6A34)
        Effects.dust(at: contact.contactPoint, intensity: intensity, color: dustColor, in: fxLayer)
        if clock - lastHaptic > 0.06 {
            lastHaptic = clock
            haptics.thud(intensity, againstWall: a == nil || b == nil)
            // Bigger Noggins knock lower; harder hits are louder and a touch higher.
            let size = Float([a, b].compactMap { $0?.radius }.max() ?? Tier.pup.radius)
            let pitch = Float(Tier.pup.radius) / size * (0.9 + 0.25 * Float(intensity)) * Float.random(in: 0.94...1.06)
            sound.play(a == nil || b == nil ? .thud : .bonk, volume: 0.25 + 0.75 * Float(intensity), pitch: pitch)
        }
    }
}
