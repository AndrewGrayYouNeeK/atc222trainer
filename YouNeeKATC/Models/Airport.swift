import CoreGraphics
import Foundation

/// A named navigation fix on the sector boundary. Arrivals appear at one and
/// departures must be vectored out through one.
struct Fix: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String          // five-letter style name, e.g. "GOLDN"
    let position: CGPoint     // NM from the field
    let isArrival: Bool       // true: traffic enters here; false: exit gate
}

/// A landing surface. `heading` is the direction an aircraft travels while
/// landing on it; the reciprocal end is generated automatically.
struct Runway: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String          // "16" / "34"
    let heading: Double        // landing course in degrees
    /// Threshold offset from the field centre in NM (touchdown point).
    let threshold: CGPoint
    /// Length used purely for drawing, in NM.
    let length: Double

    /// The opposite-direction runway sharing the same strip.
    var reciprocal: Runway {
        let recipName = String(format: "%02d", Int((heading + 180).normalizedHeading / 10).clampedRunwayNumber)
        return Runway(
            name: recipName,
            heading: (heading + 180).normalizedHeading,
            threshold: CGPoint(x: -threshold.x, y: -threshold.y),
            length: length
        )
    }
}

private extension Int {
    /// Runway numbers run 01...36; 00 should read as 36.
    var clampedRunwayNumber: Int { self == 0 ? 36 : self }
}

/// A controllable airfield: the centre of the sector with its runways and the
/// boundary fixes that feed and drain traffic.
struct Airport: Identifiable, Equatable, Sendable {
    var id: String { icao }
    let icao: String
    let name: String
    let runways: [Runway]
    let fixes: [Fix]

    var arrivalFixes: [Fix] { fixes.filter(\.isArrival) }
    var departureFixes: [Fix] { fixes.filter { !$0.isArrival } }

    /// Picks the runway whose landing course best opposes the wind (land into
    /// the wind). `windFrom` is the direction the wind blows from.
    func activeRunway(windFrom: Double) -> Runway {
        let candidates = runways.flatMap { [$0, $0.reciprocal] }
        return candidates.min { a, b in
            abs(Nav.signedDelta(from: a.heading, to: windFrom)) <
            abs(Nav.signedDelta(from: b.heading, to: windFrom))
        } ?? runways[0]
    }

    // MARK: Catalog

    /// The shipping sector: a fictional but believable approach control.
    static let kapx = Airport(
        icao: "KAPX",
        name: "Apex Approach",
        runways: [
            Runway(name: "34", heading: 340, threshold: CGPoint(x: 0, y: -0.9), length: 1.6)
        ],
        fixes: [
            Fix(name: "GOLDN", position: CGPoint(x: -30, y: 22), isArrival: true),
            Fix(name: "BRAVO", position: CGPoint(x: 32, y: 16), isArrival: true),
            Fix(name: "SIERA", position: CGPoint(x: 26, y: -28), isArrival: true),
            Fix(name: "MAPLE", position: CGPoint(x: -28, y: -24), isArrival: true),
            Fix(name: "NORTH", position: CGPoint(x: 4, y: 38), isArrival: false),
            Fix(name: "SOUTH", position: CGPoint(x: -6, y: -38), isArrival: false)
        ]
    )

    /// All shippable sectors. v1.0 ships one; add entries here to expand.
    static let catalog: [Airport] = [.kapx]
}
