import CoreGraphics

nonisolated struct MergePiece: Sendable {
    var id: Int
    var kind: NogginKind
    var position: CGPoint
}

nonisolated struct MergeGroup: Equatable, Sendable {
    var kind: NogginKind
    /// Ids of the member pieces, ascending.
    var ids: [Int]
    var centroid: CGPoint

    /// Merging into a Top Dog celebrates and removes it instead of leaving it on the lawn.
    var pops: Bool { kind.tier.next == .topDog }
}

nonisolated enum MergeEngine {
    static let requiredCount = 3

    /// Clusters pieces of the same breed and tier whose edges are within their tier's merge gap.
    /// Proximity is transitive: A near B near C is one group even if A and C are far apart.
    static func groups(in pieces: [MergePiece]) -> [MergeGroup] {
        var parent = Array(pieces.indices)

        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i {
                parent[i] = parent[parent[i]]
                i = parent[i]
            }
            return i
        }

        for i in pieces.indices {
            for j in pieces.indices where j > i {
                let a = pieces[i], b = pieces[j]
                guard a.kind == b.kind else { continue }
                if a.position.distance(to: b.position) <= a.kind.radius + b.kind.radius + a.kind.tier.mergeGap {
                    parent[root(i)] = root(j)
                }
            }
        }

        var clusters: [Int: [Int]] = [:]
        for i in pieces.indices {
            clusters[root(i), default: []].append(i)
        }

        return clusters.values
            .filter { $0.count >= requiredCount }
            .map { members in
                let n = CGFloat(members.count)
                let sumX = members.reduce(0) { $0 + pieces[$1].position.x }
                let sumY = members.reduce(0) { $0 + pieces[$1].position.y }
                return MergeGroup(
                    kind: pieces[members[0]].kind,
                    ids: members.map { pieces[$0].id }.sorted(),
                    centroid: CGPoint(x: sumX / n, y: sumY / n)
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

    /// Each piece beyond three adds 50%; the chain step within one throw multiplies.
    static func points(for group: MergeGroup, chain: Int) -> Int {
        let base = group.kind.tier.next.map(mergePoints(into:)) ?? 0
        let extra = Double(max(0, group.ids.count - MergeEngine.requiredCount)) * 0.5
        return Int((Double(base) * (1 + extra)).rounded()) * max(1, chain)
    }
}
