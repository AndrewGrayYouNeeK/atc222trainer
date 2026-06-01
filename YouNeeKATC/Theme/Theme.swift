import SwiftUI

/// Central palette and typography for the whole app. Tuned to mimic a phosphor
/// CRT air-traffic-control display: deep black glass with layered phosphor-green
/// emission and amber/red alerting. Kept as one source of truth so the menu,
/// HUD and radar all share the same visual language.
enum ATC {

    // MARK: Surfaces
    static let background = Color(red: 0.02, green: 0.05, blue: 0.04)
    static let void = Color(red: 0.01, green: 0.02, blue: 0.015)
    static let panel = Color(red: 0.05, green: 0.10, blue: 0.09)
    static let panelRaised = Color(red: 0.07, green: 0.13, blue: 0.11)

    // MARK: Phosphor greens
    static let phosphor = Color(red: 0.20, green: 1.00, blue: 0.55)
    static let phosphorBright = Color(red: 0.55, green: 1.00, blue: 0.70)
    static let phosphorDim = Color(red: 0.20, green: 1.00, blue: 0.55).opacity(0.45)
    static let grid = Color(red: 0.20, green: 0.85, blue: 0.55).opacity(0.22)
    static let gridFaint = Color(red: 0.20, green: 0.85, blue: 0.55).opacity(0.10)

    // MARK: Alerting
    static let selected = Color(red: 1.00, green: 0.85, blue: 0.30)
    static let caution = Color(red: 1.00, green: 0.74, blue: 0.18)
    static let conflict = Color(red: 1.00, green: 0.30, blue: 0.24)
    static let emergency = Color(red: 1.00, green: 0.20, blue: 0.35)
    static let success = Color(red: 0.35, green: 0.95, blue: 1.00)

    // MARK: Text
    static let hud = Color(red: 0.70, green: 0.95, blue: 0.80)
    static let hudDim = Color(red: 0.45, green: 0.70, blue: 0.55)

    // MARK: Typography
    /// Monospaced display face used across HUD and data blocks.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Radial wash drawn behind the scope to give the glass a domed sheen.
    static var scopeGradient: RadialGradient {
        RadialGradient(
            colors: [background, void],
            center: .center,
            startRadius: 0,
            endRadius: 700
        )
    }
}

/// Layered shadow that fakes the bloom of a phosphor element. Respects the
/// Reduce Motion / Reduce Transparency preferences by toning the glow down.
struct PhosphorGlow: ViewModifier {
    var color: Color = ATC.phosphor
    var radius: CGFloat = 6
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content
                .shadow(color: color.opacity(0.9), radius: radius * 0.35)
                .shadow(color: color.opacity(0.5), radius: radius)
        }
    }
}

extension View {
    func phosphorGlow(_ color: Color = ATC.phosphor, radius: CGFloat = 6) -> some View {
        modifier(PhosphorGlow(color: color, radius: radius))
    }
}
