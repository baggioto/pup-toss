import CoreGraphics
import Foundation

/// A round frozen to disk when the app goes to the background, so it can be continued later.
nonisolated struct SavedGame: Codable, Sendable {
    nonisolated struct Piece: Codable, Sendable {
        var kind: NogginKind
        var position: CGPoint
        /// Added later; older saves have none.
        var asleep: Bool? = nil
    }

    static let currentVersion = 1

    var version = SavedGame.currentVersion
    var score: Int
    var fouls: Int
    var throwsMade: Int
    var merges: Int
    var pops: Int
    var upcoming: [NogginKind]
    var generated: Int
    var goals: GoalTracker
    var pieces: [Piece]
    /// The Noggin waiting in the slingshot; `nil` if the round was saved mid-throw, in which case
    /// the turn finishes resolving on resume.
    var loaded: NogginKind?
    var features: LawnFeatures
    /// Added later; older saves have none.
    var whistles: Int?
}

/// Reads and writes the one saved round, as JSON in Application Support.
enum SaveStore {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "SavedGame.json")
    }

    static func save(_ game: SavedGame) {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(game).write(to: url, options: .atomic)
        } catch {
            print("[save] failed: \(error)")
        }
    }

    static func load() -> SavedGame? {
        guard let data = try? Data(contentsOf: url),
              let game = try? JSONDecoder().decode(SavedGame.self, from: data),
              game.version == SavedGame.currentVersion
        else { return nil }
        return game
    }

    static var hasSave: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
