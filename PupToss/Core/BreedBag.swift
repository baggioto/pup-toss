import Foundation

/// Deals breeds like a shuffled bag, so every breed in play turns up once per round of draws and
/// none goes missing for long. Sometimes it deals a breed that has a lonely Pup on the lawn
/// instead, so stray Pups find partners.
nonisolated struct BreedBag: Codable, Sendable {
    private var bag: [Breed] = []

    mutating func draw<G: RandomNumberGenerator>(available: [Breed], lonely: [Breed], bias: Double,
                                                 using generator: inout G) -> Breed {
        let lonely = lonely.filter(available.contains)
        if !lonely.isEmpty, Double.random(in: 0..<1, using: &generator) < bias,
           let breed = lonely.randomElement(using: &generator) {
            return breed
        }
        bag.removeAll { !available.contains($0) }
        if bag.isEmpty {
            bag = available.shuffled(using: &generator)
        }
        return bag.removeFirst()
    }
}
