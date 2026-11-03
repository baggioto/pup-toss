import CoreGraphics

nonisolated struct MergePiece: Sendable {
    var id: Int
    var kind: NogginKind
    var position: CGPoint
    /// Extra merge reach, e.g. for a piece sitting in a sand dig spot.
    var gapBonus: CGFloat = 0
}

nonisolated struct MergeGroup: Equatable, Sendable {
    /// The kind the group merges as (never a special: a Wild Pup takes its partners' breed).
    var kind: NogginKind
    /// Ids of the member pieces, ascending.
    var ids: [Int]
    var centroid: CGPoint
    var usesWild = false

    /// Merging into a Top Dog celebrates and removes it instead of leaving it on the lawn.
    var pops: Bool { kind.tier.next == .topDog }
}

nonisolated enum MergeEngine {
    static let requiredCount = 2

    /// Clusters pieces of the same breed and tier whose edges are within their tier's merge gap.
    /// Proximity is transitive: A near B near C is one group even if A and C are far apart.
    /// A Wild Pup pairs with the nearest Pup it touches that has no partner of its own, so it
    /// always makes an extra merge; if every Pup it touches already has a partner, it joins the
    /// nearest one. It takes that Pup's breed, and never merges with another Wild Pup alone.
    /// Bones and Bulldogs never merge.
    static func groups(in pieces: [MergePiece], gaps: MergeGaps = .standard) -> [MergeGroup] {
        var parent = Array(pieces.indices)

        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i {
                parent[i] = parent[parent[i]]
                i = parent[i]
            }
            return i
        }

        func near(_ a: MergePiece, _ b: MergePiece, gap: CGFloat) -> Bool {
            a.position.distance(to: b.position) <= a.kind.radius + b.kind.radius + gap + max(a.gapBonus, b.gapBonus)
        }

        let normals = pieces.indices.filter { pieces[$0].kind.special == nil }
        for i in normals {
            for j in normals where j > i {
                let a = pieces[i], b = pieces[j]
                guard a.kind == b.kind, near(a, b, gap: gaps.gap(for: a.kind.tier)) else { continue }
                parent[root(i)] = root(j)
            }
        }

        var clusters: [Int: [Int]] = [:]
        for i in normals {
            clusters[root(i), default: []].append(i)
        }

        // Each Wild Pup pairs with the nearest lone Pup it touches, else the nearest Pup it touches.
        for w in pieces.indices where pieces[w].kind.isWild {
            let wild = pieces[w]
            let touching = normals
                .filter { pieces[$0].kind.tier == .pup && near(wild, pieces[$0], gap: gaps.pup) }
                .sorted { wild.position.distance(to: pieces[$0].position) < wild.position.distance(to: pieces[$1].position) }
            let lone = touching.first { (clusters[root($0)]?.count ?? 0) == 1 }
            if let partner = lone ?? touching.first {
                clusters[root(partner), default: []].append(w)
            }
        }

        return clusters.values
            .filter { $0.count >= requiredCount }
            .map { members in
                let n = CGFloat(members.count)
                let sumX = members.reduce(0) { $0 + pieces[$1].position.x }
                let sumY = members.reduce(0) { $0 + pieces[$1].position.y }
                let anchor = members.first { pieces[$0].kind.special == nil } ?? members[0]
                return MergeGroup(
                    kind: pieces[anchor].kind,
                    ids: members.map { pieces[$0].id }.sorted(),
                    centroid: CGPoint(x: sumX / n, y: sumY / n),
                    usesWild: members.contains { pieces[$0].kind.isWild }
                )
            }
            .sorted { $0.ids[0] < $1.ids[0] }
    }
}

nonisolated enum Scoring {
    /// Points for creating a piece of `tier` by merging. A Top Dog is the bonus: it pops right away.
    static func mergePoints(into tier: Tier) -> Int {
        switch tier {
        case .pup: 0
        case .goodBoy: 30
        case .topDog: 500
        }
    }

    /// Each piece beyond the required two adds 50%; the chain step multiplies by
    /// `chainMultiplier`, so long chains pay far more than single merges.
    static func points(for group: MergeGroup, chain: Int, bonus: Double = 1) -> Int {
        let base = group.kind.tier.next.map(mergePoints(into:)) ?? 0
        let extra = Double(max(0, group.ids.count - MergeEngine.requiredCount)) * 0.5
        return Int((Double(base) * (1 + extra) * bonus).rounded()) * chainMultiplier(chain)
    }

    /// ×1, ×2, ×4, ×7, ×11…: each chain step adds one more than the last.
    static func chainMultiplier(_ chain: Int) -> Int {
        let n = max(1, chain)
        return 1 + n * (n - 1) / 2
    }
}
