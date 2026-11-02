import SwiftUI

/// Owns the model and the scene for the app's lifetime and switches between home and game.
struct RootView: View {
    private enum Screen { case home, game }

    @State private var model: GameModel
    @State private var scene: GameScene
    @State private var screen = Self.startsInGame ? Screen.game : Screen.home

    /// Debug scenarios (`-autoplay`, `-debugGoodBoys`, `-debugChain`, `-debugHUD`) skip the home screen.
    private static var startsInGame: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return ["-autoplay", "-debugGoodBoys", "-debugChain", "-debugHUD"].contains(where: arguments.contains)
        #else
        false
        #endif
    }

    init() {
        let model = GameModel()
        _model = State(initialValue: model)
        _scene = State(initialValue: GameScene(model: model))
    }

    var body: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(best: model.best, onPlay: play)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .game:
                GameView(model: model, scene: scene, onHome: goHome)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: screen)
        .statusBarHidden()
    }

    private func play() {
        scene.restart()
        screen = .game
    }

    private func goHome() {
        // Quitting mid-round still counts toward the personal best.
        model.commitBest()
        screen = .home
    }
}

#Preview {
    RootView()
}
