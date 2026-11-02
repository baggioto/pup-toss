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

/// Faces a Noggin can pull. Only the eyes and mouth change.
enum NogginExpression: String, CaseIterable {
    case normal, blink, happy, wince, dizzy
}

/// Draws the dog heads in code (matching the design canvas) and caches them per kind, size and
/// expression. Swap for hand-drawn artwork later behind the same two functions.
enum NogginArt {
    private struct TextureKey: Hashable {
        var kind: NogginKind
        var expression: NogginExpression
    }

    private static var textures: [TextureKey: SKTexture] = [:]
    private static var images: [String: UIImage] = [:]

    static func texture(for kind: NogginKind, expression: NogginExpression = .normal) -> SKTexture {
        let key = TextureKey(kind: kind, expression: expression)
        if let cached = textures[key] { return cached }
        let texture = SKTexture(image: image(for: kind, radius: kind.radius, expression: expression))
        textures[key] = texture
        return texture
    }

    /// `radius` is the head circle's radius; ears and crown extend beyond it.
    static func image(for kind: NogginKind, radius: CGFloat, expression: NogginExpression = .normal) -> UIImage {
        let key = "\(kind.special?.rawValue ?? kind.breed.rawValue)-\(kind.tier.rawValue)-\(radius)-\(expression.rawValue)"
        if let cached = images[key] { return cached }
        // Art is authored in a 100-unit box with the head circle (r = 37) centred at (50, 58).
        let unit = radius / 37
        let side = ceil(132 * unit)
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            cg.translateBy(x: side / 2, y: side / 2)
            cg.scaleBy(x: unit, y: unit)
            cg.translateBy(x: -50, y: -58)
            draw(kind, expression)
        }
        images[key] = image
        return image
    }

    private static var mysteryImages: [CGFloat: UIImage] = [:]
    private static var mysteryTextures: [CGFloat: SKTexture] = [:]

    /// A grey silhouette with a "?" for a Mystery Pup, sized like a Noggin of head `radius`.
    static func mysteryImage(radius: CGFloat) -> UIImage {
        if let cached = mysteryImages[radius] { return cached }
        let unit = radius / 37
        let side = ceil(132 * unit)
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            cg.translateBy(x: side / 2, y: side / 2)
            cg.scaleBy(x: unit, y: unit)
            cg.translateBy(x: -50, y: -58)
            let fill = UIColor(hex: 0xB9B3AD)
            for points in [[(16, 44), (20, 6), (48, 28)], [(84, 44), (80, 6), (52, 28)]] as [[(CGFloat, CGFloat)]] {
                let ear = UIBezierPath()
                for (i, p) in points.enumerated() {
                    if i == 0 { ear.move(to: CGPoint(x: p.0, y: p.1)) } else { ear.addLine(to: CGPoint(x: p.0, y: p.1)) }
                }
                ear.close()
                fill.setFill(); ear.fill()
                UIColor.ink.setStroke(); ear.lineWidth = 3; ear.lineJoinStyle = .round; ear.stroke()
            }
            let head = UIBezierPath(ovalIn: CGRect(x: 13, y: 21, width: 74, height: 74))
            fill.setFill(); head.fill()
            UIColor.ink.setStroke(); head.lineWidth = 3; head.stroke()
            let font = UIFont.systemFont(ofSize: 50, weight: .black)
            let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 50) } ?? font
            let mark = NSAttributedString(string: "?", attributes: [.font: rounded, .foregroundColor: UIColor.white,
                                                                     .strokeColor: UIColor.ink, .strokeWidth: -5])
            let size = mark.size()
            mark.draw(at: CGPoint(x: 50 - size.width / 2, y: 58 - size.height / 2))
        }
        mysteryImages[radius] = image
        return image
    }

    static func mysteryTexture(radius: CGFloat) -> SKTexture {
        if let cached = mysteryTextures[radius] { return cached }
        let texture = SKTexture(image: mysteryImage(radius: radius))
        mysteryTextures[radius] = texture
        return texture
    }

    /// A cream bone lying across the head's circle; it has no face.
    private static func drawBone() {
        let bone = UIBezierPath(roundedRect: CGRect(x: 22, y: 51, width: 56, height: 14), cornerRadius: 6)
        for (x, y) in [(CGFloat(20), CGFloat(50)), (20, 66), (80, 50), (80, 66)] {
            bone.append(UIBezierPath(ovalIn: CGRect(x: x - 10, y: y - 10, width: 20, height: 20)))
        }
        UIColor(hex: 0xF6EBD5).setFill()
        bone.fill()
        UIColor.ink.setStroke()
        bone.lineWidth = 3
        bone.stroke()
        // Re-fill the middle so the overlapping outlines read as one bone.
        UIColor(hex: 0xF6EBD5).setFill()
        UIBezierPath(roundedRect: CGRect(x: 21, y: 52.5, width: 58, height: 11), cornerRadius: 5).fill()
        for (x, y) in [(CGFloat(20), CGFloat(50)), (20, 66), (80, 50), (80, 66)] {
            UIBezierPath(ovalIn: CGRect(x: x - 8.5, y: y - 8.5, width: 17, height: 17)).fill()
        }
        UIColor(hex: 0xFFFFFF, alpha: 0.7).setFill()
        UIBezierPath(roundedRect: CGRect(x: 30, y: 54, width: 30, height: 3), cornerRadius: 1.5).fill()
    }

    static func colors(for breed: Breed) -> [UIColor] {
        let look = Look.of(breed)
        switch breed {
        case .stray: return [UIColor(hex: 0x8F8983), look.earFill, .white]
        case .iggy: return [UIColor(hex: 0xF2DE5C), look.fur, .white]
        default: return [look.fur, look.earFill, .white]
        }
    }

    /// `tipped`: ears that stand up and flop over at the tips, like a street dog's.
    /// `bat`: huge ears angled out to the sides, like a Boston Terrier's.
    private enum Ears { case pointy, floppy, fold, tipped, bat }

    private struct Look {
        var fur: UIColor
        var muzzle: UIColor
        var inner: UIColor
        var earFill: UIColor
        var eye: UIColor
        var ears: Ears
        var spots = false
        var mask = false
        /// Grey frosting on the lower muzzle.
        var chin: UIColor?
        /// White chest tuft peeking under the chin.
        var bib = false
        /// Dark pupils inside a coloured iris, for eyes that would vanish on dark fur.
        var pupils = false
        /// Pink cheeks; muddy on dark fur, so the Stray goes without.
        var blush = true
        /// White stripe from the forehead down to the muzzle.
        var blaze = false
        /// Heavy half-closed lids over white eyes with a coloured iris: an unimpressed look.
        var lids = false
        /// Open mouth with a row of little teeth instead of the smile.
        var grin = false
        /// Rainbow bands across the head (the Wild Pup).
        var rainbow = false
        /// Wide muzzle, forehead wrinkles and an underbite with two teeth (the Bulldog).
        var bulldog = false

        static func of(_ kind: NogginKind) -> Look {
            switch kind.special {
            case .wild:
                Look(fur: UIColor(hex: 0xF6B6C8), muzzle: .white, inner: UIColor(hex: 0xFFF3B0),
                     earFill: UIColor(hex: 0xB49BF2), eye: .ink, ears: .pointy, rainbow: true)
            case .bulldog:
                Look(fur: UIColor(hex: 0xC08E5E), muzzle: UIColor(hex: 0xF3E6D4), inner: UIColor(hex: 0x6B4A30),
                     earFill: UIColor(hex: 0x6B4A30), eye: .ink, ears: .fold, bulldog: true)
            case .bone, nil:
                of(kind.breed)
            }
        }

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
            case .stray:
                Look(fur: UIColor(hex: 0x2B2624), muzzle: UIColor(hex: 0x5E5853), inner: UIColor(hex: 0xC98B8F),
                     earFill: UIColor(hex: 0x2B2624), eye: UIColor(hex: 0x8A5A32), ears: .tipped,
                     chin: UIColor(hex: 0xA8A29B), bib: true, pupils: true, blush: false)
            case .iggy:
                Look(fur: UIColor(hex: 0x1F2624), muzzle: .white, inner: UIColor(hex: 0xF2DE5C),
                     earFill: UIColor(hex: 0x1F2624), eye: UIColor(hex: 0x7FC4E8), ears: .bat,
                     blush: false, blaze: true, lids: true, grin: true)
            }
        }
    }

    private static func draw(_ kind: NogginKind, _ expression: NogginExpression) {
        if kind.special == .bone {
            drawBone()
            return
        }
        let look = Look.of(kind)
        // Expression lines drawn on the fur need to be light on dark breeds.
        var brightness: CGFloat = 0
        look.fur.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        let faceLine = brightness < 0.3 ? UIColor(hex: 0xE8E2DC) : UIColor.ink
        let mouthColor = UIColor(hex: 0x5C1F2A)
        let tongue = UIColor(hex: 0xE07A8A)

        func paint(_ path: UIBezierPath, _ fill: UIColor?, stroke: CGFloat = 0, line: UIColor = .ink) {
            if let fill {
                fill.setFill()
                path.fill()
            }
            if stroke > 0 {
                line.setStroke()
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

        func openPolyline(_ points: [(CGFloat, CGFloat)]) -> UIBezierPath {
            let path = UIBezierPath()
            for (i, p) in points.enumerated() {
                let point = CGPoint(x: p.0, y: p.1)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            return path
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
        case .tipped:
            // Upright base, then the tip folds outward and down over a fold line.
            for mirror in [false, true] {
                func m(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
                    mirror ? points.map { (100 - $0.0, $0.1) } : points
                }
                paint(polygon(m([(12, 50), (9, 14), (31, 5), (47, 26)])), look.earFill, stroke: 3)
                paint(polygon(m([(19, 42), (17, 19), (29, 13), (39, 28)])), look.inner)
                // The flopped-over tip is its back side, a shade lighter so it reads against the head.
                paint(polygon(m([(9, 14), (31, 5), (1, 34)])), UIColor(hex: 0x4A4340), stroke: 3)
            }
        case .bat:
            for mirror in [false, true] {
                func m(_ points: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
                    mirror ? points.map { (100 - $0.0, $0.1) } : points
                }
                paint(polygon(m([(18, 48), (-8, 4), (46, 26)])), look.earFill, stroke: 3)
                paint(polygon(m([(19, 40), (0, 11), (38, 27)])), UIColor(hex: 0xB9AB34))
                paint(polygon(m([(20, 35), (6, 15), (32, 27)])), look.inner)
            }
        }

        paint(circle(50, 58, 37), look.fur, stroke: 3)

        if look.rainbow, let cg = UIGraphicsGetCurrentContext() {
            cg.saveGState()
            circle(50, 58, 35.5).addClip()
            let bands: [UInt32] = [0xFF8FA0, 0xFFB46B, 0xFFE27A, 0x9BE39A, 0x8EC5FF, 0xC3A6FF]
            for (i, color) in bands.enumerated() {
                let band = UIBezierPath(rect: CGRect(x: 0, y: 18 + CGFloat(i) * 13, width: 100, height: 13))
                band.apply(CGAffineTransform(translationX: -50, y: -58).concatenating(CGAffineTransform(rotationAngle: -0.35))
                    .concatenating(CGAffineTransform(translationX: 50, y: 58)))
                UIColor(hex: color).setFill()
                band.fill()
            }
            cg.restoreGState()
            paint(circle(50, 58, 37), nil, stroke: 3)
            // A little star on the forehead.
            var star: [(CGFloat, CGFloat)] = []
            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let r: CGFloat = i.isMultiple(of: 2) ? 6 : 2.6
                star.append((50 + cos(angle) * r, 34 + sin(angle) * r))
            }
            paint(polygon(star), .white, stroke: 1.5)
        }

        if look.bulldog {
            let wrinkles = UIBezierPath()
            for y in [CGFloat(33), 39] {
                wrinkles.move(to: CGPoint(x: 41, y: y))
                wrinkles.addQuadCurve(to: CGPoint(x: 59, y: y), controlPoint: CGPoint(x: 50, y: y - 4))
            }
            paint(wrinkles, nil, stroke: 2)
            // Droopy jowls behind the muzzle.
            paint(ellipse(36, 78, 13, 10), look.muzzle, stroke: 2)
            paint(ellipse(64, 78, 13, 10), look.muzzle, stroke: 2)
        }

        if look.spots {
            for (x, y, r) in [(CGFloat(30), CGFloat(40), CGFloat(5)), (69, 36, 4), (76, 62, 5), (23, 64, 3), (58, 28, 2.5)] {
                paint(circle(x, y, r), .ink)
            }
        }
        if look.mask {
            paint(polygon([(50, 34), (42, 56), (58, 56)]), .white)
            paint(ellipse(50, 72, 28, 20), .white)
        }

        if look.blaze {
            paint(polygon([(45, 23), (55, 23), (58, 60), (42, 60)]), .white)
        }

        if look.bib {
            paint(polygon([(37, 88), (43, 98), (50, 94), (57, 98), (63, 88), (50, 84)]), .white, stroke: 2)
        }

        paint(look.bulldog ? ellipse(50, 72, 23, 15) : ellipse(50, 72, 20, 15), look.muzzle, stroke: 2)
        if let chin = look.chin {
            paint(ellipse(50, 80, 12, 5.5), chin)
        }
        if look.blush {
            let blush = UIColor(hex: 0xFF8FA0, alpha: 0.55)
            paint(circle(27, 66, 5), blush)
            paint(circle(73, 66, 5), blush)
        }
        func drawGrin() {
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 39, y: 72))
            mouth.addQuadCurve(to: CGPoint(x: 61, y: 72), controlPoint: CGPoint(x: 50, y: 69))
            mouth.addQuadCurve(to: CGPoint(x: 39, y: 72), controlPoint: CGPoint(x: 50, y: 88))
            mouth.close()
            paint(mouth, mouthColor, stroke: 2)
            paint(ellipse(50, 80, 5, 2.4), tongue)
            var teeth: [(CGFloat, CGFloat)] = []
            for i in 0...10 {
                let x = 41 + CGFloat(i) * 1.8
                teeth.append((x, i.isMultiple(of: 2) ? 71.6 : 75))
            }
            teeth.append((59, 71.4))
            paint(polygon(teeth), .white)
        }

        func drawSmile() {
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 50, y: 69))
            mouth.addQuadCurve(to: CGPoint(x: 38, y: 72), controlPoint: CGPoint(x: 44, y: 77))
            mouth.move(to: CGPoint(x: 50, y: 69))
            mouth.addQuadCurve(to: CGPoint(x: 62, y: 72), controlPoint: CGPoint(x: 56, y: 77))
            paint(mouth, nil, stroke: 2.4)
        }

        // Eyes
        switch expression {
        case .normal:
            if look.lids {
                for cx in [CGFloat(35), 65] {
                    paint(circle(cx, 52, 6), .white, stroke: 1.5)
                    paint(circle(cx, 52.5, 3.4), look.eye)
                    paint(circle(cx, 52.5, 1.6), .ink)
                    // Top half of the eye covered by a heavy lid.
                    let lid = UIBezierPath(arcCenter: CGPoint(x: cx, y: 52), radius: 6.6, startAngle: .pi, endAngle: 2 * .pi, clockwise: true)
                    lid.addLine(to: CGPoint(x: cx - 6.6, y: 52))
                    lid.close()
                    paint(lid, look.fur, stroke: 2)
                    paint(circle(cx + 1.6, 54.4, 1), .white)
                }
            } else {
                paint(circle(36, 52, 5), look.eye)
                paint(circle(64, 52, 5), look.eye)
                if look.pupils {
                    paint(circle(36, 52, 2.9), .ink)
                    paint(circle(64, 52, 2.9), .ink)
                }
                paint(circle(37.6, 50.4, 1.7), .white)
                paint(circle(65.6, 50.4, 1.7), .white)
            }
        case .blink, .happy:
            // Closed lids curve down; happy eyes arch up.
            let bend: CGFloat = expression == .blink ? 4 : -7
            let baseline: CGFloat = expression == .blink ? 52 : 54
            for cx in [CGFloat(36), 64] {
                let eye = UIBezierPath()
                eye.move(to: CGPoint(x: cx - 5, y: baseline))
                eye.addQuadCurve(to: CGPoint(x: cx + 5, y: baseline), controlPoint: CGPoint(x: cx, y: baseline + bend))
                paint(eye, nil, stroke: 2.6, line: faceLine)
            }
        case .wince:
            paint(openPolyline([(32, 48), (39, 52), (32, 56)]), nil, stroke: 2.6, line: faceLine)
            paint(openPolyline([(68, 48), (61, 52), (68, 56)]), nil, stroke: 2.6, line: faceLine)
        case .dizzy:
            for cx in [CGFloat(36), 64] {
                paint(circle(cx, 52, 6), .white, stroke: 1.5)
                let spiral = UIBezierPath()
                for step in 0...40 {
                    let angle = CGFloat(step) / 40 * 4 * .pi
                    let r = 0.6 + 4.6 * CGFloat(step) / 40
                    let point = CGPoint(x: cx + cos(angle) * r, y: 52 + sin(angle) * r)
                    if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
                }
                paint(spiral, nil, stroke: 1.4)
            }
        }
        paint(ellipse(50, 65, 7, 5), .ink)

        // Mouth
        switch expression {
        case .normal, .blink:
            look.grin ? drawGrin() : drawSmile()
        case .happy:
            if look.grin {
                drawGrin()
            } else {
                let mouth = UIBezierPath()
                mouth.move(to: CGPoint(x: 40, y: 71))
                mouth.addQuadCurve(to: CGPoint(x: 60, y: 71), controlPoint: CGPoint(x: 50, y: 73))
                mouth.addQuadCurve(to: CGPoint(x: 40, y: 71), controlPoint: CGPoint(x: 50, y: 87))
                mouth.close()
                paint(mouth, mouthColor, stroke: 2)
                paint(ellipse(50, 79, 4.5, 2.4), tongue)
            }
        case .wince:
            paint(openPolyline([(42, 74), (45, 76.5), (48, 74), (51, 76.5), (54, 74), (57, 76.5)]), nil, stroke: 2)
        case .dizzy:
            paint(ellipse(50, 75, 3.6, 3), mouthColor, stroke: 1.5)
        }

        if look.bulldog {
            // Underbite: two little teeth poking up over the lip.
            paint(polygon([(42, 79), (44, 73), (46.5, 79)]), .white, stroke: 1.5)
            paint(polygon([(53.5, 79), (56, 73), (58, 79)]), .white, stroke: 1.5)
        }

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
