import SwiftUI

struct HUDView: View {
    let model: GameModel
    let onPause: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.ink)
                    .frame(width: 48, height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pause")
            card("Score") {
                Text(model.score, format: .number)
                    .font(.rounded(22))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.score)
            }
            .frame(minWidth: 104, alignment: .leading)
            // The chain rides on the score card's corner, so it never takes space in the row.
            .overlay(alignment: .topTrailing) {
                if model.chain > 1 {
                    ChainBadge(chain: model.chain, deadline: model.chainDeadline, window: model.chainWindow)
                        .offset(x: 16, y: -10)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.chain > 1 ? "Score \(model.score), chain times \(model.chain)" : "Score \(model.score)")
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
                        let radius: CGFloat = index == 0 ? 11 : 8
                        Image(uiImage: model.upcomingMystery.indices.contains(index) && model.upcomingMystery[index]
                              ? NogginArt.mysteryImage(radius: radius) : NogginArt.image(for: kind, radius: radius))
                            .opacity(index == 0 ? 1 : 0.55)
                    }
                }
                .frame(height: 28)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.5), value: model.chain > 1)
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
        // Never wrap into a narrow stack; shrink a little instead.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ink, lineWidth: 2.5))
    }
}

/// Yellow "×n" pill on the score card's corner. Bounces on every new chain step and grows a
/// little with each one, up to ×6.
private struct ChainBadge: View {
    let chain: Int
    /// When the chain runs out; the meter under the number drains toward it.
    let deadline: Date?
    let window: TimeInterval

    var body: some View {
        VStack(spacing: 2) {
            Text("×\(Scoring.chainMultiplier(chain))")
                .font(.rounded(15))
                .monospacedDigit()
            TimelineView(.animation) { context in
                let left = deadline.map { max(0, $0.timeIntervalSince(context.date)) / max(window, 0.01) } ?? 0
                Capsule()
                    .fill(Color.ink.opacity(0.2))
                    .frame(width: 30, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.ink).frame(width: 30 * min(1, left), height: 4)
                    }
            }
        }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.sunny, in: Capsule())
            .overlay(Capsule().stroke(Color.ink, lineWidth: 2.5))
            .rotationEffect(.degrees(8))
            .scaleEffect(1 + CGFloat(min(chain, 6) - 2) * 0.06)
            .keyframeAnimator(initialValue: 1.0, trigger: chain) { badge, pop in
                badge.scaleEffect(pop)
            } keyframes: { _ in
                SpringKeyframe(1.35, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
            .animation(.spring(duration: 0.3), value: chain)
    }
}
