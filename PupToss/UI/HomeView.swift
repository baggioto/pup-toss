import SwiftUI

struct HomeView: View {
    let best: Int
    let onPlay: () -> Void

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

                Button("Play", action: onPlay)
                    .buttonStyle(ChunkyButtonStyle(height: 68, fontSize: 30))
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

/// A gently bobbing group of Noggins, one of each breed and size.
private struct NogginCluster: View {
    private struct Member: Identifiable {
        let id: Int
        let kind: NogginKind
        let radius: CGFloat
        let offset: CGSize
        let period: Double
    }

    private let members: [Member] = [
        Member(id: 0, kind: NogginKind(breed: .husky, tier: .goodBoy), radius: 40, offset: CGSize(width: -112, height: -18), period: 1.7),
        Member(id: 1, kind: NogginKind(breed: .pug, tier: .pup), radius: 30, offset: CGSize(width: 110, height: -6), period: 1.9),
        Member(id: 2, kind: NogginKind(breed: .dalmatian, tier: .pup), radius: 26, offset: CGSize(width: -62, height: 78), period: 2.1),
        Member(id: 3, kind: NogginKind(breed: .shiba, tier: .pup), radius: 24, offset: CGSize(width: 66, height: 84), period: 1.6),
        Member(id: 4, kind: NogginKind(breed: .shiba, tier: .topDog), radius: 52, offset: CGSize(width: 0, height: -30), period: 2.4),
    ]

    @State private var bobbing = false

    var body: some View {
        ZStack {
            ForEach(members) { member in
                Image(uiImage: NogginArt.image(for: member.kind, radius: member.radius))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 3, y: 5)
                    .offset(member.offset)
                    .offset(y: bobbing ? -5 : 5)
                    .animation(.easeInOut(duration: member.period).repeatForever(autoreverses: true), value: bobbing)
            }
        }
        .accessibilityHidden(true)
        .onAppear { bobbing = true }
    }
}

#Preview {
    HomeView(best: 12480, onPlay: {})
}
