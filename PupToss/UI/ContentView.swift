import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var model: GameModel
    @State private var scene: GameScene

    init() {
        let model = GameModel()
        _model = State(initialValue: model)
        _scene = State(initialValue: GameScene(model: model))
    }

    var body: some View {
        ZStack {
            Color.lawnDark.ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
            VStack {
                HUDView(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                Spacer()
            }
            if model.isGameOver {
                GameOverView(model: model) { scene.restart() }
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(duration: 0.35), value: model.isGameOver)
        .statusBarHidden()
    }
}

extension Color {
    static let lawnDark = Color(red: 0.25, green: 0.54, blue: 0.28)
    static let ink = Color(red: 0.12, green: 0.1, blue: 0.09)
    static let tangerine = Color(red: 1, green: 0.54, blue: 0.24)
    static let sunny = Color(red: 1, green: 0.79, blue: 0.24)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

#Preview {
    ContentView()
}
