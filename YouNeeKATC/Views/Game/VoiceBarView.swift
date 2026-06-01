import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The in-game voice strip: shows the live transcript and a push-to-talk button
/// (or a hands-free listening indicator). Sits just above the command deck so
/// voice and touch controls coexist.
struct VoiceBarView: View {
    @Bindable var voice: VoiceCommandManager
    let handsFree: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressing = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusLine)
                    .font(ATC.mono(10, weight: .bold))
                    .foregroundStyle(voice.isListening ? ATC.success : ATC.hudDim)
                Text(voice.transcript.isEmpty ? placeholder : voice.transcript)
                    .font(ATC.mono(13, weight: .semibold))
                    .foregroundStyle(voice.transcript.isEmpty ? ATC.hudDim : ATC.hud)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)

            if voice.authState == .denied {
                Button(action: openSettings) {
                    Text("ENABLE MIC")
                        .font(ATC.mono(11, weight: .bold))
                        .foregroundStyle(ATC.void)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(ATC.caution))
                }
                .buttonStyle(PressableStyle())
            } else if handsFree {
                listeningIndicator
            } else {
                pushToTalkButton
            }
        }
        .padding(12)
        .panel(stroke: voice.isListening ? ATC.success.opacity(0.6) : ATC.phosphor.opacity(0.25))
        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
    }

    private var statusLine: String {
        switch voice.authState {
        case .denied: return "MIC ACCESS OFF"
        case .unavailable: return "VOICE UNAVAILABLE"
        case .notDetermined: return "TAP TO ENABLE VOICE"
        case .authorized:
            if voice.isListening { return handsFree ? "HANDS-FREE · LISTENING" : "LISTENING…" }
            return handsFree ? "HANDS-FREE READY" : "HOLD TO TRANSMIT"
        }
    }

    private var placeholder: String {
        "e.g. “Delta 482, descend and maintain 3000, cleared to land”"
    }

    private var listeningIndicator: some View {
        ZStack {
            Circle().fill(ATC.success.opacity(0.18)).frame(width: 52, height: 52)
            Image(systemName: "waveform")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ATC.success)
                .symbolEffect(.variableColor.iterative, isActive: voice.isListening && !reduceMotion)
        }
        .accessibilityLabel(voice.isListening ? "Listening hands-free" : "Hands-free ready")
    }

    private var pushToTalkButton: some View {
        ZStack {
            Circle()
                .fill(pressing ? ATC.success : ATC.phosphor)
                .frame(width: 56, height: 56)
                .phosphorGlow(pressing ? ATC.success : ATC.phosphor, radius: pressing ? 14 : 6)
            Image(systemName: pressing ? "mic.fill" : "mic")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ATC.void)
        }
        .scaleEffect(pressing ? 1.08 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressing)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressing { pressing = true; voice.startListening(continuous: false) }
                }
                .onEnded { _ in
                    pressing = false; voice.stopListening()
                }
        )
        .accessibilityLabel("Push to talk")
        .accessibilityHint("Hold and speak an instruction, then release")
        .accessibilityAddTraits(.isButton)
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
