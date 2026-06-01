import Foundation

/// One lesson in the controller academy. Each lesson pairs a real-world *concept*
/// (the WHY and the procedure a trainee would actually be taught) with standard
/// phraseology to say and a hands-on objective to demonstrate on the live scope.
///
/// Content aims for real-world accuracy (FAA/ICAO conventions). Where the game
/// simplifies operations, the `realismNote` says so honestly.
struct AcademyLesson: Identifiable, Sendable {

    enum Kind: Sendable { case drill, checkRide }

    /// The scripted traffic picture a lesson sets up.
    enum Scenario: Sendable {
        case orientation     // one slow arrival to inspect
        case vectorBasics    // one high/fast arrival to turn + descend
        case separation      // two co-altitude targets in conflict
        case finalApproach   // one arrival to vector onto final + land
        case sequencing      // two arrivals in trail; slow the trailer
        case departure       // one departure to climb + hand off
        case emergency       // one arrival that will declare an emergency
        case checkRide       // live traffic (engine spawns)
    }

    /// What the student must demonstrate to pass the lesson.
    enum Goal: Sendable, Equatable {
        case select
        case vector(heading: Double, altitudeAtOrBelow: Double?)
        case separate
        case land(Int)
        case spacing(maxTrailingSpeed: Double)
        case handoff(Int)
        case handleEmergency
        case certify(handled: Int)
    }

    let id: Int
    let moduleNumber: Int
    let moduleTitle: LocalizedStringResource
    let title: LocalizedStringResource
    let kind: Kind
    let concept: LocalizedStringResource          // the WHY + the real procedure
    let phraseology: [LocalizedStringResource]    // standard calls to say
    let realismNote: LocalizedStringResource?     // honest note where we simplify
    let objective: LocalizedStringResource        // the hands-on task
    let scenario: Scenario
    let goal: Goal

