import Foundation

/// Career progression ladder. Ranks are earned by the lifetime number of
/// aircraft handled (landings + handoffs) across all runs, giving the live game
/// a long-term sense of mastery on top of per-run scoring. The titles mirror the
/// real-world controller progression (student → developmental → CPC → senior).
struct ControllerRank: Identifiable, Equatable, Sendable {
    let level: Int
    let title: LocalizedStringResource
    let minHandled: Int

    var id: Int { level }

    /// The ladder, lowest first. Thresholds are tuned so early promotions come
    /// quickly (hook) and later ones reward long-term play (retention).
    static let ladder: [ControllerRank] = [
        ControllerRank(level: 0, title: "Trainee",                       minHandled: 0),
        ControllerRank(level: 1, title: "Developmental Controller",      minHandled: 15),
        ControllerRank(level: 2, title: "Certified Professional",        minHandled: 50),
        ControllerRank(level: 3, title: "Radar Approach Controller",     minHandled: 120),
        ControllerRank(level: 4, title: "Senior Controller",             minHandled: 250),
        ControllerRank(level: 5, title: "Watch Supervisor",              minHandled: 500),
        ControllerRank(level: 6, title: "Operations Manager",            minHandled: 900),
        ControllerRank(level: 7, title: "TRACON Legend",                 minHandled: 1500)
    ]

    /// The rank earned for a given lifetime-handled total.
    static func rank(forHandled handled: Int) -> ControllerRank {
        ladder.last { handled >= $0.minHandled } ?? ladder[0]
    }

    /// The next rank up, if any.
    var next: ControllerRank? {
        ControllerRank.ladder.first { $0.level == level + 1 }
    }

    /// Progress (0...1) from this rank toward the next, given a handled total.
    func progress(handled: Int) -> Double {
        guard let next else { return 1 }
        let span = Double(next.minHandled - minHandled)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(handled - minHandled) / span))
    }

    /// Aircraft still needed to reach the next rank (0 if maxed).
    func remaining(handled: Int) -> Int {
        guard let next else { return 0 }
        return max(0, next.minHandled - handled)
    }
}
