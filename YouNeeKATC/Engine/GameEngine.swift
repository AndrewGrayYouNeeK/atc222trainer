import CoreGraphics
import Foundation
import Observation

/// The simulation core. Owns every aircraft, the scoring and lives state, the
/// difficulty ramp, conflict detection and the arrival/departure gameplay loop.
///
/// It is intentionally free of UIKit/SwiftUI, audio and Game Center so it can be
/// unit-tested in isolation. The view layer drives it by calling `advance(to:)`
/// once per display frame and drains `events` for feedback.
@MainActor
@Observable
final class GameEngine {

    // MARK: Published state
    private(set) var aircraft: [Aircraft] = []
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var landings = 0
    private(set) var departures = 0
    private(set) var emergenciesHandled = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var emergencies: [Emergency] = []
    private(set) var isRunning = false
    private(set) var isPaused = false
    var selectedID: UUID?

    let airport: Airport
    let weather: Weather
    let activeRunway: Runway
    private(set) var difficulty: Difficulty

    /// Feedback sink set by the coordinator (haptics / audio / leaderboards /
    /// presenting game-over). Invoked on the main actor as events occur.
    var onEvent: ((GameEvent) -> Void)?

    /// Training mode disables spawns, emergencies and strikes for the tutorial.
    let isTraining: Bool

    // MARK: Private timing
    private var simTask: Task<Void, Never>?
    private var spawnAccumulator: Double = 0
    private var emergencyAccumulator: Double = 0
    private var nextMilestone = 500

    // MARK: Tunables
    private let sectorRadius: Double = 42      // NM; beyond this aircraft leave
    private let conflictRange: Double = 3.0    // NM lateral caution threshold
    private let conflictVertical: Double = 1000 // ft caution threshold
    private let collisionRange: Double = 0.9   // NM
    private let collisionVertical: Double = 400 // ft

    // MARK: Init

    init(difficulty: Difficulty, airport: Airport = .kapx, training: Bool = false) {
        self.difficulty = difficulty
        self.airport = airport
        self.weather = .calm
        self.activeRunway = airport.activeRunway(windFrom: Weather.calm.windDirection)
        self.isTraining = training
        self.lives = training ? 99 : difficulty.startingLives
    }

    var selected: Aircraft? {
        guard let selectedID else { return nil }
        return aircraft.first { $0.id == selectedID }
    }

    /// Total aircraft successfully handled this run (landed + handed off).
    var handled: Int { landings + departures }

