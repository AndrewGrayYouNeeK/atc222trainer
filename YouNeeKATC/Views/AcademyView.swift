import SwiftUI

/// The controller academy: a structured training pipeline that teaches real ATC
/// concepts and phraseology, then graduates the player into live play via a
/// certification check ride.
///
/// Each lesson opens with a classroom briefing (the WHY + standard phraseology),
/// then drops the student onto the real scope to demonstrate the skill using the
/// same tap/voice controls as the live game. Completing the check ride certifies
/// the player and leads straight into a live shift.
struct AcademyView: View {
    /// Called when the player certifies; hands back the difficulty to launch live.
    let onGraduate: (Difficulty) -> Void
    let onExit: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = GameEngine(difficulty: .relaxed, training: true)
    @State private var lessonIndex = 0
    @State private var showingBriefing = true
    @State private var lessonComplete = false
    @State private var graduated = false
    @State private var checkRideFailed = false

    // Per-lesson baselines so goals measure progress made during the lesson.
    @State private var baseLandings = 0
    @State private var baseDepartures = 0
    @State private var baseEmergencies = 0
    @State private var baseHandled = 0
    @State private var commandsIssued = 0

    private let curriculum = AcademyLesson.curriculum
    private let checkRideDifficulty: Difficulty = .relaxed

    private var lesson: AcademyLesson { curriculum[min(lessonIndex, curriculum.count - 1)] }
    private var isCheckRide: Bool { lesson.kind == .checkRide }

