#if DEBUG
import UIKit

/// Renders the app icon (a crowned Stray) from the in-game art so it always matches the Noggins,
/// in the light, dark and tinted appearances iOS 18+ offers on the home screen.
/// Run a debug build with `-exportIcon`; the PNGs land in the app's Documents folder
/// (see the README for copying them into `Assets.xcassets`).
enum IconExporter {
    enum Appearance: String, CaseIterable {
        case light, dark, tinted

        var fileName: String {
            switch self {
            case .light: "AppIcon.png"
            case .dark: "AppIcon-Dark.png"
            case .tinted: "AppIcon-Tinted.png"
            }
        }
    }

    static func exportIfRequested() {
        if ProcessInfo.processInfo.arguments.contains("-exportSheet") { exportSheet() }
        if ProcessInfo.processInfo.arguments.contains("-exportFaces") { exportFaces() }
        guard ProcessInfo.processInfo.arguments.contains("-exportIcon") else { return }
        for appearance in Appearance.allCases {
            let url = URL.documentsDirectory.appending(path: appearance.fileName)
            let image = render(appearance)
            let data = appearance == .tinted ? grayscalePNG(image) : opaquePNG(image)
            do {
                try data?.write(to: url)
                print("[icon] wrote \(url.path)")
            } catch {
                print("[icon] failed: \(error)")
            }
        }
    }

    static func render(_ appearance: Appearance = .light, side: CGFloat = 1024) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            let radius = side * 0.28
            let center = CGPoint(x: side / 2, y: side * 0.56)

            switch appearance {
            case .light, .dark:
                // Whole-pixel stripes so no anti-aliased seams show between them.
                let colors: (UInt32, UInt32) = appearance == .light ? (0x74C26F, 0x66B562) : (0x1F3D24, 0x1A3520)
                let stripe = (side / 8).rounded()
                for i in 0..<Int((side / stripe).rounded(.up)) {
                    UIColor(hex: i.isMultiple(of: 2) ? colors.0 : colors.1).setFill()
                    cg.fill(CGRect(x: 0, y: CGFloat(i) * stripe, width: side, height: stripe))
                }
                if appearance == .dark {
                    // A soft glow behind the head keeps the black Stray from sinking into the dark.
                    UIColor(hex: 0x4E8F52, alpha: 0.55).setFill()
                    cg.fillEllipse(in: CGRect(x: center.x - radius * 1.45, y: center.y - radius * 1.45,
                                              width: radius * 2.9, height: radius * 2.9))
                }
                UIColor(white: 0, alpha: appearance == .light ? 0.18 : 0.35).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius * 1.05 + side * 0.02, y: center.y - radius * 1.05 + side * 0.035,
                                          width: radius * 2.1, height: radius * 2.1))
            case .tinted:
                // iOS tints the light parts of a greyscale icon, so the head sits on a pale disc.
                UIColor.black.setFill()
                cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
                UIColor(white: 0.82, alpha: 1).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius * 1.42, y: center.y - radius * 1.42,
                                          width: radius * 2.84, height: radius * 2.84))
            }

            let head = NogginArt.image(for: NogginKind(breed: .stray, tier: .topDog), radius: radius)
            head.draw(in: CGRect(x: center.x - head.size.width / 2, y: center.y - head.size.height / 2,
                                 width: head.size.width, height: head.size.height))
        }
    }

    /// Every breed at every tier on the lawn colour, labelled, for reviewing art changes (`-exportSheet`).
    private static func exportSheet() {
        let cell: CGFloat = 300, label: CGFloat = 220, header: CGFloat = 70
        let size = CGSize(width: label + cell * CGFloat(Tier.allCases.count),
                          height: header + cell * CGFloat(Breed.allCases.count + 1))
        let font = UIFont.systemFont(ofSize: 34, weight: .heavy)
        let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 34) } ?? font
        let text: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: UIColor.ink]
        let sheet = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hex: 0x74C26F).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (column, tier) in Tier.allCases.enumerated() {
                let title = tier.displayName as NSString
                let width = title.size(withAttributes: text).width
                title.draw(at: CGPoint(x: label + CGFloat(column) * cell + (cell - width) / 2, y: 16), withAttributes: text)
            }
            for (row, breed) in Breed.allCases.enumerated() {
                let y = header + CGFloat(row) * cell
                (breed.displayName as NSString).draw(at: CGPoint(x: 24, y: y + cell / 2 - 22), withAttributes: text)
                for (column, tier) in Tier.allCases.enumerated() {
                    let image = NogginArt.image(for: NogginKind(breed: breed, tier: tier), radius: 70)
                    image.draw(at: CGPoint(x: label + CGFloat(column) * cell + (cell - image.size.width) / 2,
                                           y: y + (cell - image.size.height) / 2))
                }
            }
            // Last row: the specials, drawn at their in-game sizes relative to a Pup.
            let y = header + CGFloat(Breed.allCases.count) * cell
            ("Specials" as NSString).draw(at: CGPoint(x: 24, y: y + cell / 2 - 22), withAttributes: text)
            for (column, special) in Special.allCases.enumerated() {
                let kind = NogginKind.special(special)
                let image = NogginArt.image(for: kind, radius: 70 * kind.radius / Tier.pup.radius)
                image.draw(at: CGPoint(x: label + CGFloat(column) * cell + (cell - image.size.width) / 2,
                                       y: y + (cell - image.size.height) / 2))
            }
        }
        let url = URL.documentsDirectory.appending(path: "Sheet.png")
        try? sheet.pngData()?.write(to: url)
        print("[sheet] wrote \(url.path)")
    }

    /// Every breed's Pup in every expression (`-exportFaces`), written to `Faces.png`.
    private static func exportFaces() {
        let cell: CGFloat = 260, label: CGFloat = 220, header: CGFloat = 70
        let expressions = NogginExpression.allCases
        let size = CGSize(width: label + cell * CGFloat(expressions.count),
                          height: header + cell * CGFloat(Breed.allCases.count))
        let font = UIFont.systemFont(ofSize: 34, weight: .heavy)
        let text: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.ink]
        let sheet = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hex: 0x74C26F).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (column, expression) in expressions.enumerated() {
                let title = expression.rawValue.capitalized as NSString
                let width = title.size(withAttributes: text).width
                title.draw(at: CGPoint(x: label + CGFloat(column) * cell + (cell - width) / 2, y: 16), withAttributes: text)
            }
            for (row, breed) in Breed.allCases.enumerated() {
                let y = header + CGFloat(row) * cell
                (breed.displayName as NSString).draw(at: CGPoint(x: 24, y: y + cell / 2 - 22), withAttributes: text)
                for (column, expression) in expressions.enumerated() {
                    let image = NogginArt.image(for: NogginKind(breed: breed, tier: .pup), radius: 62, expression: expression)
                    image.draw(at: CGPoint(x: label + CGFloat(column) * cell + (cell - image.size.width) / 2,
                                           y: y + (cell - image.size.height) / 2))
                }
            }
        }
        try? sheet.pngData()?.write(to: URL.documentsDirectory.appending(path: "Faces.png"))
    }

    private static func grayscalePNG(_ image: UIImage) -> Data? {
        guard let source = image.cgImage,
              let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        return context.makeImage().flatMap { UIImage(cgImage: $0).pngData() }
    }

    /// The App Store rejects icons with an alpha channel, so re-encode without one.
    private static func opaquePNG(_ image: UIImage) -> Data? {
        guard let source = image.cgImage,
              let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        return context.makeImage().flatMap { UIImage(cgImage: $0).pngData() }
    }
}
#endif
