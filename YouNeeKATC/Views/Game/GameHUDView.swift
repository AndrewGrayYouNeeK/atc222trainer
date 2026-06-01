import SwiftUI

/// Top status bar: score, strikes, streak, live traffic count, wind and the
/// pause control. Also surfaces the most urgent active emergency.
struct GameHUDView: View {
    @Bindable var engine: GameEngine
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.airport.icao + " APPROACH")
                        .font(ATC.mono(13, weight: .bold))
                        .foregroundStyle(ATC.phosphor)
                    Text("RWY \(engine.activeRunway.name) · \(windText)")
                        .font(ATC.mono(9, weight: .semibold))
                        .foregroundStyle(ATC.hudDim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(engine.score)")
                        .font(ATC.mono(28, weight: .bold))
                        .foregroundStyle(ATC.selected)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Score \(engine.score)")
                    HStack(spacing: 8) {
                        if engine.streak >= 2 {
                            Text("×\(engine.streak)")
                                .font(ATC.mono(11, weight: .bold))
                                .foregroundStyle(ATC.success)
                                .accessibilityLabel("Streak \(engine.streak)")
                        }
                        strikes
                    }
                }
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ATC.hud)
                        .frame(width: 38, height: 38)
                        .panel(corner: 10)
                }
                .accessibilityLabel("Pause")
                .padding(.leading, 6)
            }

            if let emergency = topEmergency {
                emergencyBanner(emergency)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var strikes: some View {
        HStack(spacing: 4) {
            ForEach(0..<engine.difficulty.startingLives, id: \.self) { i in
                Image(systemName: i < engine.lives ? "circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundStyle(i < engine.lives ? ATC.success : ATC.conflict.opacity(0.6))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(engine.lives) of \(engine.difficulty.startingLives) lives remaining")
    }

    private var windText: String {
        "WIND \(String(format: "%03.0f", engine.weather.windDirection))/\(engine.weather.windSpeed)"
    }

    private var topEmergency: Emergency? {
        engine.emergencies.filter { !$0.resolved }.max { $0.type.severity < $1.type.severity }
    }

    private func emergencyBanner(_ emergency: Emergency) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("\(emergency.callsign) — \(emergency.type.title)")
                .font(ATC.mono(12, weight: .bold))
            Spacer()
            Text(emergency.isExpired ? "!!" : "\(max(0, Int(emergency.remaining)))s")
                .font(ATC.mono(12, weight: .bold))
        }
        .foregroundStyle(ATC.emergency)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .panel(corner: 10, stroke: ATC.emergency.opacity(0.7))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
