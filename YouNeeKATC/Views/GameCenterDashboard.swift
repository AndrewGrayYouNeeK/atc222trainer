import SwiftUI
#if canImport(GameKit)
import GameKit
#endif

/// Presents Apple's native Game Center dashboard (leaderboards / achievements).
/// Falls back to an informational panel when Game Center is unavailable or the
/// player isn't signed in, so the entry points never dead-end.
struct GameCenterDashboard: View {
    enum State: Equatable {
        case leaderboard(String)
        case achievements
        case dashboard
    }
    let state: State

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        if env.gameCenter.isAuthenticated {
            GameCenterControllerView(state: state)
                .ignoresSafeArea()
        } else {
            unavailable
        }
        #else
        unavailable
        #endif
    }

    private var unavailable: some View {
        ZStack {
            ATC.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "trophy")
                    .font(.system(size: 44))
                    .foregroundStyle(ATC.hudDim)
                Text("Game Center Unavailable")
                    .font(ATC.mono(18, weight: .bold))
                    .foregroundStyle(ATC.hud)
                Text("Sign in to Game Center in the Settings app to compare scores and earn achievements.")
                    .font(ATC.mono(13))
                    .foregroundStyle(ATC.hudDim)
                    .multilineTextAlignment(.center)
                SecondaryButton(title: "Retry Sign-In", systemImage: "arrow.clockwise") {
                    env.gameCenter.authenticate()
                }
                PrimaryButton(title: "Close") { dismiss() }
            }
            .padding(30)
            .frame(maxWidth: 380)
        }
    }
}

#if os(iOS) && canImport(GameKit)
/// UIKit bridge for `GKGameCenterViewController`.
private struct GameCenterControllerView: UIViewControllerRepresentable {
    let state: GameCenterDashboard.State

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller: GKGameCenterViewController
        switch state {
        case .leaderboard(let id):
            controller = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        case .achievements:
            controller = GKGameCenterViewController(state: .achievements)
        case .dashboard:
            controller = GKGameCenterViewController(state: .dashboard)
        }
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
#endif
