import CoreGraphics
import Foundation

/// Performance class. Drives speed limits, turn rate and the marketing label.
enum AircraftKind: String, CaseIterable, Codable, Sendable {
    case heavy   // wide-body
    case jet     // narrow-body
    case prop    // turboprop / GA

    var minSpeed: Double {
        switch self {
        case .heavy: return 150
        case .jet: return 140
        case .prop: return 90
        }
    }
    var maxSpeed: Double {
        switch self {
        case .heavy: return 320
        case .jet: return 300
        case .prop: return 210
        }
    }
    var turnRate: Double {   // degrees per second at standard rate
        switch self {
        case .heavy: return 2.6
        case .jet: return 3.0
        case .prop: return 3.4
        }
    }
    var climbRate: Double {  // feet per second
        switch self {
        case .heavy: return 28
        case .jet: return 38
        case .prop: return 22
        }
    }
}

/// Whether the aircraft is arriving (must land) or departing (must reach a fix).
enum FlightIntent: Equatable, Sendable {
    case arrival
    case departure(fix: String)
}

/// The lifecycle stage that scoring and the simulation key off of.
enum AircraftPhase: Equatable, Sendable {
    case enroute        // being vectored
    case established    // captured the final approach course
    case landing        // on the glide, decelerating
    case completed      // landed or handed off successfully — remove + score
    case crashed        // lost separation — game over event
}

/// A single controlled aircraft. A value type so the engine can mutate copies
/// cheaply inside its tick loop and SwiftUI can diff cleanly.
struct Aircraft: Identifiable, Equatable, Sendable {
    let id = UUID()
    let callsign: String          // canonical, e.g. "DAL482"
    let spoken: String            // telephony, e.g. "Delta 482"
    let kind: AircraftKind
    let intent: FlightIntent

    /// Position relative to the field, in nautical miles.
    var position: CGPoint
    var heading: Double            // degrees, 0 = north
    var altitude: Double           // feet
    var speed: Double              // knots

    // Targets the autopilot flies toward (nil = hold current).
    var targetHeading: Double?
    var targetAltitude: Double?
    var targetSpeed: Double?
    var turnDirection: TurnDirection = .auto

    var phase: AircraftPhase = .enroute
    var clearedToLand = false
    var handoffFix: String?        // the fix a departure has been sent direct to
    var spawnedAt: Date = .now
    var lastInstruction: String = ""
    var trail: [CGPoint] = []

    /// Transient UI flags refreshed every tick by the engine.
    var conflict = false
    var emergency: EmergencyType?

    enum TurnDirection: Sendable { case auto, left, right }

    // MARK: Derived display values

    /// Flight-level style altitude, e.g. 7000 ft -> "070".
    var altitudeLabel: String { String(format: "%03d", Int((altitude / 100).rounded())) }
    var speedLabel: String { String(format: "%03d", Int(speed.rounded())) }
    var rangeNM: Double { position.rangeFromField }
    var isArrival: Bool { if case .arrival = intent { return true }; return false }

    /// Human-readable data block used by the radar and accessibility labels.
    var dataBlock: String { "\(callsign) \(altitudeLabel) \(speedLabel)" }
}
