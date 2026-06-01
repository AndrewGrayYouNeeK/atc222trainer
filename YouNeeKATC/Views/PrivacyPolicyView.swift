import SwiftUI

/// In-app copy of the privacy policy so it is always reachable without a network
/// connection (App Review requires an accessible policy). The canonical hosted
/// version lives at the URL in the App Store metadata.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Apex Control respects your privacy. In short: the game does not collect, store, or transmit any personal data to us.")
                        .font(ATC.mono(13))
                        .foregroundStyle(ATC.hud)

                    policy("Data we collect", "None. Apex Control has no accounts, no analytics SDKs, and no advertising. We never see your gameplay.")
                    policy("Microphone & voice control", "If you use voice control, the microphone captures your spoken instructions and converts them to text using on-device speech recognition. Audio is processed live on your device, is not recorded or stored, and is never transmitted to us or anyone else. Voice control is optional — you can turn it off and play entirely by touch.")
                    policy("On-device data", "Your scores, career stats and settings are stored only on your device. Deleting the app removes them. You can also clear them anytime via Settings ▸ Reset all stats.")
                    policy("Game Center", "If you opt in, scores and achievements are submitted to Apple's Game Center. That data is handled by Apple under its own privacy policy; we only send your score and achievement progress.")
                    policy("Children", "The game is suitable for all ages and contains no data collection, in-game purchases, or third-party content.")
                    policy("Contact", "Questions about privacy? Email support@apexcontrol.example.")

                    Text("Last updated: 2026")
                        .font(ATC.mono(10))
                        .foregroundStyle(ATC.hudDim)
                        .padding(.top, 8)
                }
                .padding(22)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ATC.background.ignoresSafeArea())
            .navigationTitle("Privacy Policy")
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

    private func policy(_ title: LocalizedStringResource, _ body: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(ATC.mono(15, weight: .bold)).foregroundStyle(ATC.phosphor)
            Text(body).font(ATC.mono(13)).foregroundStyle(ATC.hud)
        }
    }
}
