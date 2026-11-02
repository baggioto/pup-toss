import SwiftUI

/// Owns the model and the scene for the app's lifetime and switches between home and game.
struct RootView: View {
    private enum Screen { case home, game }

    @State private var model: GameModel
    @State private var scene: GameScene
    @State private var screen = Self.startsInGame ? Screen.game : Screen.home
    @State private var hasSave = SaveStore.hasSave

    /// Debug options (`-autoplay` and the `-debug…` scenarios) skip the home screen.
    private static var startsInGame: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return ["-autoplay", "-debugGoodBoys", "-debugChain", "-debugHUD", "-debugLawn", "-debugDrama"].contains(where: arguments.contains)
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
                HomeView(best: model.best, onPlay: play, onContinue: continueAction)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .game:
                GameView(model: model, scene: scene, onHome: goHome, onSave: save)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: screen)
        .statusBarHidden()
        .onAppear { SoundEngine.shared.isEnabled = model.isSoundOn }
        .onChange(of: model.isSoundOn) { _, on in SoundEngine.shared.isEnabled = on }
    }

    private var continueAction: (() -> Void)? {
        hasSave ? { resume() } : nil
    }

    private func play() {
        SaveStore.clear()
        hasSave = false
        scene.restart()
        screen = .game
    }

    private func resume() {
        guard let game = SaveStore.load() else {
            hasSave = false
            return
        }
        scene.restore(game)
        screen = .game
    }

    /// Keeps the round for Continue; `false` when there's nothing to keep (the game is over).
    private func save() {
        if let game = scene.snapshot() {
            SaveStore.save(game)
            hasSave = true
        } else {
            SaveStore.clear()
            hasSave = false
        }
    }

    private func goHome() {
        // Quitting mid-round still counts toward the personal best, and the round can be continued.
        model.commitBest()
        save()
        screen = .home
    }
}

#Preview {
    RootView()
}