    // MARK: Run lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        if isTraining {
            seedTrainingAircraft()
        } else {
            seedInitialTraffic()
        }
        launchLoop()
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func quit() {
        guard isRunning else { return }
        finish(reason: .quit)
    }

    /// Releases the simulation task. Call from the view's `onDisappear`.
    func teardown() {
        simTask?.cancel()
        simTask = nil
    }

    // MARK: Simulation loop

    /// Runs the fixed-tick loop on the main actor. Mutating engine state here
    /// (rather than inside the SwiftUI render pass) keeps view updates clean.
    private func launchLoop() {
        guard simTask == nil else { return }
        simTask = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await clock.sleep(for: .milliseconds(16))
                guard let self, self.isRunning else { continue }
                let now = clock.now
                let elapsed = last.duration(to: now)
                last = now
                guard !self.isPaused else { continue }
                let dt = min(max(Self.seconds(elapsed), 0), 0.1)
                if dt > 0 { self.tick(dt: dt) }
            }
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        let comps = duration.components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }

    // MARK: Seeding

    private func seedInitialTraffic() {
        for fix in airport.arrivalFixes.shuffled().prefix(2) {
            aircraft.append(TrafficFactory.makeArrival(at: fix, existing: callsigns))
        }
    }

    private func seedTrainingAircraft() {
        let fix = airport.arrivalFixes.first { $0.name == "GOLDN" } ?? airport.arrivalFixes[0]
        var trainer = TrafficFactory.makeArrival(at: fix, existing: [])
        trainer.altitude = 6000
        trainer.speed = 250
        aircraft = [trainer]
        selectedID = trainer.id
    }

    private var callsigns: Set<String> { Set(aircraft.map(\.callsign)) }

    // MARK: Player commands

    func select(_ id: UUID) {
        selectedID = id
        emit(.aircraftSelected)
    }

    func setHeading(_ heading: Double, turn: Aircraft.TurnDirection = .auto) {
        mutateSelected { ac in
            ac.targetHeading = heading.normalizedHeading
            ac.turnDirection = turn
            ac.lastInstruction = "FLY HDG \(String(format: "%03.0f", heading.normalizedHeading))"
        }
    }

    func setAltitude(_ feet: Double) {
        mutateSelected { ac in
            ac.targetAltitude = max(0, feet)
            ac.lastInstruction = (feet > ac.altitude ? "CLIMB " : "DESCEND ") + "\(Int(feet))"
        }
    }

    func setSpeed(_ knots: Double) {
        mutateSelected { ac in
            let clamped = min(max(knots, ac.kind.minSpeed), ac.kind.maxSpeed)
            ac.targetSpeed = clamped
            ac.lastInstruction = "SPEED \(Int(clamped))"
        }
    }

    func directTo(fixNamed name: String) {
        guard let fix = airport.fixes.first(where: { $0.name == name }) else { return }
        mutateSelected { ac in
            ac.targetHeading = Nav.bearing(from: ac.position, to: fix.position)
            ac.turnDirection = .auto
            ac.handoffFix = name
            ac.lastInstruction = "DIRECT \(name)"
        }
    }

    func clearSelectedToLand() {
        guard let idx = selectedIndex, aircraft[idx].isArrival else { return }
        aircraft[idx].clearedToLand = true
        aircraft[idx].lastInstruction = "CLEARED TO LAND \(activeRunway.name)"
        emit(.clearedToLand)
    }

    func goAround() {
        mutateSelected { ac in
            guard ac.isArrival else { return }
            ac.clearedToLand = false
            ac.phase = .enroute
            ac.targetAltitude = 4000
            ac.targetSpeed = ac.kind.maxSpeed * 0.7
            ac.lastInstruction = "GO AROUND"
        }
    }

    // MARK: Voice commands

    /// The resolvable callsigns currently on the scope, for the speech parser.
    var callsignCandidates: [CallsignCandidate] {
        aircraft.map { CallsignCandidate(callsign: $0.callsign, spoken: $0.spoken) }
    }

    /// Applies a parsed voice transmission to the aircraft it addresses. Selects
    /// that aircraft so the HUD follows along. Returns true if a target was
    /// resolved and at least one command took effect.
    @discardableResult
    func apply(_ transmission: ParsedTransmission) -> Bool {
        guard let callsign = transmission.targetCallsign,
              let idx = aircraft.firstIndex(where: { $0.callsign == callsign }) else { return false }
        selectedID = aircraft[idx].id

        var applied = false
        for command in transmission.commands {
            switch command {
            case let .turn(kind, heading):
                aircraft[idx].targetHeading = Double(heading).normalizedHeading
                aircraft[idx].turnDirection = kind == .left ? .left : (kind == .right ? .right : .auto)
                applied = true
            case let .climb(a), let .descend(a), let .maintainAltitude(a):
                aircraft[idx].targetAltitude = max(0, Double(a))
                applied = true
            case let .speed(_, knots):
                let clamped = min(max(Double(knots), aircraft[idx].kind.minSpeed), aircraft[idx].kind.maxSpeed)
                aircraft[idx].targetSpeed = clamped
                applied = true
            case let .direct(fix):
                if let f = airport.fixes.first(where: { $0.name == fix }) {
                    aircraft[idx].targetHeading = Nav.bearing(from: aircraft[idx].position, to: f.position)
                    aircraft[idx].turnDirection = .auto
                    aircraft[idx].handoffFix = fix
                    applied = true
                }
            case .clearedToLand:
                if aircraft[idx].isArrival {
                    aircraft[idx].clearedToLand = true
                    applied = true
                    emit(.clearedToLand)
                }
            case .contactTower, .sayAgain:
                break
            }
        }

        if applied {
            aircraft[idx].lastInstruction = transmission.readback.uppercased()
            emit(.commandIssued)
        }
        return applied
    }

    // MARK: Academy / scripted scenarios

    /// Replaces all traffic with a scripted set for a training drill. Clears any
    /// active emergencies. Works in training mode where spawns are disabled.
    func loadScenario(_ scripted: [Aircraft], select: Bool = true) {
        aircraft = scripted
        emergencies.removeAll()
        spawnAccumulator = 0
        emergencyAccumulator = 0
        selectedID = select ? scripted.first?.id : nil
    }

    /// Manually attaches an emergency to a specific aircraft (used by the
    /// academy's priority-handling lesson, where automatic emergencies are off).
    func triggerEmergency(on id: UUID, type: EmergencyType, in seconds: TimeInterval = 100) {
        guard let idx = aircraft.firstIndex(where: { $0.id == id }), aircraft[idx].emergency == nil else { return }
        aircraft[idx].emergency = type
        emergencies.append(Emergency(
            aircraftID: id,
            callsign: aircraft[idx].callsign,
            type: type,
            deadline: .now.addingTimeInterval(seconds)
        ))
        emit(.emergencyBegan(type, callsign: aircraft[idx].callsign))
    }

    /// Test seam: adds an aircraft and selects it without starting the loop,
    /// so the deterministic command logic can be exercised in isolation.
    func injectForTesting(_ aircraft: Aircraft) {
        self.aircraft.append(aircraft)
        selectedID = aircraft.id
    }

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return aircraft.firstIndex { $0.id == selectedID }
    }

    private func mutateSelected(_ body: (inout Aircraft) -> Void) {
        guard let idx = selectedIndex else { return }
        body(&aircraft[idx])
        emit(.commandIssued)
    }

    // MARK: Tick

    private func tick(dt: Double) {
        elapsed += dt

        for i in aircraft.indices {
            stepHeading(&aircraft[i], dt: dt)
            stepAltitude(&aircraft[i], dt: dt)
            stepSpeed(&aircraft[i], dt: dt)
            move(&aircraft[i], dt: dt)
            if aircraft[i].isArrival {
                updateApproach(&aircraft[i])
            } else {
                updateDeparture(&aircraft[i])
            }
        }

        detectConflicts()
        if !isTraining {
            handleSpawns(dt: dt)
            handleEmergencies(dt: dt)
        }
        resolveCompletions()
        checkMilestones()
    }

    // MARK: Kinematics

    private func stepHeading(_ ac: inout Aircraft, dt: Double) {
        guard let target = ac.targetHeading else { return }
        let delta = Nav.signedDelta(from: ac.heading, to: target)
        let maxStep = ac.kind.turnRate * dt
        let step: Double
        switch ac.turnDirection {
        case .auto:
            step = max(-maxStep, min(maxStep, delta))
        case .left:
            var left = delta
            if left > 0 { left -= 360 }
            step = max(left, -maxStep)
        case .right:
            var right = delta
            if right < 0 { right += 360 }
            step = min(right, maxStep)
        }
        ac.heading = (ac.heading + step).normalizedHeading
        if abs(Nav.signedDelta(from: ac.heading, to: target)) <= maxStep {
            ac.heading = target
            ac.targetHeading = nil
            ac.turnDirection = .auto
        }
    }

    private func stepAltitude(_ ac: inout Aircraft, dt: Double) {
        guard let target = ac.targetAltitude else { return }
        let maxStep = ac.kind.climbRate * dt
        let diff = target - ac.altitude
        if abs(diff) <= maxStep { ac.altitude = target; ac.targetAltitude = nil }
        else { ac.altitude += maxStep * (diff > 0 ? 1 : -1) }
    }

    private func stepSpeed(_ ac: inout Aircraft, dt: Double) {
        guard let target = ac.targetSpeed else { return }
        let maxStep = 9.0 * dt
        let diff = target - ac.speed
        if abs(diff) <= maxStep { ac.speed = target; ac.targetSpeed = nil }
        else { ac.speed += maxStep * (diff > 0 ? 1 : -1) }
    }

    private func move(_ ac: inout Aircraft, dt: Double) {
        let v = Nav.vector(forHeading: ac.heading)
        let nmPerSec = ac.speed / 3600
        // Wind drift (light): pushes the aircraft downwind.
        let windV = Nav.vector(forHeading: (weather.windDirection + 180).normalizedHeading)
        let windNM = Double(weather.windSpeed) / 3600 * 0.35
        ac.position.x += CGFloat(Double(v.x) * nmPerSec * dt + Double(windV.x) * windNM * dt)
        ac.position.y += CGFloat(Double(v.y) * nmPerSec * dt + Double(windV.y) * windNM * dt)

        if ac.trail.last.map({ Nav.distance($0, ac.position) > 0.5 }) ?? true {
            ac.trail.append(ac.position)
            if ac.trail.count > 16 { ac.trail.removeFirst(ac.trail.count - 16) }
        }
    }

    // MARK: Approach & landing

    /// Along-track (negative = before threshold) and lateral offset from the
    /// extended runway centerline, in NM.
    private func runwayFrame(_ ac: Aircraft) -> (along: Double, lateral: Double) {
        let dir = Nav.vector(forHeading: activeRunway.heading)
        let perp = CGPoint(x: dir.y, y: -dir.x)
        let w = CGPoint(x: ac.position.x - activeRunway.threshold.x,
                        y: ac.position.y - activeRunway.threshold.y)
        let along = Double(w.x * dir.x + w.y * dir.y)
        let lateral = Double(w.x * perp.x + w.y * perp.y)
        return (along, lateral)
    }

    private func updateApproach(_ ac: inout Aircraft) {
        guard ac.phase != .completed, ac.phase != .crashed else { return }
        let frame = runwayFrame(ac)
        let aligned = abs(Nav.signedDelta(from: ac.heading, to: activeRunway.heading)) <= 35
        let onApproachSide = frame.along < 0
        let nearCenterline = abs(frame.lateral) <= 1.3
        let lowEnough = ac.altitude <= 4200

        if ac.clearedToLand, onApproachSide, nearCenterline, aligned, lowEnough,
           frame.along > -13 {
            ac.phase = .landing
        }

        if ac.phase == .landing {
            // Track the centerline: steer slightly into it.
            let correction = max(-12, min(12, -frame.lateral * 10))
            ac.targetHeading = (activeRunway.heading + correction).normalizedHeading
            ac.turnDirection = .auto
            // 3-degree glide: 300 ft per NM from threshold.
            let glide = max(0, -frame.along) * 300
            ac.targetAltitude = min(glide, ac.altitude)
            ac.targetSpeed = ac.kind.minSpeed

            // Touchdown when crossing the threshold low and slow.
            if frame.along >= -0.4 {
                if ac.altitude <= 400 && ac.speed <= ac.kind.minSpeed + 25 {
                    ac.phase = .completed
                } else {
                    // Unstable — automatic go-around (no penalty, just lost time).
                    ac.clearedToLand = false
                    ac.phase = .enroute
                    ac.targetAltitude = 4000
                    ac.targetSpeed = ac.kind.maxSpeed * 0.7
                    ac.lastInstruction = "GO AROUND"
                }
            }
        }
    }

    // MARK: Departures

    private func updateDeparture(_ ac: inout Aircraft) {
        guard ac.phase != .completed, ac.phase != .crashed else { return }
        guard case let .departure(fixName) = ac.intent else { return }
        guard let fix = airport.fixes.first(where: { $0.name == fixName }) else { return }
        let towardFix = abs(Nav.signedDelta(from: ac.heading, to: Nav.bearing(from: ac.position, to: fix.position))) <= 30
        if ac.rangeNM >= sectorRadius - 2, ac.altitude >= 4000, towardFix || ac.handoffFix == fixName {
            ac.phase = .completed
        }
    }

    // MARK: Conflicts

    private func detectConflicts() {
        for i in aircraft.indices { aircraft[i].conflict = false }
        let live = aircraft.indices.filter {
            aircraft[$0].phase != .completed && aircraft[$0].phase != .crashed && aircraft[$0].altitude > 500
        }
        for a in 0..<live.count {
            for b in (a + 1)..<live.count {
                let i = live[a], j = live[b]
                let horizontal = Nav.distance(aircraft[i].position, aircraft[j].position)
                let vertical = abs(aircraft[i].altitude - aircraft[j].altitude)
                if horizontal < conflictRange && vertical < conflictVertical {
                    if !aircraft[i].conflict && !aircraft[j].conflict { emit(.conflictBegan) }
                    aircraft[i].conflict = true
                    aircraft[j].conflict = true
                    if horizontal < collisionRange && vertical < collisionVertical && !isTraining {
                        aircraft[i].phase = .crashed
                        aircraft[j].phase = .crashed
                        registerStrike(midair: true)
                    }
                }
            }
        }
    }

    // MARK: Completion & failure resolution

    private func resolveCompletions() {
        var survivors: [Aircraft] = []
        survivors.reserveCapacity(aircraft.count)
        for ac in aircraft {
            switch ac.phase {
            case .completed:
                award(for: ac)
            case .crashed:
                continue // already counted by registerStrike
            default:
                if ac.rangeNM > sectorRadius {
                    // Left controlled airspace without being handled.
                    if !isTraining { registerStrike(midair: false) }
                    if selectedID == ac.id { selectedID = nil }
                } else {
                    survivors.append(ac)
                }
            }
        }
        aircraft = survivors
        if selectedID != nil, !aircraft.contains(where: { $0.id == selectedID }) {
            selectedID = aircraft.first?.id
        }
    }

    private func award(for ac: Aircraft) {
        streak += 1
        bestStreak = max(bestStreak, streak)
        let base = ac.isArrival ? 100 : 80
        let comboBonus = 1.0 + Double(streak - 1) * 0.1
        var points = Int(Double(base) * difficulty.scoreMultiplier * comboBonus)

        if let emergency = ac.emergency {
            emergenciesHandled += 1
            points += 150 * emergency.severity
            resolveEmergency(for: ac.id, type: emergency)
        }
        score += points

        if ac.isArrival {
            landings += 1
            emit(.landed(points: points, callsign: ac.callsign))
        } else {
            departures += 1
            emit(.departed(points: points, callsign: ac.callsign))
        }
        if selectedID == ac.id { selectedID = nil }
    }

    private func registerStrike(midair: Bool) {
        streak = 0
        lives -= 1
        emit(.strike(remaining: max(lives, 0)))
        if lives <= 0 {
            finish(reason: midair ? .midair : .outOfLives)
        }
    }

    private func checkMilestones() {
        if score >= nextMilestone {
            emit(.scoreMilestone(nextMilestone))
            nextMilestone += 500
        }
    }

    // MARK: Spawning

    private func handleSpawns(dt: Double) {
        spawnAccumulator += dt
        let ramp = min(1, elapsed / 180)
        let interval = difficulty.initialSpawnInterval
            - (difficulty.initialSpawnInterval - difficulty.minSpawnInterval) * ramp
        guard spawnAccumulator >= interval else { return }
        spawnAccumulator = 0
        guard aircraft.count < difficulty.trafficCeiling else { return }
        spawnOne()
    }

    private func spawnOne() {
        let wantDeparture = Double.random(in: 0...1) < 0.32
            && aircraft.filter { !$0.isArrival }.count < 3
        if wantDeparture, let exit = airport.departureFixes.randomElement() {
            aircraft.append(TrafficFactory.makeDeparture(runway: activeRunway, exitFix: exit, existing: callsigns))
        } else {
            let fix = leastBusyArrivalFix()
            aircraft.append(TrafficFactory.makeArrival(at: fix, existing: callsigns))
        }
    }

    /// Avoids stacking new arrivals on top of one already near a given fix.
    private func leastBusyArrivalFix() -> Fix {
        airport.arrivalFixes.max { a, b in
            minDistanceToTraffic(a.position) < minDistanceToTraffic(b.position)
        } ?? airport.arrivalFixes[0]
    }

    private func minDistanceToTraffic(_ point: CGPoint) -> Double {
        aircraft.map { Nav.distance($0.position, point) }.min() ?? .greatestFiniteMagnitude
    }

    // MARK: Emergencies

    private func handleEmergencies(dt: Double) {
        guard difficulty != .relaxed else { return }
        emergencyAccumulator += dt
        // Roughly one emergency attempt every ~45s once traffic is established.
        guard emergencyAccumulator >= 45, elapsed > 60 else { return }
        emergencyAccumulator = 0
        guard emergencies.filter({ !$0.resolved }).isEmpty else { return }
        let candidates = aircraft.indices.filter {
            aircraft[$0].isArrival && aircraft[$0].emergency == nil && aircraft[$0].phase == .enroute
        }
        guard let idx = candidates.randomElement() else { return }
        let type = EmergencyType.allCases.filter { $0 != .microburst }.randomElement() ?? .medical
        aircraft[idx].emergency = type
        let em = Emergency(
            aircraftID: aircraft[idx].id,
            callsign: aircraft[idx].callsign,
            type: type,
            deadline: .now.addingTimeInterval(Double(110 - type.severity * 10))
        )
        emergencies.append(em)
        emit(.emergencyBegan(type, callsign: aircraft[idx].callsign))
    }

    private func resolveEmergency(for aircraftID: UUID, type: EmergencyType) {
        if let i = emergencies.firstIndex(where: { $0.aircraftID == aircraftID && !$0.resolved }) {
            emergencies[i].resolved = true
            emit(.emergencyResolved(type))
        }
    }

    // MARK: Finishing

    private func finish(reason: GameOverReason) {
        guard isRunning else { return }
        isRunning = false
        simTask?.cancel()
        simTask = nil
        let result = RunResult(
            score: score,
            landings: landings,
            departures: departures,
            emergenciesHandled: emergenciesHandled,
            bestStreak: bestStreak,
            durationSeconds: Int(elapsed),
            difficulty: difficulty,
            date: .now
        )
        emit(.gameOver(result, reason))
    }

    private func emit(_ event: GameEvent) { onEvent?(event) }
}
