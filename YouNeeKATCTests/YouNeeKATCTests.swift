import Testing
import CoreGraphics
@testable import YouNeeKATC

// MARK: - Phraseology (retained flavour utility)

struct ATCPhraseologyTests {

    @Test func parsesTurnLeftHeading() {
        let result = ATCPhraseology.parse("turn left heading two seven zero", callsigns: [])
        #expect(result.commands == [.turn(.left, heading: 270)])
    }

    @Test func parsesClimbAndMaintain() {
        let result = ATCPhraseology.parse("climb and maintain five thousand", callsigns: [])
        #expect(result.commands == [.climb(altitude: 5000)])
    }

    @Test func parsesFlightLevel() {
        let result = ATCPhraseology.parse("climb and maintain flight level two five zero", callsigns: [])
        #expect(result.commands == [.climb(altitude: 25000)])
    }

    @Test func resolvesAirlineCallsignAndCompoundInstruction() {
        let candidate = CallsignCandidate(callsign: "DAL482", spoken: "Delta 482")
        let result = ATCPhraseology.parse(
            "Delta four eight two turn left heading two seven zero descend and maintain three thousand",
            candidates: [candidate]
        )
        #expect(result.targetCallsign == "DAL482")
        #expect(result.commands == [.turn(.left, heading: 270), .descend(altitude: 3000)])
    }
}

// MARK: - Navigation maths

struct NavTests {

    @Test func normalizeWraps() {
        #expect(Nav.normalize(370) == 10)
        #expect(Nav.normalize(-10) == 350)
        #expect(Nav.normalize(720) == 0)
    }

    @Test func signedDeltaPicksShortestTurn() {
        #expect(Nav.signedDelta(from: 350, to: 10) == 20)   // turn right
        #expect(Nav.signedDelta(from: 10, to: 350) == -20)  // turn left
    }

    @Test func bearingPointsNorth() {
        let north = Nav.bearing(from: .zero, to: CGPoint(x: 0, y: 10))
        #expect(north == 0)
        let east = Nav.bearing(from: .zero, to: CGPoint(x: 10, y: 0))
        #expect(east == 90)
    }

    @Test func distanceIsEuclidean() {
        #expect(Nav.distance(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)) == 5)
    }
}

// MARK: - Airport

struct AirportTests {

    @Test func activeRunwayFacesTheWind() {
        // Wind from 340° should favour runway 34 (340°) over its 16 reciprocal.
        let runway = Airport.kapx.activeRunway(windFrom: 340)
        #expect(runway.heading == 340)
        let opposite = Airport.kapx.activeRunway(windFrom: 160)
        #expect(opposite.heading == 160)
    }

    @Test func sectorDefinesArrivalAndDepartureFixes() {
        #expect(!Airport.kapx.arrivalFixes.isEmpty)
        #expect(!Airport.kapx.departureFixes.isEmpty)
    }

    @Test func reciprocalRunwayIsOpposite() {
        let main = Airport.kapx.runways[0]
        #expect(main.reciprocal.heading == 160)
    }
}

// MARK: - Aircraft model

struct AircraftTests {

    @Test func altitudeAndSpeedLabelsFormat() {
        let ac = Aircraft(callsign: "DAL1", spoken: "Delta 1", kind: .jet, intent: .arrival,
                          position: CGPoint(x: 10, y: 0), heading: 270, altitude: 7000, speed: 250)
        #expect(ac.altitudeLabel == "070")
        #expect(ac.speedLabel == "250")
        #expect(ac.isArrival)
        #expect(ac.rangeNM == 10)
    }
}

// MARK: - Engine commands

@MainActor
struct GameEngineTests {

    private func engineWithArrival() -> (GameEngine, Aircraft) {
        let engine = GameEngine(difficulty: .standard)
        let ac = Aircraft(callsign: "UAL5", spoken: "United 5", kind: .jet, intent: .arrival,
                          position: CGPoint(x: 20, y: 20), heading: 200, altitude: 9000, speed: 280)
        engine.injectForTesting(ac)
        return (engine, ac)
    }

    @Test func setHeadingAssignsTarget() {
        let (engine, _) = engineWithArrival()
        engine.setHeading(340)
        #expect(engine.selected?.targetHeading == 340)
    }

    @Test func setAltitudeAssignsTarget() {
        let (engine, _) = engineWithArrival()
        engine.setAltitude(3000)
        #expect(engine.selected?.targetAltitude == 3000)
    }

    @Test func setSpeedClampsToPerformance() {
        let (engine, _) = engineWithArrival()
        engine.setSpeed(50)   // below a jet's minimum
        #expect(engine.selected?.targetSpeed == AircraftKind.jet.minSpeed)
    }

