import SwiftUI

/// Career dashboard: lifetime totals, best score per difficulty and a log of
/// recent runs. Reads straight from the persisted `PlayerStore`.
struct StatsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let profile = env.player.profile

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    rankCard(profile)
                    lifetime(profile)
                    bests(profile)
                    recent(profile)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(ATC.background.ignoresSafeArea())
            .navigationTitle("Career")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rankCard(_ p: PlayerProfile) -> some View {
        let handled = p.lifetimeHandled
        let rank = ControllerRank.rank(forHandled: handled)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "rosette").foregroundStyle(ATC.selected)
                Text(rank.title).font(ATC.mono(17, weight: .bold)).foregroundStyle(ATC.hud)
                Spacer()
                Text("LVL \(rank.level)").font(ATC.mono(11, weight: .bold)).foregroundStyle(ATC.hudDim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ATC.panelRaised)
                    Capsule().fill(ATC.phosphor)
                        .frame(width: max(4, geo.size.width * rank.progress(handled: handled)))
                }
            }
            .frame(height: 6)
            if let next = rank.next {
                Text("\(rank.remaining(handled: handled)) more aircraft to make \(text(next.title))")
                    .font(ATC.mono(10, weight: .semibold)).foregroundStyle(ATC.hudDim)
            } else {
                Text("Top of the ladder — legend status.")
                    .font(ATC.mono(10, weight: .semibold)).foregroundStyle(ATC.selected)
            }
        }
        .padding(16)
        .panel()
        .accessibilityElement(children: .combine)
    }

    private func text(_ resource: LocalizedStringResource) -> String { String(localized: resource) }

    private func lifetime(_ p: PlayerProfile) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile("All-time best", "\(p.allTimeBest)", "star.fill", ATC.selected)
                statTile("Runs", "\(p.totalRuns)", "flag.checkered", ATC.hud)
            }
            HStack(spacing: 12) {
                statTile("Landings", "\(p.lifetimeLandings)", "airplane.arrival", ATC.success)
                statTile("Departures", "\(p.lifetimeDepartures)", "airplane.departure", ATC.success)
            }
            statTile("Emergencies handled", "\(p.lifetimeEmergencies)", "cross.case.fill", ATC.emergency)
        }
    }

    private func statTile(_ title: LocalizedStringResource, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(tint)
            Text(value).font(ATC.mono(24, weight: .bold)).foregroundStyle(ATC.hud)
            Text(title).font(ATC.mono(10, weight: .semibold)).foregroundStyle(ATC.hudDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .panel(corner: 12)
        .accessibilityElement(children: .combine)
    }

    private func bests(_ p: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BEST BY DIFFICULTY").font(ATC.mono(11, weight: .bold)).foregroundStyle(ATC.hudDim).tracking(2)
            ForEach(Difficulty.allCases) { d in
                HStack {
                    Text(d.title).foregroundStyle(ATC.hud)
                    Spacer()
                    Text("\(p.bestScore(for: d))").foregroundStyle(ATC.selected)
                }
                .font(ATC.mono(14, weight: .semibold))
            }
        }
        .padding(16)
        .panel()
    }

    private func recent(_ p: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT SHIFTS").font(ATC.mono(11, weight: .bold)).foregroundStyle(ATC.hudDim).tracking(2)
            if p.recentRuns.isEmpty {
                Text("No shifts logged yet. Take a position to start your record.")
                    .font(ATC.mono(12)).foregroundStyle(ATC.hudDim)
            } else {
                ForEach(p.recentRuns) { run in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(run.score)").font(ATC.mono(15, weight: .bold)).foregroundStyle(ATC.hud)
                            Text(run.date, style: .date).font(ATC.mono(9)).foregroundStyle(ATC.hudDim)
                        }
                        Spacer()
                        Text("\(run.handled) handled · ×\(run.bestStreak)")
                            .font(ATC.mono(11)).foregroundStyle(ATC.hudDim)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .panel()
    }
}
