import SwiftUI

struct GameOverView: View {
    let model: GameModel
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Three fouls!")
                    .font(.rounded(36))
                    .foregroundStyle(.white)
                    .shadow(color: .ink, radius: 0, x: 0, y: 3)

                VStack(spacing: 4) {
                    Text("FINAL SCORE")
                        .font(.rounded(12, .bold))
                        .foregroundStyle(Color.ink.opacity(0.7))
                    Text(model.score, format: .number)
                        .font(.rounded(52))
                    if model.isNewBest {
                        Text("New best")
                            .font(.rounded(13, .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Color.sunny, in: Capsule())
                            .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
                    } else {
                        Text("Best \(model.best.formatted())")
                            .font(.rounded(14, .semibold))
                            .foregroundStyle(Color.ink.opacity(0.7))
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.ink, lineWidth: 3))

                HStack(spacing: 10) {
                    stat("Throws", model.throwsMade)
                    stat("Merges", model.merges)
                    stat("Pops", model.pops)
                }

                Button(action: onPlayAgain) {
                    Text("Play again")
                        .font(.rounded(24))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.tangerine, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.rounded(12, .bold))
                .foregroundStyle(Color.ink.opacity(0.7))
            Text("\(value)")
                .font(.rounded(24))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ink, lineWidth: 2.5))
    }
}
