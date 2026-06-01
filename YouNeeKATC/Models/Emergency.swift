import Foundation

/// High-priority abnormal scenarios the controller must handle.
enum EmergencyType: String, CaseIterable, Codable, Sendable {
    case birdStrike
    case engineFailure
    case medical
    case lowFuel
    case terroristThreat
    case microburst

    var title: String {
        switch self {
        case .birdStrike: return "Bird Strike"
        case .engineFailure: return "Engine Failure"
        case .medical: return "Medical Emergency"
        case .lowFuel: return "Low Fuel"
        case .terroristThreat: return "Security Threat"
        case .microburst: return "Microburst Escape"
        }
    }

    /// Urgency score used for reward balancing.
    var severity: Int {
        switch self {
        case .medical, .birdStrike: return 2
        case .lowFuel, .engineFailure: return 3
        case .microburst: return 4
        case .terroristThreat: return 5
        }
    }
}

/// One active emergency attached to a specific aircraft.
struct Emergency: Identifiable, Equatable, Sendable {
    let id: UUID
    let aircraftID: UUID
    let callsign: String
    let type: EmergencyType
    var startedAt: Date
    var deadline: Date
    var acknowledged: Bool
    var resolved: Bool

    init(
        id: UUID = UUID(),
        aircraftID: UUID,
        callsign: String,
        type: EmergencyType,
        startedAt: Date = .now,
        deadline: Date,
        acknowledged: Bool = false,
        resolved: Bool = false
    ) {
        self.id = id
        self.aircraftID = aircraftID
        self.callsign = callsign
        self.type = type
        self.startedAt = startedAt
        self.deadline = deadline
        self.acknowledged = acknowledged
        self.resolved = resolved
    }

    var remaining: TimeInterval { deadline.timeIntervalSinceNow }
    var isExpired: Bool { remaining <= 0 }
}
