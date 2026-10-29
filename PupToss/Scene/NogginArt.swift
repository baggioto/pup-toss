import SpriteKit
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static let ink = UIColor(hex: 0x1F1A17)
}

/// Draws the dog heads in code (matching the design canvas) and caches them per kind and size.
/// Swap for hand-drawn artwork later behind the same two functions.
enum NogginArt {
    private static var textures: [NogginKind: SKTexture] = [:]
    private static var images: [String: UIImage] = [:]

    static func texture(for kind: NogginKind) -> SKTexture {
        if let cached = textures[kind] { return cached }
        let texture = SKTexture(image: image(for: kind, radius: kind.radius))
        textures[kind] = texture
        return texture
    }

    /// `radius` is the head circle's radius; ears and crown extend beyond it.
    static func image(for kind: NogginKind, radius: CGFloat) -> UIImage {
        let key = "\(kind.breed.rawValue)-\(kind.tier.rawValue)-\(radius)"
        if let cached = images[key] { return cached }
        // Art is authored in a 100-unit box with the head circle (r = 37) centred at (50, 58).
        let unit = radius / 37
        let side = ceil(132 * unit)
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            cg.translateBy(x: side / 2, y: side / 2)
            cg.scaleBy(x: unit, y: unit)
            cg.translateBy(x: -50, y: -58)
            draw(kind)
        }
        images[key] = image
        return image
    }

    static func colors(for breed: Breed) -> [UIColor] {
        let look = Look.of(breed)
        return [look.fur, look.earFill, .white]
    }

    private enum Ears { case pointy, floppy, fold }

    private struct Look {
        var fur: UIColor
        var muzzle: UIColor
        var inner: UIColor
        var earFill: UIColor
        var eye: UIColor
        var ears: Ears
        var spots = false
        var mask = false

        static func of(_ breed: Breed) -> Look {
            switch breed {
            case .shiba:
                Look(fur: UIColor(hex: 0xE8913A), muzzle: UIColor(hex: 0xFFF1DE), inner: UIColor(hex: 0xFFD2B0),
                     earFill: UIColor(hex: 0xE8913A), eye: .ink, ears: .pointy)
            case .pug:
                Look(fur: UIColor(hex: 0xE0C294), muzzle: UIColor(hex: 0x3A2A22), inner: UIColor(hex: 0x3A2A22),
                     earFill: UIColor(hex: 0x3A2A22), eye: .ink, ears: .fold)
            case .dalmatian:
                Look(fur: .white, muzzle: .white, inner: .white,
                     earFill: UIColor(hex: 0x2B2B2B), eye: .ink, ears: .floppy, spots: true)
            case .husky:
                Look(fur: UIColor(hex: 0x7D8A99), muzzle: .white, inner: UIColor(hex: 0xF4D9DF),
                     earFill: UIColor(hex: 0x7D8A99), eye: UIColor(hex: 0x2F8DE0), ears: .pointy, mask: true)
            }
        }
    }

    private static func draw(_ kind: NogginKind) {
        let look = Look.of(kind.breed)

        func paint(_ path: UIBezierPath, _ fill: UIColor?, stroke: CGFloat = 0) {
            if let fill {
                fill.setFill()
                path.fill()
            }
            if stroke > 0 {
                UIColor.ink.setStroke()
                path.lineWidth = stroke
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                path.stroke()
            }
        }

        func polygon(_ points: [(CGFloat, CGFloat)]) -> UIBezierPath {
            let path = UIBezierPath()
            for (i, p) in points.enumerated() {
                let point = CGPoint(x: p.0, y: p.1)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            return path
        }

        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> UIBezierPath {
            UIBezierPath(ovalIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        }

        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> UIBezierPath {
            ellipse(cx, cy, r, r)
        }

        switch look.ears {
        case .pointy:
            paint(polygon([(16, 44), (20, 6), (48, 28)]), look.fur, stroke: 3)
            paint(polygon([(84, 44), (80, 6), (52, 28)]), look.fur, stroke: 3)
            paint(polygon([(24, 36), (25, 17), (39, 29)]), look.inner)
            paint(polygon([(76, 36), (75, 17), (61, 29)]), look.inner)
        case .floppy:
            for (cx, degrees) in [(CGFloat(14), CGFloat(18)), (86, -18)] {
                let ear = UIBezierPath(ovalIn: CGRect(x: -12, y: -25, width: 24, height: 50))
                ear.apply(CGAffineTransform(rotationAngle: degrees * .pi / 180))
                ear.apply(CGAffineTransform(translationX: cx, y: 54))
                paint(ear, look.earFill, stroke: 3)
            }
        case .fold:
            paint(polygon([(18, 34), (34, 16), (40, 40)]), look.earFill, stroke: 3)
            paint(polygon([(82, 34), (66, 16), (60, 40)]), look.earFill, stroke: 3)
        }

        paint(circle(50, 58, 37), look.fur, stroke: 3)

        if look.spots {
            for (x, y, r) in [(CGFloat(30), CGFloat(40), CGFloat(5)), (69, 36, 4), (76, 62, 5), (23, 64, 3), (58, 28, 2.5)] {
                paint(circle(x, y, r), .ink)
            }
        }
        if look.mask {
            paint(polygon([(50, 34), (42, 56), (58, 56)]), .white)
            paint(ellipse(50, 72, 28, 20), .white)
        }

        paint(ellipse(50, 72, 20, 15), look.muzzle, stroke: 2)
        let blush = UIColor(hex: 0xFF8FA0, alpha: 0.55)
        paint(circle(27, 66, 5), blush)
        paint(circle(73, 66, 5), blush)
        paint(circle(36, 52, 5), look.eye)
        paint(circle(64, 52, 5), look.eye)
        paint(circle(37.6, 50.4, 1.7), .white)
        paint(circle(65.6, 50.4, 1.7), .white)
        paint(ellipse(50, 65, 7, 5), .ink)

        let mouth = UIBezierPath()
        mouth.move(to: CGPoint(x: 50, y: 69))
        mouth.addQuadCurve(to: CGPoint(x: 38, y: 72), controlPoint: CGPoint(x: 44, y: 77))
        mouth.move(to: CGPoint(x: 50, y: 69))
        mouth.addQuadCurve(to: CGPoint(x: 62, y: 72), controlPoint: CGPoint(x: 56, y: 77))
        paint(mouth, nil, stroke: 2.4)

        if kind.tier != .pup {
            let bandana = UIBezierPath()
            bandana.move(to: CGPoint(x: 24, y: 86))
            bandana.addQuadCurve(to: CGPoint(x: 76, y: 86), controlPoint: CGPoint(x: 50, y: 98))
            bandana.addLine(to: CGPoint(x: 50, y: 106))
            bandana.close()
            paint(bandana, UIColor(hex: 0x3D7BFF), stroke: 2.5)
            paint(circle(50, 96, 2.5), .white)
        }
        if kind.tier == .topDog {
            paint(polygon([(32, 24), (34, 4), (43, 14), (50, -2), (57, 14), (66, 4), (68, 24)]),
                  UIColor(hex: 0xFFC93C), stroke: 2.5)
            paint(circle(50, 16, 3), UIColor(hex: 0xFF5A6E))
        }
    }
}