    static let curriculum: [AcademyLesson] = [

        // MARK: Module 1 — Fundamentals
        AcademyLesson(
            id: 0, moduleNumber: 1, moduleTitle: "Fundamentals",
            title: "The Scope & the Data Block",
            kind: .drill,
            concept: """
            Welcome to Apex Approach. You're a TRACON-style approach controller working traffic within about 40 NM of the field. The rings are spaced 10 NM apart; the airport sits at the center. Aircraft enter at named fixes and you guide them to the runway or out to a departure gate.

            Every target carries a data block: callsign, altitude in hundreds of feet (“070” = 7,000 ft), and groundspeed. The line off the target is the velocity leader — it points where the aircraft is going, and it grows with speed. Headings are magnetic and spoken as three digits (360 = north, 090 = east). At and above 18,000 ft, altitudes become “flight levels.”
            """,
            phraseology: [
                "You identify yourself as “Apex Approach.”",
                "Pilots read instructions back to you — that read-back is how you confirm they heard it right."
            ],
            realismNote: "Real scopes show far more (Mode C, full data tags, automatic conflict alerts, weather). We keep the data block to callsign / altitude / speed.",
            objective: "Tap the highlighted aircraft to select it and read its data block.",
            scenario: .orientation,
            goal: .select
        ),
        AcademyLesson(
            id: 1, moduleNumber: 1, moduleTitle: "Fundamentals",
            title: "Headings & Altitudes",
            kind: .drill,
            concept: """
            Your two primary tools are vectors (headings) and altitudes. Assign a heading and the aircraft turns at a standard rate, taking the shortest way around unless you specify a direction. Assign an altitude with “climb/descend and maintain.”

            Instructions are given in a consistent order — generally turn, then altitude, then speed — and always addressed to the callsign first. Descend arrivals in stages as they get closer so they’re low enough to join the approach.
            """,
            phraseology: [
                "“United 319, turn left heading 270.”",
                "“United 319, descend and maintain 5,000.”",
                "Pilot read-back: “Left 270, down to 5,000, United 319.”"
            ],
            realismNote: nil,
            objective: "Turn United 319 to heading 270 and descend to 5,000 or below.",
            scenario: .vectorBasics,
            goal: .vector(heading: 270, altitudeAtOrBelow: 5000)
        ),

        // MARK: Module 2 — Separation
        AcademyLesson(
            id: 2, moduleNumber: 2, moduleTitle: "Separation",
            title: "Separation Standards",
            kind: .drill,
            concept: """
            Your #1 job is separation. In approach control the standard minima are 3 NM laterally OR 1,000 ft vertically. As long as ONE of those is satisfied between any two aircraft, they’re legally separated — they can be a half-mile apart laterally if they’re 1,000 ft apart vertically, and vice-versa.

            When two targets close inside the minima you’ll get a conflict alert (the halo). Fix it early: assign different altitudes, or turn one onto a diverging vector. Issuing a traffic advisory while you do it is good practice.
            """,
            phraseology: [
                "“United 319, traffic 12 o’clock, 3 miles, opposite direction — descend and maintain 4,000.”",
                "Or vector: “United 319, turn right heading 090 for traffic.”"
            ],
            realismNote: "Real separation also factors wake-turbulence categories and facility-specific rules. We model the common 3 NM / 1,000 ft approach standard.",
            objective: "Two aircraft are in conflict. Restore 3 NM apart OR 1,000 ft of vertical.",
            scenario: .separation,
            goal: .separate
        ),

        // MARK: Module 3 — Arrivals
        AcademyLesson(
            id: 3, moduleNumber: 3, moduleTitle: "Arrivals & Final",
            title: "Vectoring to Final",
            kind: .drill,
            concept: """
            To land, an arrival must be lined up with the final approach course — the extended runway centerline — then descended on a roughly 3° glidepath to the runway. You vector the aircraft to intercept the centerline at a shallow angle (30° or less), get it down to the intercept altitude, and clear it for the approach.

            Sequence: turn to intercept → descend → clear to land. If it arrives too high or too fast to be stable, it’ll go around — better than an unsafe landing.
            """,
            phraseology: [
                "“Delta 482, turn left heading 340 to join the final approach course.”",
                "“Delta 482, descend and maintain 2,000.”",
                "“Delta 482, cleared to land runway 34.”"
            ],
            realismNote: "Real ops split this between Approach (vectors + “cleared ILS”) and Tower (“cleared to land”). We fold it into one “cleared to land.”",
            objective: "Vector Delta 482 onto final, descend it, and clear it to land.",
            scenario: .finalApproach,
            goal: .land(1)
        ),
        AcademyLesson(
            id: 4, moduleNumber: 3, moduleTitle: "Arrivals & Final",
            title: "Sequencing & Speed Control",
            kind: .drill,
            concept: """
            When several arrivals funnel to one runway, speed is how you build and protect the spacing between them. Slow a fast trailing aircraft so it doesn’t compress on the one ahead; you generally work down from around 210 knots to 170, then to final-approach speed.

            Good sequencing keeps a steady stream landing without anyone having to go around. Speed control is cheaper than vectors — reach for it first.
            """,
            phraseology: [
                "“American 502, reduce speed to 180.”",
                "“American 502, reduce speed to 170, you’re number two following traffic on final.”"
            ],
            realismNote: nil,
            objective: "Two are in trail and compressing. Slow the trailing jet to 180 knots or less.",
            scenario: .sequencing,
            goal: .spacing(maxTrailingSpeed: 180)
        ),

        // MARK: Module 4 — Departures
        AcademyLesson(
            id: 5, moduleNumber: 4, moduleTitle: "Departures",
            title: "Departures & Handoffs",
            kind: .drill,
            concept: """
            Departures come off the runway climbing. You give them a climb and turn them on course toward their departure fix, keeping them clear of your arrivals. Once they’re established and leaving your airspace, you hand them off to the next sector (Center).

            Keep climbing traffic and descending arrivals apart — the same 3 NM / 1,000 ft rule applies.
            """,
            phraseology: [
                "“JetBlue 412, climb and maintain 5,000.”",
                "“JetBlue 412, proceed direct NORTH.”",
                "“JetBlue 412, contact Center. Good day.”"
            ],
            realismNote: "We model the handoff as sending the aircraft direct to its exit fix and out of the sector, rather than a frequency change.",
            objective: "Climb the departure and send it direct NORTH to hand it off.",
            scenario: .departure,
            goal: .handoff(1)
        ),

        // MARK: Module 5 — Abnormal & emergency
        AcademyLesson(
            id: 6, moduleNumber: 5, moduleTitle: "Emergencies",
            title: "Priority & Emergency Handling",
            kind: .drill,
            concept: """
            An aircraft in distress gets priority over everything else. When a pilot declares an emergency (“Mayday” for distress, “Pan-pan” for urgency), you make them number one: shortest routing to the runway, expedited descent, and you move other traffic out of their way.

            Acknowledge, prioritize, and get them down. Ask what they need — souls on board and fuel remaining — so the airport can prepare, but flying the aircraft to a safe landing comes first.
            """,
            phraseology: [
                "“Delta 482, roger your emergency. You’re number one. Descend and maintain 3,000, cleared to land runway 34.”",
                "“Delta 482, say souls on board and fuel remaining.”"
            ],
            realismNote: "We simplify the radio back-and-forth. The skill that matters: drop everything and get the emergency safely on the ground first.",
            objective: "An aircraft is declaring an emergency. Get it down first — before its time runs out.",
            scenario: .emergency,
            goal: .handleEmergency
        ),

        // MARK: Module 6 — Certification
        AcademyLesson(
            id: 7, moduleNumber: 6, moduleTitle: "Certification",
            title: "Certification Check Ride",
            kind: .checkRide,
            concept: """
            Put it all together against live traffic, exactly like a real certification check ride. Maintain separation, sequence arrivals onto final, climb and hand off departures, and handle whatever the day throws at you — all at once.

            You’re cleared to certify once you’ve handled 6 aircraft without losing the picture. Stay ahead of it, keep them moving, and don’t let two get close. Good luck, controller.
            """,
            phraseology: [
                "Everything you’ve learned — turns, altitudes, speed control, approach clearances, handoffs.",
                "Work the callsigns. Keep your scan moving."
            ],
            realismNote: "A real check ride is graded live by a training supervisor over a full session. Here, success is handling 6 aircraft cleanly on relaxed-pace traffic.",
            objective: "Handle 6 aircraft cleanly to earn your certification.",
            scenario: .checkRide,
            goal: .certify(handled: 6)
        )
    ]
}
