import Foundation

/// Sector weather snapshot consumed by physics and HUD.
struct Weather: Equatable, Sendable {
    /// Wind direction in degrees, where the wind is blowing FROM.
    var windDirection: Double
    /// Wind speed in knots.
    var windSpeed: Int
    /// Visibility in statute miles.
    var visibility: Double
    /// Per-minute chance of microburst generation while enabled.
    var microburstChance: Double

    static let calm = Weather(
        windDirection: 270,
        windSpeed: 4,
        visibility: 10,
        microburstChance: 0.01
    )
}
