import Foundation
import Observation
#if canImport(GameKit)
import GameKit
#endif

/// Owns Game Center authentication, score submission and achievement unlocks.
///
/// All identifiers below must be created to match in App Store Connect
/// (Features ▸ Game Center). They are namespaced so leaderboards and
/// achievements stay readable.
@MainActor
@Observable
final class GameCenterManager {

    private(set) var isAuthenticated = false
    private(set) var lastError: String?

    // Leaderboards (one per difficulty so boards stay comparable).
    enum Leaderboard {
        static func id(for difficulty: Difficulty) -> String {
            "apex.score.\(difficulty.rawValue)"
        }
        static let allTime = "apex.score.alltime"
    }

    // Achievements.
    enum Achievement: String, CaseIterable {
        case firstLanding   = "apex.ach.first_landing"
        case streak10       = "apex.ach.streak_10"
        case score5000      = "apex.ach.score_5000"
        case score15000     = "apex.ach.score_15000"
        case emergencyAce   = "apex.ach.emergency_ace"
        case centuryClub    = "apex.ach.century_landings"
    }

    /// Kicks off authentication. On iOS this may present Apple's sign-in sheet
    /// the first time; afterwards it resolves silently.
    func authenticate() {
        #if canImport(GameKit) && os(iOS)
        let local = GKLocalPlayer.local
        local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let viewController {
                Self.present(viewController)
                return
            }
            if let error {
                self.lastError = error.localizedDescription
                self.isAuthenticated = false
                return
            }
            self.isAuthenticated = local.isAuthenticated
            self.lastError = nil
        }
        #endif
    }

    /// Submits a finished run to the relevant leaderboards.
    func submit(_ result: RunResult) {
        #if canImport(GameKit)
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            result.score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Leaderboard.id(for: result.difficulty), Leaderboard.allTime]
        ) { [weak self] error in
            if let error { self?.lastError = error.localizedDescription }
        }
        #endif
    }

    /// Evaluates and reports achievement progress from a finished run plus the
    /// player's lifetime profile.
    func evaluateAchievements(run: RunResult, profile: PlayerProfile) {
        #if canImport(GameKit)
        guard isAuthenticated else { return }
        var reports: [GKAchievement] = []

        func achievement(_ id: Achievement, percent: Double) -> GKAchievement {
            let a = GKAchievement(identifier: id.rawValue)
            a.percentComplete = min(100, max(0, percent))
            a.showsCompletionBanner = true
            return a
        }

        if profile.lifetimeLandings >= 1 {
            reports.append(achievement(.firstLanding, percent: 100))
        }
        if run.bestStreak >= 10 {
            reports.append(achievement(.streak10, percent: 100))
        } else {
            reports.append(achievement(.streak10, percent: Double(run.bestStreak) / 10 * 100))
        }
        reports.append(achievement(.score5000, percent: Double(run.score) / 5000 * 100))
        reports.append(achievement(.score15000, percent: Double(run.score) / 15000 * 100))
        if profile.lifetimeEmergencies >= 10 {
            reports.append(achievement(.emergencyAce, percent: 100))
        } else {
            reports.append(achievement(.emergencyAce, percent: Double(profile.lifetimeEmergencies) / 10 * 100))
        }
        reports.append(achievement(.centuryClub, percent: Double(profile.lifetimeLandings) / 100 * 100))

        GKAchievement.report(reports) { [weak self] error in
            if let error { self?.lastError = error.localizedDescription }
        }
        #endif
    }

    // MARK: Presentation helpers

    #if canImport(GameKit) && os(iOS)
    static func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(viewController, animated: true)
    }
    #endif
}

#if canImport(GameKit) && os(iOS)
private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: \.isKeyWindow) ?? windows.first }
}
#endif
