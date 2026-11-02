import SpriteKit
import SwiftUI

struct GameView: View {
    let model: GameModel
    let scene: GameScene
    let onHome: () -> Void

    @State private var isPaused = false

    var body: some View {
        ZStack {
            Color.lawnDark.ignoresSafeArea()
            SpriteView(scene: scene, isPaused: isPaused, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
            VStack {
                HUDView(model: model) { isPaused = true }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                Spacer()
            }
            if isPaused {
                PauseView(
                    onResume: { isPaused = false },
                    onRestart: {
                        scene.restart()
                        isPaused = false
                    },
                    onHome: onHome
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            if model.isGameOver {
                GameOverView(model: model, onPlayAgain: { scene.restart() }, onHome: onHome)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(duration: 0.35), value: model.isGameOver)
        .animation(.spring(duration: 0.3), value: isPaused)
    }
}

private struct PauseView: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                OutlinedText(text: "Paused", size: 40)
                    .padding(.bottom, 8)
                Button("Resume", action: onResume)
                    .buttonStyle(ChunkyButtonStyle(height: 60, fontSize: 24))
                Button("Restart", action: onRestart)
                    .buttonStyle(ChunkyButtonStyle(fill: .white, height: 52, fontSize: 20, depth: 4))
                Button("Home", action: onHome)
                    .buttonStyle(ChunkyButtonStyle(fill: .white, height: 52, fontSize: 20, depth: 4))
            }
            .padding(.horizontal, 40)
        }
    }
}
