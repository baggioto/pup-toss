import SwiftUI

struct HUDView: View {
    let model: GameModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            card("Score") {
                Text(model.score, format: .number)
                    .font(.rounded(22))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.score)
            }
            if model.chain > 1 {
                card("Chain", fill: .sunny) {
                    Text("×\(model.chain)").font(.rounded(22))
                }
                .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
            card("Fouls") {
                HStack(spacing: 3) {
                    ForEach(0..<GameModel.maxFouls, id: \.self) { i in
                        Image(systemName: i < model.fouls ? "xmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(i < model.fouls ? Color.red : Color.ink.opacity(0.35))
                    }
                }
                .frame(height: 28)
            }
            card("Next") {
                HStack(spacing: 2) {
                    ForEach(Array(model.upcoming.prefix(2).enumerated()), id: \.offset) { index, kind in
                        Image(uiImage: NogginArt.image(for: kind, radius: index == 0 ? 11 : 8))
                            .opacity(index == 0 ? 1 : 0.55)
                    }
                }
                .frame(height: 28)
            }
        }
        .animation(.spring(duration: 0.3), value: model.chain > 1)
    }

    private func card<Content: View>(_ title: String, fill: Color = .white, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.rounded(10, .bold))
                .tracking(0.6)
                .foregroundStyle(Color.ink.opacity(0.7))
            content()
                .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ink, lineWidth: 2.5))
    }
}
