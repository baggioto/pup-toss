#if DEBUG
import UIKit

/// Renders the app icon (a crowned Stray) from the in-game art so it always matches the Noggins.
/// Run a debug build with `-exportIcon`; the PNG lands in the app's Documents folder
/// (see the README for copying it into `Assets.xcassets`).
enum IconExporter {
    static func exportIfRequested() {
        if ProcessInfo.processInfo.arguments.contains("-exportSheet") { exportSheet() }
        guard ProcessInfo.processInfo.arguments.contains("-exportIcon") else { return }
        let url = URL.documentsDirectory.appending(path: "AppIcon.png")
        do {
            try opaquePNG(render())?.write(to: url)
            print("[icon] wrote \(url.path)")
        } catch {
            print("[icon] failed: \(error)")
        }
    }

    static func render(side: CGFloat = 1024) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            // Whole-pixel stripes so no anti-aliased seams show between them.
            let stripe = (side / 8).rounded()
            for i in 0..<Int((side / stripe).rounded(.up)) {
                UIColor(hex: i.isMultiple(of: 2) ? 0x74C26F : 0x66B562).setFill()
                cg.fill(CGRect(x: 0, y: CGFloat(i) * stripe, width: side, height: stripe))
            }

            let radius = side * 0.28
            let center = CGPoint(x: side / 2, y: side * 0.56)
            UIColor(white: 0, alpha: 0.18).setFill()
            cg.fillEllipse(in: CGRect(x: center.x - radius * 1.05 + side * 0.02, y: center.y - radius * 1.05 + side * 0.035,
                                      width: radius * 2.1, height: radius * 2.1))

            let head = NogginArt.image(for: NogginKind(breed: .stray, tier: .topDog), radius: radius)
            head.draw(in: CGRect(x: center.x - head.size.width / 2, y: center.y - head.size.height / 2,
                                 width: head.size.width, height: head.size.height))
        }
    }

    /// Every breed at every tier on the lawn colour, labelled, for reviewing art changes (`-exportSheet`).
    private static func exportSheet() {
        let cell: CGFloat = 300, label: CGFloat = 220, header: CGFloat = 70
        let size = CGSize(width: label + cell * CGFloat(Tier.allCases.count),
                          height: header + cell * CGFloat(Breed.allCases.count))
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
        }
        let url = URL.documentsDirectory.appending(path: "Sheet.png")
        try? sheet.pngData()?.write(to: url)
        print("[sheet] wrote \(url.path)")
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