    @Test func clearToLandFlagsArrival() {
        let (engine, _) = engineWithArrival()
        engine.clearSelectedToLand()
        #expect(engine.selected?.clearedToLand == true)
    }

    @Test func difficultyTunesLives() {
        #expect(Difficulty.standard.startingLives == 3)
        #expect(Difficulty.relaxed.startingLives == 5)
    }

    @Test func appliesVoiceTransmissionToTargetedAircraft() {
        let engine = GameEngine(difficulty: .standard)
        let ac = Aircraft(callsign: "DAL482", spoken: "Delta 482", kind: .jet, intent: .arrival,
                          position: CGPoint(x: 20, y: 20), heading: 200, altitude: 9000, speed: 280)
        engine.injectForTesting(ac)
        let tx = ParsedTransmission(
            targetCallsign: "DAL482", spokenCallsign: "Delta 482",
            commands: [.turn(.left, heading: 270), .descend(altitude: 3000)],
            rawText: "Delta 482 turn left heading 270 descend and maintain 3000"
        )
        #expect(engine.apply(tx))
        let target = engine.aircraft.first { $0.callsign == "DAL482" }
        #expect(target?.targetHeading == 270)
        #expect(target?.targetAltitude == 3000)
        #expect(target?.turnDirection == .left)
    }

    @Test func ignoresTransmissionForUnknownCallsign() {
        let engine = GameEngine(difficulty: .standard)
        let tx = ParsedTransmission(targetCallsign: "XXX999", spokenCallsign: nil,
                                    commands: [.contactTower], rawText: "")
        #expect(!engine.apply(tx))
    }

    @Test func endToEndVoiceParseAndApply() {
        let engine = GameEngine(difficulty: .standard)
        let ac = Aircraft(callsign: "UAL319", spoken: "United 319", kind: .jet, intent: .arrival,
                          position: CGPoint(x: -15, y: 18), heading: 160, altitude: 8000, speed: 270)
        engine.injectForTesting(ac)
        let tx = ATCPhraseology.parse(
            "United 319, reduce speed two one zero",
            candidates: engine.callsignCandidates
        )
        #expect(engine.apply(tx))
        #expect(engine.aircraft.first { $0.callsign == "UAL319" }?.targetSpeed == 210)
    }
}

// MARK: - Persistence model

struct PlayerProfileTests {

    @Test func bestScoreFiltersByDifficulty() {
        var profile = PlayerProfile()
        profile.runs = [
            RunResult(score: 1000, landings: 5, departures: 2, emergenciesHandled: 0,
                      bestStreak: 3, durationSeconds: 120, difficulty: .standard, date: .now),
            RunResult(score: 4000, landings: 10, departures: 3, emergenciesHandled: 1,
                      bestStreak: 6, durationSeconds: 240, difficulty: .intense, date: .now)
        ]
        #expect(profile.bestScore(for: .standard) == 1000)
        #expect(profile.bestScore(for: .intense) == 4000)
        #expect(profile.bestScore(for: .relaxed) == 0)
        #expect(profile.allTimeBest == 4000)
    }

    @Test func lifetimeHandledSumsLandingsAndDepartures() {
        var p = PlayerProfile()
        p.lifetimeLandings = 30
        p.lifetimeDepartures = 12
        #expect(p.lifetimeHandled == 42)
    }
}

// MARK: - Career progression

struct ControllerRankTests {

    @Test func rankClimbsWithHandledTotal() {
        #expect(ControllerRank.rank(forHandled: 0).level == 0)
        #expect(ControllerRank.rank(forHandled: 14).level == 0)
        #expect(ControllerRank.rank(forHandled: 15).level == 1)
        #expect(ControllerRank.rank(forHandled: 50).level == 2)
        #expect(ControllerRank.rank(forHandled: 1_000_000).level == ControllerRank.ladder.count - 1)
    }

    @Test func progressIsBoundedAndNextResolves() {
        let rank = ControllerRank.rank(forHandled: 20)
        let p = rank.progress(handled: 20)
        #expect(p >= 0 && p <= 1)
        #expect(rank.next?.level == rank.level + 1)
        #expect(ControllerRank.ladder.last?.next == nil)
    }
}

// MARK: - Academy curriculum

struct AcademyTests {

    @Test func curriculumIsOrderedAndCertifies() {
        let curriculum = AcademyLesson.curriculum
        #expect(!curriculum.isEmpty)
        #expect(curriculum.map(\.id) == Array(0..<curriculum.count))
        #expect(curriculum.last?.kind == .checkRide)
        // Every drill must carry teaching content.
        for lesson in curriculum {
            #expect(!String(localized: lesson.objective).isEmpty)
        }
    }

    @Test func onlyTheFinalLessonIsACheckRide() {
        let checkRides = AcademyLesson.curriculum.filter { $0.kind == .checkRide }
        #expect(checkRides.count == 1)
    }
}
