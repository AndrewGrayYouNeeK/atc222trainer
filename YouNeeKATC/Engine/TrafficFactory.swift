import CoreGraphics
import Foundation

/// Generates believable callsigns and seeds new aircraft at the sector edges or
/// the runway, with sensible initial performance for their phase of flight.
enum TrafficFactory {

    private struct Airline { let code: String; let spoken: String }

    private static let airlines: [Airline] = [
        Airline(code: "DAL", spoken: "Delta"),
        Airline(code: "UAL", spoken: "United"),
        Airline(code: "AAL", spoken: "American"),
        Airline(code: "SWA", spoken: "Southwest"),
        Airline(code: "JBU", spoken: "JetBlue"),
        Airline(code: "FFT", spoken: "Frontier"),
        Airline(code: "ASA", spoken: "Alaska"),
        Airline(code: "NKS", spoken: "Spirit")
    ]

    /// Avoids two aircraft sharing a callsign in the same run.
    static func uniqueCallsign(existing: Set<String>, prop: Bool) -> (code: String, spoken: String) {
        for _ in 0..<40 {
            if prop {
                // General-aviation tail number, e.g. N4827K.
                let digits = (0..<4).map { _ in String(Int.random(in: 0...9)) }.joined()
                let letter = String("ABCDEFGHJKLMNPQRSTUVWXYZ".randomElement()!)
                let code = "N\(digits)\(letter)"
                if !existing.contains(code) { return (code, code) }
            } else {
                let airline = airlines.randomElement()!
                let number = Int.random(in: 100...999)
                let code = "\(airline.code)\(number)"
                if !existing.contains(code) {
                    return (code, "\(airline.spoken) \(number)")
                }
            }
        }
        let fallback = "GA\(Int.random(in: 1000...9999))"
        return (fallback, fallback)
    }

    /// Builds an arrival entering at the given fix, pointed roughly at the field.
    static func makeArrival(at fix: Fix, existing: Set<String>) -> Aircraft {
        let prop = Double.random(in: 0...1) < 0.18
        let kind: AircraftKind = prop ? .prop : (Bool.random() ? .jet : .heavy)
        let (code, spoken) = uniqueCallsign(existing: existing, prop: prop)
        let inbound = Nav.bearing(from: fix.position, to: .zero)
        return Aircraft(
            callsign: code,
            spoken: spoken,
            kind: kind,
            intent: .arrival,
            position: fix.position,
            heading: inbound + Double.random(in: -8...8),
            altitude: Double(Int.random(in: 60...110) * 100),
            speed: Double(Int.random(in: 230...290))
        )
    }

    /// Builds a departure rolling off the active runway, climbing out.
    static func makeDeparture(runway: Runway, exitFix: Fix, existing: Set<String>) -> Aircraft {
        let prop = Double.random(in: 0...1) < 0.22
        let kind: AircraftKind = prop ? .prop : .jet
        let (code, spoken) = uniqueCallsign(existing: existing, prop: prop)
        return Aircraft(
            callsign: code,
            spoken: spoken,
            kind: kind,
            intent: .departure(fix: exitFix.name),
            position: runway.threshold,
            heading: runway.heading,
            altitude: 1000,
            speed: kind.minSpeed + 20,
            targetAltitude: 5000,
            targetSpeed: kind.minSpeed + 60
        )
    }
}
