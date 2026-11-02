import SwiftUI

extension Color {
    static let lawnDark = Color(red: 0.25, green: 0.54, blue: 0.28)
    static let lawnStripeA = Color(red: 0.40, green: 0.71, blue: 0.38)
    static let lawnStripeB = Color(red: 0.37, green: 0.67, blue: 0.35)
    static let ink = Color(red: 0.12, green: 0.1, blue: 0.09)
    static let tangerine = Color(red: 1, green: 0.54, blue: 0.24)
    static let sunny = Color(red: 1, green: 0.79, blue: 0.24)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Mown-lawn stripes, the backdrop for every screen outside the game.
struct LawnBackground: View {
    var stripe: CGFloat = 56

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            var even = true
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: stripe)),
                             with: .color(even ? .lawnStripeA : .lawnStripeB))
                y += stripe
                even.toggle()
            }
        }
        .ignoresSafeArea()
    }
}

/// Chunky cartoon button: ink outline with a solid drop that squashes when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = .tangerine
    var height: CGFloat = 64
    var fontSize: CGFloat = 26
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.rounded(fontSize))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ink, lineWidth: 3))
            .background(Color.ink, in: RoundedRectangle(cornerRadius: 20).offset(y: pressed ? 1 : depth))
            .offset(y: pressed ? depth - 1 : 0)
            .animation(.snappy(duration: 0.12), value: pressed)
    }
}

/// White text with a thick ink outline, for titles over the lawn.
struct OutlinedText: View {
    let text: String
    let size: CGFloat
    var outline: CGFloat = 3

    var body: some View {
        let label = Text(text).font(.rounded(size, .black)).multilineTextAlignment(.center)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                label
                    .foregroundStyle(Color.ink)
                    .offset(x: cos(angle) * outline, y: sin(angle) * outline)
            }
            label.foregroundStyle(.white)
        }
        .shadow(color: .ink, radius: 0, x: 0, y: outline + 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
