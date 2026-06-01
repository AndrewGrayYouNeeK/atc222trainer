import Foundation

/// Selectable challenge level. Tunes spawn pacing, traffic ceiling and the
/// score multiplier so leaderboards stay meaningful.
enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case relaxed
    case standard
    case intense

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .relaxed: return "Relaxed"
        case .standard: return "Standard"
        case .intense: return "Intense"
        }
    }

    var blurb: LocalizedStringResource {
        switch self {
        case .relaxed: return "Gentle pacing. Learn the ropes."
        case .standard: return "A steady, building rush."
        case .intense: return "Relentless traffic. Experts only."
        }
    }

    /// Seconds between spawns at the start of a run.
    var initialSpawnInterval: Double {
        switch self {
        case .relaxed: return 16
        case .standard: return 11
        case .intense: return 7
        }
    }

    /// The floor the spawn interval ramps down toward as a run gets longer.
    var minSpawnInterval: Double {
        switch self {
        case .relaxed: return 8
        case .standard: return 5
        case .intense: return 3
        }
    }

    /// Maximum simultaneous aircraft on the scope.
    var trafficCeiling: Int {
        switch self {
        case .relaxed: return 6
        case .standard: return 9
        case .intense: return 13
        }
    }

    /// Score multiplier applied to every handled aircraft.
    var scoreMultiplier: Double {
        switch self {
        case .relaxed: return 1.0
        case .standard: return 1.5
        case .intense: return 2.25
        }
    }

    /// Strikes the controller can absorb before the run ends.
    var startingLives: Int {
        switch self {
        case .relaxed: return 5
        case .standard: return 3
        case .intense: return 3
        }
    }
}

/// Why a run ended, used to theme the game-over screen.
enum GameOverReason: Equatable, Sendable {
    case outOfLives
    case midair
    case quit

    var headline: LocalizedStringResource {
        switch self {
        case .outOfLives: return "Shift Over"
        case .midair: return "Loss of Separation"
        case .quit: return "Position Relieved"
        }
    }
}

/// The immutable summary of a finished run, persisted to the history store and
/// reported to Game Center.
struct RunResult: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var score: Int
    var landings: Int
    var departures: Int
    var emergenciesHandled: Int
    var bestStreak: Int
    var durationSeconds: Int
    var difficulty: Difficulty
    var date: Date

    var handled: Int { landings + departures }
}
