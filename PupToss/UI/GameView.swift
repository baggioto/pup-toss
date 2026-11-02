import SpriteKit
import SwiftUI

struct GameView: View {
    let model: GameModel
    let scene: GameScene
    let onHome: () -> Void

    @State private var isPaused = false
    @State private var celebrating: GameModel.CompletedGoal?

    var body: some View {
        ZStack {
            Color.lawnDark.ignoresSafeArea()
            SpriteView(scene: scene, isPaused: isPaused, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                HUDView(model: model) { isPaused = true }
                HStack(spacing: 8) {
                    GoalPill(goal: model.goals.current, progress: model.goals.progress)
                    Spacer(minLength: 0)
                    if model.isLastChance {
                        LastChancePill()
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .animation(.spring(duration: 0.35, bounce: 0.5), value: model.isLastChance)
            if let celebrating {
                GoalBanner(goal: celebrating.goal)
                    .id(celebrating.id)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
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
        .animation(.spring(duration: 0.4, bounce: 0.45), value: celebrating)
        .onChange(of: model.completedGoal) { _, completed in
            guard let completed else { return }
            celebrating = completed
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                if celebrating == completed { celebrating = nil }
            }
        }
    }
}

/// The current goal, its progress and its bonus, under the top bar.
private struct GoalPill: View {
    let goal: Goal
    let progress: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .black))
            Text(goal.shortTitle)
                .font(.rounded(13, .bold))
            if goal.target > 1 {
                Text("\(min(progress, goal.target))/\(goal.target)")
                    .font(.rounded(13))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink.opacity(0.6))
                    .contentTransition(.numericText())
            }
            Text("+\(goal.bonus)")
                .font(.rounded(12))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.sunny, in: Capsule())
        }
        .lineLimit(1)
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
        .animation(.snappy, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal: \(goal.title), \(min(progress, goal.target)) of \(goal.target), bonus \(goal.bonus)")
    }
}

private struct LastChancePill: View {
    var body: some View {
        Text("Last chance!")
            .font(.rounded(13))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 0.93, green: 0.3, blue: 0.36), in: Capsule())
            .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
            .phaseAnimator([1.0, 1.08]) { pill, scale in
                pill.scaleEffect(scale)
            } animation: { _ in .easeInOut(duration: 0.5) }
    }
}

/// Pops up in the middle of the lawn when a goal is completed.
private struct GoalBanner: View {
    let goal: Goal

    var body: some View {
        VStack(spacing: 2) {
            Text("GOAL COMPLETE")
                .font(.rounded(13, .black))
                .tracking(1)
                .foregroundStyle(Color.ink.opacity(0.7))
            Text(goal.title)
                .font(.rounded(22))
                .foregroundStyle(Color.ink)
            Text("+\(goal.bonus)")
                .font(.rounded(28, .black))
                .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.0))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.sunny, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.ink, lineWidth: 3))
        .background(Color.ink, in: RoundedRectangle(cornerRadius: 22).offset(y: 5))
        .rotationEffect(.degrees(-3))
        .accessibilityElement(children: .combine)
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
