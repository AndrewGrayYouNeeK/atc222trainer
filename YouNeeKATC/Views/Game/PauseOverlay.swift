import SwiftUI

/// Modal shown when the controller pauses. Dims the scope and offers resume /
/// quit. The simulation is frozen behind it.
struct PauseOverlay: View {
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture(perform: onResume)
            VStack(spacing: 18) {
                Text("PAUSED")
                    .font(ATC.mono(26, weight: .bold))
                    .foregroundStyle(ATC.phosphor)
                    .phosphorGlow()
                PrimaryButton(title: "Resume", systemImage: "play.fill", action: onResume)
                SecondaryButton(title: "End Shift", systemImage: "stop.fill", tint: ATC.caution, action: onQuit)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .panel()
            .padding(40)
        }
        .transition(.opacity)
    }
}
