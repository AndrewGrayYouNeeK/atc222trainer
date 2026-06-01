import SwiftUI

/// Player-facing preferences plus Game Center, privacy and reset controls.
/// Presented as a sheet from the main menu.
struct SettingsView: View {
    var onReplayAcademy: (() -> Void)?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false
    @State private var showPrivacy = false
    @State private var showAchievements = false

    var body: some View {
        @Bindable var settings = env.settings

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    section("AUDIO & HAPTICS") {
                        toggleRow("Sound effects", systemImage: "speaker.wave.2.fill", isOn: $settings.soundEnabled)
                        toggleRow("Haptics", systemImage: "iphone.radiowaves.left.and.right", isOn: $settings.hapticsEnabled)
                    }

                    section("DISPLAY") {
                        toggleRow("Aircraft data blocks", systemImage: "tag.fill", isOn: $settings.showDataBlocks)
                        toggleRow("Colour-blind palette", systemImage: "eye.fill", isOn: $settings.colorBlindMode)
                    }

                    section("VOICE CONTROL") {
                        toggleRow("Voice control", systemImage: "mic.fill", isOn: $settings.voiceControlEnabled)
                        if settings.voiceControlEnabled {
                            toggleRow("Hands-free (always listening)", systemImage: "waveform", isOn: $settings.handsFreeVoice)
                            toggleRow("Spoken read-back", systemImage: "speaker.wave.2.fill", isOn: $settings.spokenReadback)
                            Text("Hold the transmit button and speak standard phraseology, e.g. “United 319, turn left heading 270, descend and maintain 4000.” Audio is recognised on your device and never leaves it.")
                                .font(ATC.mono(11))
                                .foregroundStyle(ATC.hudDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    section("GAMEPLAY") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Default difficulty")
                                .font(ATC.mono(13, weight: .semibold))
                                .foregroundStyle(ATC.hud)
                            DifficultyPicker(selection: $settings.preferredDifficulty)
                        }
                        .padding(.vertical, 4)
                        actionRow("Replay the Academy", systemImage: "graduationcap.fill") {
                            dismiss()
                            onReplayAcademy?()
                        }
                    }

                    section("GAME CENTER") {
                        HStack {
                            Label("Status", systemImage: "person.crop.circle")
                                .foregroundStyle(ATC.hud)
                            Spacer()
                            Text(env.gameCenter.isAuthenticated ? "Signed in" : "Signed out")
                                .foregroundStyle(env.gameCenter.isAuthenticated ? ATC.success : ATC.hudDim)
                        }
                        .font(ATC.mono(13, weight: .semibold))
                        if !env.gameCenter.isAuthenticated {
                            actionRow("Sign in to Game Center", systemImage: "arrow.right.circle.fill") {
                                env.gameCenter.authenticate()
                            }
                        }
                        actionRow("Achievements", systemImage: "trophy.fill") { showAchievements = true }
                    }

                    section("ABOUT") {
                        actionRow("Privacy Policy", systemImage: "hand.raised.fill") { showPrivacy = true }
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundStyle(ATC.hud)
                            Spacer()
                            Text(versionString).foregroundStyle(ATC.hudDim)
                        }
                        .font(ATC.mono(13, weight: .semibold))
                        actionRow("Reset all stats", systemImage: "trash.fill", tint: ATC.conflict) {
                            showResetConfirm = true
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(ATC.background.ignoresSafeArea())
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showAchievements) {
                GameCenterDashboard(state: .achievements)
            }
            .confirmationDialog("Reset all stats and history?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) { env.player.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently clears local scores and career totals. Game Center records are not affected.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Building blocks

    private func section(_ title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ATC.mono(11, weight: .bold))
                .foregroundStyle(ATC.hudDim)
                .tracking(2)
            content()
        }
        .padding(16)
        .panel()
    }

    private func toggleRow(_ title: LocalizedStringResource, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
                .font(ATC.mono(14, weight: .semibold))
                .foregroundStyle(ATC.hud)
        }
        .tint(ATC.phosphor)
    }

    private func actionRow(_ title: LocalizedStringResource, systemImage: String,
                           tint: Color = ATC.hud, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label { Text(title) } icon: { Image(systemName: systemImage) }
                    .font(ATC.mono(14, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ATC.hudDim)
            }
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
