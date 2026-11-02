import SpriteKit
import UIKit

enum Effects {
    private static let dot: SKTexture = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { _ in
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 16, height: 16)).fill()
    })

    private static let chip: SKTexture = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 10, height: 6)).image { _ in
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 10, height: 6)).fill()
    })

    /// A grass-fleck emitter that follows a rolling Noggin. The scene moves it, aims it behind the
    /// roll and sets its birth rate from the speed; it starts off.
    static func grassTrail(in layer: SKNode) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = chip
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 0.45
        emitter.particleLifetimeRange = 0.2
        emitter.particleSpeed = 70
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = 0.9
        emitter.particleScale = 0.55
        emitter.particleScaleRange = 0.25
        emitter.particleScaleSpeed = -0.6
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 5
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.6
        emitter.particleColor = UIColor(hex: 0x3E8E3C)
        emitter.particleColorBlendFactor = 1
        emitter.particleColorRedRange = 0.1
        emitter.particleColorGreenRange = 0.2
        emitter.targetNode = layer
        layer.addChild(emitter)
        return emitter
    }

    // MARK: Lawn features

    /// A sandy patch with a few darker grains. Grains are placed from the radius, not at random,
    /// so the same patch always looks the same.
    static func sandPatch(radius: CGFloat) -> SKNode {
        let patch = SKShapeNode(path: blobPath(radius: radius, wobble: 0.06, lobes: 7))
        patch.fillColor = UIColor(hex: 0xE2C887)
        patch.strokeColor = UIColor(hex: 0xC9AC66)
        patch.lineWidth = 3
        for i in 0..<12 {
            let angle = CGFloat(i) * 2.4
            let distance = radius * (0.2 + 0.6 * CGFloat((i * 7) % 10) / 10)
            let grain = SKShapeNode(circleOfRadius: 1.8 + CGFloat(i % 3) * 0.6)
            grain.fillColor = UIColor(hex: 0xC4A25A)
            grain.strokeColor = .clear
            grain.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            patch.addChild(grain)
        }
        return patch
    }

    /// A slick blue puddle with a shimmering highlight.
    static func puddle(radius: CGFloat) -> SKNode {
        let puddle = SKShapeNode(path: blobPath(radius: radius, wobble: 0.08, lobes: 5))
        puddle.fillColor = UIColor(hex: 0x73B9E6)
        puddle.strokeColor = UIColor(hex: 0x4E97CB)
        puddle.lineWidth = 3
        let shine = SKShapeNode(ellipseOf: CGSize(width: radius * 0.7, height: radius * 0.22))
        shine.fillColor = UIColor(white: 1, alpha: 0.5)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -radius * 0.25, y: radius * 0.38)
        shine.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 1.1), .fadeAlpha(to: 1, duration: 1.1)])))
        puddle.addChild(shine)
        return puddle
    }

    /// A grey boulder with an ink outline, a highlight and a shadow.
    static func rock(radius: CGFloat) -> SKNode {
        let rock = SKNode()
        let shadow = SKShapeNode(circleOfRadius: radius * 1.02)
        shadow.fillColor = UIColor(white: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -4)
        let stone = SKShapeNode(path: blobPath(radius: radius, wobble: 0.09, lobes: 4))
        stone.fillColor = UIColor(hex: 0x9A958F)
        stone.strokeColor = .ink
        stone.lineWidth = 3
        let highlight = SKShapeNode(ellipseOf: CGSize(width: radius * 0.8, height: radius * 0.4))
        highlight.fillColor = UIColor(white: 1, alpha: 0.35)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -radius * 0.2, y: radius * 0.35)
        rock.addChild(shadow)
        rock.addChild(stone)
        rock.addChild(highlight)
        return rock
    }

    /// Water flung off a Noggin shaking itself dry.
    static func droplets(at point: CGPoint, radius: CGFloat, in layer: SKNode) {
        let emitter = burst(texture: dot, count: 16, at: point)
        emitter.particleLifetime = 0.45
        emitter.particleLifetimeRange = 0.15
        emitter.particlePositionRange = CGVector(dx: radius, dy: radius)
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 60
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.15
        emitter.particleColor = UIColor(hex: 0x8ECDF2)
        layer.addChild(emitter)
    }

    /// A squirrel running to the right (flip `xScale` to face left), with a bushy tail.
    static func squirrel() -> SKNode {
        let squirrel = SKNode()
        let brown = UIColor(hex: 0xA0694A), light = UIColor(hex: 0xD6A27A)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -10, y: -4))
        tail.addCurve(to: CGPoint(x: -26, y: 22), control1: CGPoint(x: -34, y: -6), control2: CGPoint(x: -38, y: 14))
        tail.addCurve(to: CGPoint(x: -8, y: 6), control1: CGPoint(x: -16, y: 30), control2: CGPoint(x: -6, y: 18))
        tail.closeSubpath()
        let tailNode = SKShapeNode(path: tail)
        tailNode.fillColor = light
        tailNode.strokeColor = .ink
        tailNode.lineWidth = 2.5
        let body = SKShapeNode(ellipseOf: CGSize(width: 30, height: 18))
        body.fillColor = brown
        body.strokeColor = .ink
        body.lineWidth = 2.5
        let head = SKShapeNode(circleOfRadius: 8)
        head.position = CGPoint(x: 15, y: 6)
        head.fillColor = brown
        head.strokeColor = .ink
        head.lineWidth = 2.5
        let ear = SKShapeNode(path: { let p = CGMutablePath(); p.move(to: CGPoint(x: 11, y: 12)); p.addLine(to: CGPoint(x: 13, y: 20)); p.addLine(to: CGPoint(x: 17, y: 13)); p.closeSubpath(); return p }())
        ear.fillColor = brown
        ear.strokeColor = .ink
        ear.lineWidth = 2
        let eye = SKShapeNode(circleOfRadius: 1.8)
        eye.position = CGPoint(x: 18, y: 8)
        eye.fillColor = .ink
        eye.strokeColor = .clear
        for node in [tailNode, body, ear, head, eye] { squirrel.addChild(node) }
        tailNode.run(.repeatForever(.sequence([.rotate(byAngle: 0.2, duration: 0.1), .rotate(byAngle: -0.2, duration: 0.1)])))
        return squirrel
    }

    /// An arrow showing the gust's direction, sized by strength, with a "Wind" label.
    static func windIndicator() -> SKNode {
        let indicator = SKNode()
        let arrow = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -22, y: 0)); p.addLine(to: CGPoint(x: 14, y: 0))
            p.move(to: CGPoint(x: 6, y: 8)); p.addLine(to: CGPoint(x: 16, y: 0)); p.addLine(to: CGPoint(x: 6, y: -8))
            return p
        }())
        arrow.name = "arrow"
        arrow.strokeColor = .white
        arrow.lineWidth = 5
        arrow.lineCap = .round
        arrow.lineJoin = .round
        let label = SKLabelNode(text: "Wind")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 13
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -26)
        indicator.addChild(arrow)
        indicator.addChild(label)
        return indicator
    }

    /// Leaves drifting across the lawn with the wind. The scene aims and starts it.
    static func windLeaves(across lawn: CGRect, in layer: SKNode) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = chip
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 3.5
        emitter.particleLifetimeRange = 1
        emitter.particlePositionRange = CGVector(dx: lawn.width, dy: lawn.height)
        emitter.position = CGPoint(x: lawn.midX, y: lawn.midY)
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.2
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.4
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 2.5
        emitter.particleColor = UIColor(hex: 0xC9D46A)
        emitter.particleColorBlendFactor = 1
        emitter.particleColorGreenRange = 0.3
        emitter.targetNode = layer
        layer.addChild(emitter)
        return emitter
    }

    /// A ring that spreads out on a puddle where a Noggin slides through.
    static func ripple(at point: CGPoint, radius: CGFloat, in layer: SKNode) {
        let ring = SKShapeNode(circleOfRadius: radius * 0.6)
        ring.position = point
        ring.strokeColor = UIColor(white: 1, alpha: 0.7)
        ring.lineWidth = 2
        ring.fillColor = .clear
        let spread = SKAction.scale(to: 2, duration: 0.6)
        spread.timingMode = .easeOut
        ring.run(.sequence([.group([spread, .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        layer.addChild(ring)
    }

    /// A softly wobbly closed outline around a circle.
    private static func blobPath(radius: CGFloat, wobble: CGFloat, lobes: Int) -> CGPath {
        let path = CGMutablePath()
        let steps = 48
        for step in 0...steps {
            let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
            let r = radius * (1 + wobble * sin(angle * CGFloat(lobes) + 0.7))
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// A faint scuff on the grass that fades away, left by a hard-curving Noggin.
    static func skidMark(at point: CGPoint, radius: CGFloat, in layer: SKNode) {
        let mark = SKSpriteNode(texture: dot)
        mark.color = UIColor(hex: 0x2F6B33)
        mark.colorBlendFactor = 1
        mark.alpha = 0.35
        mark.size = CGSize(width: radius * 0.55, height: radius * 0.55)
        mark.position = point
        mark.run(.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 1.2), .removeFromParent()]))
        layer.addChild(mark)
    }

    /// Twinkles around a Top Dog's crown. Attach to the Noggin so they move with it.
    static func crownSparkles(radius: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dot
        emitter.particleBirthRate = 28
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.2
        emitter.particlePositionRange = CGVector(dx: radius * 1.1, dy: radius * 0.35)
        emitter.particleSpeed = 22
        emitter.particleSpeedRange = 12
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.particleScale = 0.28
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.4
        emitter.particleAlphaSpeed = -1.6
        emitter.particleColor = UIColor(hex: 0xFFF3B0)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.position = CGPoint(x: 0, y: radius * 1.15)
        emitter.zPosition = 1
        return emitter
    }

    static func dust(at point: CGPoint, intensity: CGFloat, color: UIColor, in layer: SKNode) {
        let emitter = burst(texture: dot, count: 4 + Int(8 * intensity), at: point)
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.2
        emitter.particleSpeed = 40 + 90 * intensity
        emitter.particleSpeedRange = 40
        emitter.particleAlpha = 0.75
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.4
        emitter.particleColor = color
        layer.addChild(emitter)
    }

    static func confetti(at point: CGPoint, colors: [UIColor], amount: Int, in layer: SKNode) {
        for color in colors {
            let emitter = burst(texture: chip, count: amount, at: point)
            emitter.particleLifetime = 0.9
            emitter.particleLifetimeRange = 0.3
            emitter.particleSpeed = 220
            emitter.particleSpeedRange = 120
            emitter.xAcceleration = 0
            emitter.particleAlphaSpeed = -1
            emitter.particleScale = 0.9
            emitter.particleScaleRange = 0.4
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = 6
            emitter.particleColor = color
            emitter.particleColorBlendFactor = 1
            layer.addChild(emitter)
        }
    }

    static func shockRing(at point: CGPoint, radius: CGFloat, in layer: SKNode) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = point
        ring.strokeColor = UIColor(white: 1, alpha: 0.8)
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.setScale(0.4)
        let grow = SKAction.scale(to: 1, duration: 0.3)
        grow.timingMode = .easeOut
        ring.run(.sequence([.group([grow, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        layer.addChild(ring)
    }

    static func popBurst(at point: CGPoint, in layer: SKNode) {
        let raw: [(CGFloat, CGFloat)] = [(50, 2), (59, 30), (88, 18), (72, 44), (98, 56), (68, 62), (78, 92),
                                         (50, 74), (22, 92), (32, 62), (2, 56), (28, 44), (12, 18), (41, 30)]
        let path = CGMutablePath()
        for (i, p) in raw.enumerated() {
            let point = CGPoint(x: (p.0 - 50) * 1.4, y: -(p.1 - 50) * 1.4)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.position = point
        star.fillColor = UIColor(hex: 0xFFC93C)
        star.strokeColor = .ink
        star.lineWidth = 3
        star.setScale(0.2)
        let grow = SKAction.scale(to: 1.3, duration: 0.35)
        grow.timingMode = .easeOut
        star.run(.sequence([
            .group([grow, .rotate(byAngle: 0.6, duration: 0.6)]),
            .group([.fadeOut(withDuration: 0.25), .scale(to: 1.5, duration: 0.25)]),
            .removeFromParent(),
        ]))
        layer.addChild(star)
    }

    static func floatingText(_ text: String, at point: CGPoint, color: UIColor, size: CGFloat, in layer: SKNode) {
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .strokeColor: UIColor.ink,
            .strokeWidth: -4,
        ])
        label.verticalAlignmentMode = .center
        label.position = point
        label.setScale(0.5)
        let pop = SKAction.scale(to: 1, duration: 0.15)
        pop.timingMode = .easeOut
        let rise = SKAction.moveBy(x: 0, y: 56, duration: 0.9)
        rise.timingMode = .easeOut
        label.run(.sequence([
            pop,
            .group([rise, .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
        layer.addChild(label)
    }

    private static func burst(texture: SKTexture, count: Int, at point: CGPoint) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = 4000
        emitter.emissionAngleRange = .pi * 2
        emitter.particleColorBlendFactor = 1
        emitter.position = point
        emitter.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
        return emitter
    }
}
