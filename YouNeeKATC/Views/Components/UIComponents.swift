import SwiftUI

// MARK: - Buttons

/// Primary phosphor-filled action button used for the strongest call to action.
struct PrimaryButton: View {
    let title: LocalizedStringResource
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(ATC.mono(18, weight: .bold))
            .foregroundStyle(ATC.void)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ATC.phosphor)
            )
            .phosphorGlow(radius: 10)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Secondary outlined button for menu navigation.
struct SecondaryButton: View {
    let title: LocalizedStringResource
    var systemImage: String?
    var tint: Color = ATC.phosphor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).frame(width: 22) }
                Text(title)
                Spacer(minLength: 0)
            }
            .font(ATC.mono(16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ATC.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tint.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// Adds a tactile press scale to any button without overriding its visuals.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Panel surface

/// Rounded glass panel used to group HUD and menu content.
struct PanelBackground: ViewModifier {
    var corner: CGFloat = 16
    var stroke: Color = ATC.phosphor.opacity(0.25)
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(ATC.panel.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func panel(corner: CGFloat = 16, stroke: Color = ATC.phosphor.opacity(0.25)) -> some View {
        modifier(PanelBackground(corner: corner, stroke: stroke))
    }
}

// MARK: - Animated CRT scanline backdrop

/// Subtle moving scanlines + vignette that sit behind menus to keep the CRT
/// aesthetic consistent. Honors Reduce Motion by freezing the scan.
struct ScopeBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ATC.scopeGradient.ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas { context, size in
                    let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 18
                    let spacing: CGFloat = 3
                    var y = CGFloat(phase.truncatingRemainder(dividingBy: Double(spacing)))
                    while y < size.height {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                        context.fill(Path(rect), with: .color(.black.opacity(0.10)))
                        y += spacing
                    }
                }
                .ignoresSafeArea()
                .blendMode(.multiply)
            }
        }
    }
}
