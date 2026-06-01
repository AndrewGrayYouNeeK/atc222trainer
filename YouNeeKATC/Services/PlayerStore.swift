import Foundation
import Observation

/// Aggregated, persisted career record: every finished run plus lifetime totals.
/// Encoded as JSON in Application Support so it round-trips cleanly and is easy
/// to migrate. Kept separate from `AppSettings` (which uses `UserDefaults`).
struct PlayerProfile: Codable, Equatable, Sendable {
    var runs: [RunResult] = []
    var lifetimeLandings = 0
    var lifetimeDepartures = 0
    var lifetimeEmergencies = 0
    var totalRuns = 0

    func bestScore(for difficulty: Difficulty) -> Int {
        runs.filter { $0.difficulty == difficulty }.map(\.score).max() ?? 0
    }

    var allTimeBest: Int { runs.map(\.score).max() ?? 0 }

    /// Career total of aircraft handled (landings + handoffs), the basis for rank.
    var lifetimeHandled: Int { lifetimeLandings + lifetimeDepartures }

    var recentRuns: [RunResult] {
        Array(runs.sorted { $0.date > $1.date }.prefix(10))
    }
}

/// Loads, mutates and saves the `PlayerProfile`. Failures degrade gracefully to
/// an empty profile rather than crashing — a saved-game system should never take
/// the app down.
@MainActor
@Observable
final class PlayerStore {

    private(set) var profile: PlayerProfile

    private let fileURL: URL

    init(filename: String = "player_profile.json") {
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        self.fileURL = dir.appendingPathComponent(filename)
        self.profile = Self.load(from: fileURL) ?? PlayerProfile()
    }

    /// Records a finished run, updates lifetime stats and persists. Returns true
    /// if this run set a new personal best for its difficulty.
    @discardableResult
    func record(_ result: RunResult) -> Bool {
        let previousBest = profile.bestScore(for: result.difficulty)
        profile.runs.append(result)
        profile.totalRuns += 1
        profile.lifetimeLandings += result.landings
        profile.lifetimeDepartures += result.departures
        profile.lifetimeEmergencies += result.emergenciesHandled
        // Cap stored history to keep the file small.
        if profile.runs.count > 200 {
            profile.runs = Array(profile.runs.sorted { $0.date > $1.date }.prefix(200))
        }
        save()
        return result.score > previousBest
    }

    func reset() {
        profile = PlayerProfile()
        save()
    }

    // MARK: Disk

    private func save() {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Non-fatal: keep the in-memory profile; next save may succeed.
        }
    }

    private static func load(from url: URL) -> PlayerProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlayerProfile.self, from: data)
    }
}
