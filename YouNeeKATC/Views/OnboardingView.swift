import SwiftUI

/// First-launch walkthrough. Three quick paged cards set expectations, then the
/// player can jump straight into the interactive tutorial or skip to the menu.
struct OnboardingView: View {
    let onStartAcademy: () -> Void
    let onSkip: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringResource
        let body: LocalizedStringResource
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "dot.radiowaves.left.and.right",
             title: "You are the controller",
             body: "Aircraft stream into your airspace from every direction. Your job: keep them safely apart and guide each one home."),
        Page(id: 1, symbol: "mic.fill",
             title: "Talk to your traffic",
             body: "Hold the transmit button and speak like a real controller — “Delta 482, descend and maintain 3000, cleared to land.” Prefer touch? Tap an aircraft and drag a heading. Use either, anytime."),
        Page(id: 2, symbol: "graduationcap.fill",
             title: "Train, then certify",
             body: "The Academy teaches you real ATC — separation, vectoring to final, sequencing, departures and emergencies — using genuine phraseology. Pass the check ride to get certified and unlock live traffic, then climb the ranks.")
    ]

    var body: some View {
        ZStack {
            ScopeBackdrop()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(ATC.mono(14, weight: .semibold))
                        .foregroundStyle(ATC.hudDim)
                        .padding()
                }

                TabView(selection: $page) {
                    ForEach(pages) { p in
                        VStack(spacing: 22) {
                            Image(systemName: p.symbol)
                                .font(.system(size: 72))
                                .foregroundStyle(ATC.phosphor)
                                .phosphorGlow(radius: 16)
                            Text(p.title)
                                .font(ATC.mono(24, weight: .bold))
                                .foregroundStyle(ATC.hud)
                                .multilineTextAlignment(.center)
                            Text(p.body)
                                .font(ATC.mono(15))
                                .foregroundStyle(ATC.hudDim)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding()
                        .tag(p.id)
                        .accessibilityElement(children: .combine)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                #endif

                VStack(spacing: 12) {
                    if page == pages.count - 1 {
                        PrimaryButton(title: "Enter the Academy", systemImage: "graduationcap.fill", action: onStartAcademy)
                        SecondaryButton(title: "Skip to Menu", action: onSkip)
                    } else {
                        PrimaryButton(title: "Next", systemImage: "chevron.right") {
                            withAnimation { page += 1 }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 480)
            }
        }
        .preferredColorScheme(.dark)
    }
}