    var body: some View {
        ZStack {
            ATC.background.ignoresSafeArea()

            RadarScopeView(
                engine: engine,
                palette: env.settings.colorBlindMode ? .colorBlind : .standard,
                showDataBlocks: env.settings.showDataBlocks,
                reduceMotion: reduceMotion
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                if !showingBriefing {
                    VStack(spacing: 10) {
                        if lessonComplete {
                            completeBar
                        } else {
                            objectiveBar
                        }
                        if env.settings.voiceControlEnabled {
                            VoiceBarView(voice: env.voice, handsFree: env.settings.handsFreeVoice)
                        }
                        ControlPanelView(engine: engine)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }

            if showingBriefing { briefingOverlay }
            if graduated { certifiedOverlay }
            if checkRideFailed { failedOverlay }
        }
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.25), value: showingBriefing)
        .animation(.easeInOut(duration: 0.25), value: lessonComplete)
        .animation(.easeInOut(duration: 0.3), value: graduated)
        .animation(.easeInOut(duration: 0.3), value: checkRideFailed)
        .onChange(of: progressSignature) { _, _ in evaluate() }
        .onAppear {
            configureVoice()
            wire(engine)
            engine.start()
            startLesson(0)
        }
        .onDisappear {
            engine.teardown()
            env.voice.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { env.voice.cancel() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ACADEMY · MODULE \(lesson.moduleNumber)")
                    .font(ATC.mono(10, weight: .bold))
                    .foregroundStyle(ATC.success)
                Text(lesson.moduleTitle)
                    .font(ATC.mono(13, weight: .bold))
                    .foregroundStyle(ATC.phosphor)
            }
            Spacer()
            if isCheckRide && !showingBriefing {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HANDLED \(max(0, engine.handled - baseHandled))/6")
                        .font(ATC.mono(13, weight: .bold))
                        .foregroundStyle(ATC.selected)
                        .contentTransition(.numericText())
                    Text("LIVES \(engine.lives)")
                        .font(ATC.mono(10, weight: .semibold))
                        .foregroundStyle(engine.lives > 1 ? ATC.hudDim : ATC.conflict)
                }
            } else {
                Text("LESSON \(lessonIndex + 1)/\(curriculum.count)")
                    .font(ATC.mono(11, weight: .bold))
                    .foregroundStyle(ATC.hudDim)
            }
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ATC.hud)
                    .frame(width: 34, height: 34)
                    .panel(corner: 9)
            }
            .accessibilityLabel("Exit academy")
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    // MARK: Objective / completion bars

    private var objectiveBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "target").foregroundStyle(ATC.selected)
            Text(lesson.objective)
                .font(ATC.mono(12, weight: .semibold))
                .foregroundStyle(ATC.hud)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                showingBriefing = true
                if !isCheckRide { engine.pause() }
            } label: {
                Image(systemName: "info.circle").foregroundStyle(ATC.hudDim)
            }
            .accessibilityLabel("Show briefing")
        }
        .padding(12)
        .panel(corner: 12, stroke: ATC.selected.opacity(0.4))
    }

    private var completeBar: some View {
        Button(action: advance) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(ATC.success)
                Text(isCheckRide ? "Certified!" : "Objective complete — Continue")
                    .font(ATC.mono(14, weight: .bold))
                    .foregroundStyle(ATC.hud)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill").foregroundStyle(ATC.success)
            }
            .padding(14)
            .panel(corner: 12, stroke: ATC.success.opacity(0.6))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Briefing overlay

    private var briefingOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MODULE \(lesson.moduleNumber) · \(text(lesson.moduleTitle))")
                            .font(ATC.mono(10, weight: .bold))
                            .foregroundStyle(ATC.success)
                        Text(lesson.title)
                            .font(ATC.mono(22, weight: .bold))
                            .foregroundStyle(ATC.phosphor)
                    }

                    Text(lesson.concept)
                        .font(ATC.mono(13))
                        .foregroundStyle(ATC.hud)
                        .fixedSize(horizontal: false, vertical: true)

                    if !lesson.phraseology.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("STANDARD PHRASEOLOGY", systemImage: "quote.bubble.fill")
                                .font(ATC.mono(10, weight: .bold))
                                .foregroundStyle(ATC.selected)
                            ForEach(Array(lesson.phraseology.enumerated()), id: \.offset) { item in
                                Text(item.element)
                                    .font(ATC.mono(12, weight: .medium))
                                    .foregroundStyle(ATC.hud)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panel(corner: 12, stroke: ATC.selected.opacity(0.35))
                    }

                    if let note = lesson.realismNote {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill").foregroundStyle(ATC.hudDim)
                            Text(note)
                                .font(ATC.mono(11))
                                .foregroundStyle(ATC.hudDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target").foregroundStyle(ATC.selected)
                        Text(lesson.objective)
                            .font(ATC.mono(13, weight: .bold))
                            .foregroundStyle(ATC.selected)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PrimaryButton(title: isCheckRide ? "Begin Check Ride" : "Begin Drill",
                                  systemImage: "play.fill",
                                  action: beginDrill)
                        .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Certified / failed overlays

    private var certifiedOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(ATC.success)
                    .phosphorGlow(ATC.success, radius: 18)
                Text("CERTIFIED")
                    .font(ATC.mono(30, weight: .bold))
                    .foregroundStyle(ATC.phosphor)
                    .tracking(4)
                    .phosphorGlow()
                Text("You’re cleared to control live traffic.\nKeep them moving, keep them safe.")
                    .font(ATC.mono(14))
                    .foregroundStyle(ATC.hud)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Enter Live Traffic", systemImage: "dot.radiowaves.left.and.right") {
                    onGraduate(env.settings.preferredDifficulty)
                }
                SecondaryButton(title: "Back to Menu", systemImage: "house.fill", action: onExit)
            }
            .padding(28)
            .frame(maxWidth: 400)
        }
    }

    private var failedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(ATC.caution)
                Text("Check Ride Incomplete")
                    .font(ATC.mono(20, weight: .bold))
                    .foregroundStyle(ATC.hud)
                Text("You lost the picture before handling six. Reset and try again — you’ve got this.")
                    .font(ATC.mono(13))
                    .foregroundStyle(ATC.hudDim)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Retry Check Ride", systemImage: "arrow.clockwise") {
                    checkRideFailed = false
                    startLesson(lessonIndex)
                }
                SecondaryButton(title: "Back to Menu", systemImage: "house.fill", action: onExit)
            }
            .padding(28)
            .frame(maxWidth: 400)
        }
    }

    // MARK: Lesson lifecycle

    private func startLesson(_ index: Int) {
        lessonIndex = index
        lessonComplete = false
        checkRideFailed = false
        commandsIssued = 0

        let lesson = curriculum[index]
        if lesson.kind == .drill {
            ensureTrainingEngine()
            let autoselect: Bool = {
                if case .select = lesson.goal { return false }
                return true
            }()
            engine.loadScenario(scenarioAircraft(for: lesson.scenario), select: autoselect)
            engine.pause()              // frozen while the briefing is up
        }
        // Check-ride engine is created in beginDrill so live traffic only starts
        // once the student is ready.
        showingBriefing = true
    }

    private func beginDrill() {
        showingBriefing = false
        if isCheckRide {
            engine.teardown()
            let live = GameEngine(difficulty: checkRideDifficulty)
            wire(live)
            engine = live
            env.voice.candidatesProvider = { [weak live] in live?.callsignCandidates ?? [] }
            live.start()
        } else {
            engine.resume()
            // The emergency is armed now, so its countdown doesn't tick during reading.
            if lesson.scenario == .emergency, let id = engine.aircraft.first?.id {
                engine.triggerEmergency(on: id, type: .lowFuel, in: 180)
            }
        }
        captureBaseline()
        startHandsFreeIfNeeded()
    }

    private func advance() {
        if lessonIndex >= curriculum.count - 1 {
            onExit()    // (only reached for non-checkride final; checkride graduates)
        } else {
            startLesson(lessonIndex + 1)
        }
    }

    private func ensureTrainingEngine() {
        if !engine.isTraining || !engine.isRunning {
            engine.teardown()
            let trainer = GameEngine(difficulty: .relaxed, training: true)
            wire(trainer)
            engine = trainer
            env.voice.candidatesProvider = { [weak trainer] in trainer?.callsignCandidates ?? [] }
            trainer.start()
        }
    }

    private func captureBaseline() {
        baseLandings = engine.landings
        baseDepartures = engine.departures
        baseEmergencies = engine.emergenciesHandled
        baseHandled = engine.handled
    }

    // MARK: Evaluation

    private var progressSignature: String {
        let s = engine.selected
        let conflicts = engine.aircraft.filter(\.conflict).count
        return [
            engine.selectedID != nil ? "1" : "0",
            String(engine.landings), String(engine.departures),
            String(engine.emergenciesHandled), String(engine.handled),
            String(conflicts), String(commandsIssued),
            s.map { String(Int($0.targetHeading ?? $0.heading)) } ?? "-",
            s.map { String(Int($0.targetAltitude ?? $0.altitude)) } ?? "-",
            s.map { String(Int($0.targetSpeed ?? $0.speed)) } ?? "-"
        ].joined(separator: "|")
    }

    private func evaluate() {
        guard !showingBriefing, !lessonComplete, !graduated, !checkRideFailed else { return }
        guard goalMet(lesson.goal) else { return }
        if isCheckRide {
            graduate()
        } else {
            lessonComplete = true
            engine.pause()
            env.haptics.success()
            env.sound.play(.success)
        }
    }

    private func graduate() {
        graduated = true
        engine.teardown()
        env.voice.cancel()
        env.settings.isCertified = true
        env.settings.hasCompletedTutorial = true
        env.haptics.success()
        env.sound.play(.milestone)
    }

    private func goalMet(_ goal: AcademyLesson.Goal) -> Bool {
        switch goal {
        case .select:
            return engine.selectedID != nil
        case let .vector(heading, alt):
            guard let a = engine.aircraft.first else { return false }
            let hdg = a.targetHeading ?? a.heading
            let okHeading = abs(Nav.signedDelta(from: hdg, to: heading)) <= 20
            let okAlt = alt.map { (a.targetAltitude ?? a.altitude) <= $0 + 1 } ?? true
            return okHeading && okAlt
        case .separate:
            let live = engine.aircraft.filter { $0.phase != .completed && $0.phase != .crashed }
            guard live.count >= 2, commandsIssued > 0 else { return false }
            for i in 0..<live.count {
                for j in (i + 1)..<live.count {
                    let horizontal = Nav.distance(live[i].position, live[j].position)
                    let vertical = abs(live[i].altitude - live[j].altitude)
                    if horizontal < 3 && vertical < 1000 { return false }
                }
            }
            return true
        case let .land(n):
            return engine.landings - baseLandings >= n
        case let .spacing(maxTrailingSpeed):
            let arrivals = engine.aircraft.filter(\.isArrival)
            guard commandsIssued > 0,
                  let trailer = arrivals.max(by: { $0.rangeNM < $1.rangeNM }) else { return false }
            return (trailer.targetSpeed ?? trailer.speed) <= maxTrailingSpeed + 1
        case let .handoff(n):
            return engine.departures - baseDepartures >= n
        case .handleEmergency:
            return engine.emergenciesHandled - baseEmergencies >= 1
        case let .certify(handled):
            return engine.handled - baseHandled >= handled
        }
    }

    // MARK: Engine + voice wiring

    private func wire(_ e: GameEngine) {
        e.onEvent = { event in handleEvent(event) }
    }

    private func handleEvent(_ event: GameEvent) {
        env.feedback(for: event)
        switch event {
        case .commandIssued, .clearedToLand:
            commandsIssued += 1
        case .gameOver:
            if isCheckRide {
                env.voice.cancel()
                checkRideFailed = true
            }
        default:
            break
        }
    }

    private func configureVoice() {
        guard env.settings.voiceControlEnabled else { return }
        env.voice.candidatesProvider = { [weak engine] in engine?.callsignCandidates ?? [] }
        env.voice.onTransmission = { transmission in handleTransmission(transmission) }
        Task {
            await env.voice.requestAuthorization()
            startHandsFreeIfNeeded()
        }
    }

    private func startHandsFreeIfNeeded() {
        guard env.settings.voiceControlEnabled, env.settings.handsFreeVoice,
              env.voice.authState == .authorized, engine.isRunning,
              !showingBriefing, !lessonComplete, !graduated
        else { return }
        env.voice.startListening(continuous: true)
    }

    private func handleTransmission(_ transmission: ParsedTransmission) {
        guard engine.isRunning, !showingBriefing, !graduated else { return }
        if engine.apply(transmission) {
            if env.settings.spokenReadback {
                let spoken = transmission.spokenCallsign ?? transmission.targetCallsign ?? ""
                env.voice.speak(ATCPhraseology.readbackSpeech(callsign: spoken, commands: transmission.commands))
            }
        } else {
            env.haptics.warning()
        }
    }

    private func text(_ resource: LocalizedStringResource) -> String { String(localized: resource) }

    // MARK: Scripted scenarios

    private func scenarioAircraft(for scenario: AcademyLesson.Scenario) -> [Aircraft] {
        switch scenario {
        case .orientation:
            return [arrival("DAL482", "Delta 482", .jet, at: CGPoint(x: -18, y: 16), heading: 225, alt: 7000, spd: 220)]

        case .vectorBasics:
            return [arrival("UAL319", "United 319", .jet, at: CGPoint(x: 24, y: 14), heading: 240, alt: 11000, spd: 300)]

        case .separation:
            return [
                arrival("DAL482", "Delta 482", .jet, at: CGPoint(x: -1.5, y: 6), heading: 360, alt: 6000, spd: 220),
                arrival("UAL319", "United 319", .jet, at: CGPoint(x: 1.0, y: 6), heading: 360, alt: 6000, spd: 220)
            ]

        case .finalApproach:
            return [arrival("DAL482", "Delta 482", .jet, at: CGPoint(x: 4, y: -13), heading: 20, alt: 5000, spd: 220)]

        case .sequencing:
            return [
                arrival("DAL482", "Delta 482", .jet, at: CGPoint(x: 4, y: -10), heading: 340, alt: 2500, spd: 180),
                arrival("AAL502", "American 502", .jet, at: CGPoint(x: 4.7, y: -22), heading: 340, alt: 4000, spd: 260)
            ]

        case .departure:
            var dep = Aircraft(callsign: "JBU412", spoken: "JetBlue 412", kind: .jet,
                               intent: .departure(fix: "NORTH"),
                               position: engine.activeRunway.threshold, heading: engine.activeRunway.heading,
                               altitude: 1000, speed: 165)
            dep.targetAltitude = 5000
            dep.targetSpeed = AircraftKind.jet.minSpeed + 40
            return [dep]

        case .emergency:
            return [arrival("DAL482", "Delta 482", .jet, at: CGPoint(x: 16, y: 16), heading: 225, alt: 7000, spd: 250)]

        case .checkRide:
            return []
        }
    }

    private func arrival(_ callsign: String, _ spoken: String, _ kind: AircraftKind,
                         at position: CGPoint, heading: Double, alt: Double, spd: Double) -> Aircraft {
        Aircraft(callsign: callsign, spoken: spoken, kind: kind, intent: .arrival,
                 position: position, heading: heading, altitude: alt, speed: spd)
    }
}
