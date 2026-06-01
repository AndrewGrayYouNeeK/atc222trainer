import SwiftUI

/// Top-level router. Full-screen flows (menu, onboarding, tutorial, game) are
/// switched here; settings, stats and leaderboards are presented as sheets from
/// the menu. First launch drops the player into onboarding.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    enum Screen: Equatable {
        case menu
        case onboarding
        case academy
        case game(Difficulty)
    }

    @State private var screen: Screen = .menu

    var body: some View {
        Group {
            switch screen {
            case .menu:
                MainMenuView(
                    onPlay: { go(.game($0)) },
                    onAcademy: { go(.academy) }
                )
            case .onboarding:
                OnboardingView(
                    onStartAcademy: {
                        env.settings.hasOnboarded = true
                        go(.academy)
                    },
                    onSkip: {
                        env.settings.hasOnboarded = true
                        go(.menu)
                    }
                )
            case .academy:
                AcademyView(
                    onGraduate: { difficulty in go(.game(difficulty)) },
                    onExit: { go(.menu) }
                )
            case .game(let difficulty):
                GameContainerView(difficulty: difficulty, onExit: { go(.menu) })
            }
        }
        .transition(.opacity)
        .onAppear {
            if !env.settings.hasOnboarded { screen = .onboarding }
        }
    }

    private func go(_ destination: Screen) {
        withAnimation(.easeInOut(duration: 0.3)) { screen = destination }
    }
}
