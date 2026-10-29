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
