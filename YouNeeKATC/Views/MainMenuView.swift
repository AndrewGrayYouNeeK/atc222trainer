import SwiftUI

/// The home screen: branding, rank, difficulty selection, personal best and the
/// routes into a run, the academy, settings, stats and the leaderboard.
struct MainMenuView: View {
    let onPlay: (Difficulty) -> Void
    let onAcademy: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showLeaderboard = false

    var body: some View {
        @Bindable var settings = env.settings

        ZStack {
            ScopeBackdrop()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    rankBadge
                    bestBadge

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DIFFICULTY")
                            .font(ATC.mono(11, weight: .bold))
                            .foregroundStyle(ATC.hudDim)
                        DifficultyPicker(selection: $settings.preferredDifficulty)
                        Text(settings.preferredDifficulty.blurb)
                            .font(ATC.mono(11))
                            .foregroundStyle(ATC.hudDim)
                            .animation(.easeInOut, value: settings.preferredDifficulty)
                    }
                    .padding(16)
                    .panel()

                    VStack(spacing: 12) {
                        if settings.isCertified {
                            PrimaryButton(title: "Take Position", systemImage: "dot.radiowaves.left.and.right") {
                                onPlay(settings.preferredDifficulty)
                            }
                        } else {
                            PrimaryButton(title: "Enter the Academy", systemImage: "graduationcap.fill", action: onAcademy)
                        }
                        HStack(spacing: 12) {
                            SecondaryButton(
                                title: settings.isCertified ? "Academy" : "Skip to Live",
                                systemImage: settings.isCertified ? "graduationcap.fill" : "forward.fill"
                            ) {
                                if settings.isCertified { onAcademy() } else { onPlay(settings.preferredDifficulty) }
                            }
                            SecondaryButton(title: "Stats", systemImage: "chart.bar.fill") { showStats = true }
                        }
                        HStack(spacing: 12) {
                            SecondaryButton(title: "Leaderboard", systemImage: "trophy.fill", tint: ATC.selected) {
                                showLeaderboard = true
                            }
                            SecondaryButton(title: "Settings", systemImage: "gearshape.fill") { showSettings = true }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(onReplayAcademy: onAcademy)
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showLeaderboard) {
            GameCenterDashboard(state: .dashboard)
        }
    }

    private var rankBadge: some View {
        let handled = env.player.profile.lifetimeHandled
        let rank = ControllerRank.rank(forHandled: handled)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: env.settings.isCertified ? "checkmark.seal.fill" : "graduationcap")
                    .foregroundStyle(env.settings.isCertified ? ATC.success : ATC.hudDim)
                Text(rank.title)
                    .font(ATC.mono(15, weight: .bold))
                    .foregroundStyle(ATC.hud)
                Spacer()
                if rank.next != nil {
                    Text("\(rank.remaining(handled: handled)) to promote")
                        .font(ATC.mono(10, weight: .semibold))
                        .foregroundStyle(ATC.hudDim)
                } else {
                    Text("MAX RANK")
                        .font(ATC.mono(10, weight: .bold))
                        .foregroundStyle(ATC.selected)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ATC.panelRaised)
                    Capsule().fill(ATC.phosphor)
                        .frame(width: max(4, geo.size.width * rank.progress(handled: handled)))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .panel(corner: 16, stroke: ATC.phosphor.opacity(0.3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(String(localized: rank.title))")
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(ATC.phosphor)
                .phosphorGlow(radius: 14)
            Text("APEX CONTROL")
                .font(ATC.mono(30, weight: .bold))
                .foregroundStyle(ATC.phosphor)
                .phosphorGlow()
            Text("APPROACH CONTROLLER")
                .font(ATC.mono(11, weight: .semibold))
                .tracking(4)
                .foregroundStyle(ATC.hudDim)
        }
        .padding(.top, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apex Control, approach controller game")
    }

    private var bestBadge: some View {
        let best = env.player.profile.bestScore(for: env.settings.preferredDifficulty)
        return HStack(spacing: 10) {
            Image(systemName: "star.fill").foregroundStyle(ATC.selected)
            Text("BEST · \(best)")
                .font(ATC.mono(15, weight: .bold))
                .foregroundStyle(ATC.hud)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .panel(corner: 20, stroke: ATC.selected.opacity(0.4))
        .accessibilityLabel("Best score \(best) on \(String(localized: env.settings.preferredDifficulty.title))")
    }
}

/// Segmented difficulty selector styled to match the scope.
struct DifficultyPicker: View {
    @Binding var selection: Difficulty

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Difficulty.allCases) { difficulty in
                let isSelected = difficulty == selection
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selection = difficulty }
                } label: {
                    Text(difficulty.title)
                        .font(ATC.mono(13, weight: .bold))
                        .foregroundStyle(isSelected ? ATC.void : ATC.hud)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? ATC.phosphor : ATC.panelRaised)
                        )
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}
