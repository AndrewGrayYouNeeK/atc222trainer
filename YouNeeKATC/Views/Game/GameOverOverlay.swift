import SwiftUI

/// End-of-run summary with the score breakdown, a new-best flag, and the next
/// actions (play again / leaderboard / menu).
struct GameOverOverlay: View {
    let result: RunResult
    let reason: GameOverReason
    let isNewBest: Bool
    /// Set when this run earned a promotion, for a celebratory line.
    var promotedTo: ControllerRank?
    let onRetry: () -> Void
    let onLeaderboard: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text(reason.headline)
                        .font(ATC.mono(22, weight: .bold))
                        .foregroundStyle(reason == .midair ? ATC.conflict : ATC.phosphor)
                        .phosphorGlow(reason == .midair ? ATC.conflict : ATC.phosphor)

                    if isNewBest {
                        Label("NEW PERSONAL BEST", systemImage: "star.fill")
                            .font(ATC.mono(12, weight: .bold))
                            .foregroundStyle(ATC.selected)
                    }

                    if let promotedTo {
                        VStack(spacing: 4) {
                            Label("PROMOTED", systemImage: "arrow.up.circle.fill")
                                .font(ATC.mono(12, weight: .bold))
                                .foregroundStyle(ATC.success)
                            Text(promotedTo.title)
                                .font(ATC.mono(15, weight: .bold))
                                .foregroundStyle(ATC.hud)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .panel(corner: 12, stroke: ATC.success.opacity(0.6))
                        .transition(.scale.combined(with: .opacity))
                    }

                    Text("\(result.score)")
                        .font(ATC.mono(52, weight: .bold))
                        .foregroundStyle(ATC.selected)

                    VStack(spacing: 10) {
                        statRow("Landings", "\(result.landings)")
                        statRow("Departures", "\(result.departures)")
                        statRow("Emergencies", "\(result.emergenciesHandled)")
                        statRow("Best streak", "×\(result.bestStreak)")
                        statRow("On position", durationText)
                        statRow("Difficulty", String(localized: result.difficulty.title))
                    }
                    .padding(16)
                    .panel(corner: 12)

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Play Again", systemImage: "arrow.clockwise", action: onRetry)
                        SecondaryButton(title: "Leaderboard", systemImage: "trophy.fill", tint: ATC.selected, action: onLeaderboard)
                        SecondaryButton(title: "Main Menu", systemImage: "house.fill", action: onMenu)
                    }
                }
                .padding(28)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }
        }
        .transition(.opacity)
    }

    private func statRow(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(ATC.hudDim)
            Spacer()
            Text(value).foregroundStyle(ATC.hud)
        }
        .font(ATC.mono(14, weight: .semibold))
        .accessibilityElement(children: .combine)
    }

    private var durationText: String {
        let m = result.durationSeconds / 60, s = result.durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
