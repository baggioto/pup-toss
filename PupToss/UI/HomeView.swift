import SwiftUI

struct HomeView: View {
    let best: Int
    let onPlay: () -> Void
    /// Shown as a Continue button when there's a saved round.
    var onContinue: (() -> Void)?

    var body: some View {
        ZStack {
            LawnBackground()
            VStack(spacing: 0) {
                HStack {
                    BestBadge(best: best)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer(minLength: 16)

                VStack(spacing: 14) {
                    OutlinedText(text: "Pup\nToss", size: 80)
                        .lineSpacing(-14)
                    Text("Toss. Match. Merge. Pop!")
                        .font(.rounded(17, .bold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.sunny, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ink, lineWidth: 3))
                        .rotationEffect(.degrees(-3))
                }

                Spacer(minLength: 16)

                NogginCluster()
                    .frame(height: 230)

                Spacer(minLength: 16)

                VStack(spacing: 12) {
                    if let onContinue {
                        Button("Continue", action: onContinue)
                            .buttonStyle(ChunkyButtonStyle(height: 68, fontSize: 30))
                        Button("New game", action: onPlay)
                            .buttonStyle(ChunkyButtonStyle(fill: .white, height: 52, fontSize: 20, depth: 4))
                    } else {
                        Button("Play", action: onPlay)
                            .buttonStyle(ChunkyButtonStyle(height: 68, fontSize: 30))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

/// The small personal-best number in the home screen's corner.
private struct BestBadge: View {
    let best: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.8, green: 0.55, blue: 0.05))
            Text("Best")
                .font(.rounded(13, .bold))
                .foregroundStyle(Color.ink.opacity(0.7))
            Text(best, format: .number)
                .font(.rounded(15))
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(Color.ink, lineWidth: 2.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Personal best: \(best)")
    }
}

/// A gently bobbing group of Noggins. Tap one and it hops, grins and barks.
private struct NogginCluster: View {
    private struct Member: Identifiable {
        let id: Int
        let kind: NogginKind
        let radius: CGFloat
        let offset: CGSize
        let period: Double
    }

    private struct Hop {
        var lift: CGFloat = 0
        var squash: CGFloat = 1
    }

    private let members: [Member] = [
        Member(id: 0, kind: NogginKind(breed: .husky, tier: .goodBoy), radius: 38, offset: CGSize(width: -116, height: -24), period: 1.7),
        Member(id: 1, kind: NogginKind(breed: .iggy, tier: .pup), radius: 27, offset: CGSize(width: 118, height: -14), period: 1.9),
        Member(id: 2, kind: NogginKind(breed: .dalmatian, tier: .pup), radius: 25, offset: CGSize(width: -70, height: 82), period: 2.1),
        Member(id: 3, kind: NogginKind(breed: .shiba, tier: .pup), radius: 24, offset: CGSize(width: 74, height: 86), period: 1.6),
        Member(id: 4, kind: NogginKind(breed: .stray, tier: .topDog), radius: 52, offset: CGSize(width: 0, height: -30), period: 2.4),
    ]

    @State private var bobbing = false
    @State private var hops: [Int: Int] = [:]
    @State private var barking: Int?

    var body: some View {
        ZStack {
            ForEach(members) { member in
                Button {
                    bark(member)
                } label: {
                    Image(uiImage: NogginArt.image(for: member.kind, radius: member.radius,
                                                   expression: barking == member.id ? .happy : .normal))
                        .shadow(color: .black.opacity(0.18), radius: 0, x: 3, y: 5)
                }
                .buttonStyle(.plain)
                .keyframeAnimator(initialValue: Hop(), trigger: hops[member.id, default: 0]) { content, hop in
                    content
                        .scaleEffect(x: hop.squash, y: 2 - hop.squash, anchor: .bottom)
                        .offset(y: -hop.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.squash) {
                        CubicKeyframe(1.14, duration: 0.07)
                        CubicKeyframe(0.92, duration: 0.12)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(0, duration: 0.07)
                        SpringKeyframe(34, duration: 0.18)
                        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                    }
                }
                .overlay(alignment: .top) {
                    if barking == member.id {
                        Text("Woof!")
                            .font(.rounded(15))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(.white, in: Capsule())
                            .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
                            .fixedSize()
                            .offset(y: -30)
                            .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .offset(member.offset)
                .offset(y: bobbing ? -5 : 5)
                .animation(.easeInOut(duration: member.period).repeatForever(autoreverses: true), value: bobbing)
                .accessibilityLabel("\(member.kind.breed.displayName). Tap to make it bark.")
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hops)
        .onAppear { bobbing = true }
    }

    private func bark(_ member: Member) {
        hops[member.id, default: 0] += 1
        // Small dogs yip higher.
        SoundEngine.shared.play(.bark, pitch: Float(40 / member.radius) * Float.random(in: 0.95...1.05))
        withAnimation(.spring(duration: 0.25, bounce: 0.5)) { barking = member.id }
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            if barking == member.id {
                withAnimation(.easeOut(duration: 0.2)) { barking = nil }
            }
        }
    }
}

#Preview {
    HomeView(best: 12480, onPlay: {})
}
