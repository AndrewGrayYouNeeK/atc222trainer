import SwiftUI

/// Hosts a single run: the radar, HUD and command deck plus the pause and
/// game-over overlays. Owns the `GameEngine` and routes its events to feedback,
/// the save store and Game Center.
struct GameContainerView: View {
    let difficulty: Difficulty
    let onExit: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine: GameEngine
    @State private var showPause = false
    @State private var finished: (result: RunResult, reason: GameOverReason, newBest: Bool, promoted: ControllerRank?)?
    @State private var showLeaderboard = false

    init(difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onExit = onExit
        _engine = State(initialValue: GameEngine(difficulty: difficulty))
    }

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
                GameHUDView(engine: engine) { pause() }
                Spacer()
                VStack(spacing: 10) {
                    if env.settings.voiceControlEnabled {
                        VoiceBarView(voice: env.voice, handsFree: env.settings.handsFreeVoice)
                    }
                    ControlPanelView(engine: engine)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            if showPause {
                PauseOverlay(onResume: resume, onQuit: { engine.quit() })
            }

            if let finished {
                GameOverOverlay(
                    result: finished.result,
                    reason: finished.reason,
                    isNewBest: finished.newBest,
                    promotedTo: finished.promoted,
                    onRetry: retry,
                    onLeaderboard: { showLeaderboard = true },
                    onMenu: onExit
                )
            }
        }
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.25), value: showPause)
        .animation(.easeInOut(duration: 0.3), value: finished != nil)
        .sheet(isPresented: $showLeaderboard) {
            GameCenterDashboard(state: .leaderboard(GameCenterManager.Leaderboard.id(for: difficulty)))
        }
        .onAppear {
            engine.onEvent = { handle($0) }
            engine.start()
            setUpVoice()
        }
        .onDisappear {
            engine.teardown()
            env.voice.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, engine.isRunning, finished == nil { pause() }
        }
    }

    // MARK: Control

    private func pause() {
        engine.pause()
        env.voice.cancel()
        showPause = true
    }

    private func resume() {
        showPause = false
        engine.resume()
        startHandsFreeIfNeeded()
    }

    private func retry() {
        finished = nil
        showPause = false
        let fresh = GameEngine(difficulty: difficulty)
        fresh.onEvent = { handle($0) }
        engine = fresh
        engine.start()
        env.voice.candidatesProvider = { [weak engine] in engine?.callsignCandidates ?? [] }
        startHandsFreeIfNeeded()
    }

    // MARK: Voice

    private func setUpVoice() {
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
              env.voice.authState == .authorized, engine.isRunning, !showPause, finished == nil
        else { return }
        env.voice.startListening(continuous: true)
    }

    private func handleTransmission(_ transmission: ParsedTransmission) {
        guard engine.isRunning, !showPause, finished == nil else { return }
        if engine.apply(transmission) {
            if env.settings.spokenReadback {
                let spoken = transmission.spokenCallsign ?? transmission.targetCallsign ?? ""
                env.voice.speak(ATCPhraseology.readbackSpeech(callsign: spoken, commands: transmission.commands))
            }
        } else {
            // Heard speech but couldn't resolve a target/command.
            env.haptics.warning()
        }
    }

    // MARK: Event handling

    private func handle(_ event: GameEvent) {
        env.feedback(for: event)
        if case let .gameOver(result, reason) = event {
            showPause = false
            env.voice.cancel()
            // Rank is based on lifetime handled; compare before/after recording.
            let rankBefore = ControllerRank.rank(forHandled: env.player.profile.lifetimeHandled)
            let newBest = env.player.record(result)
            let rankAfter = ControllerRank.rank(forHandled: env.player.profile.lifetimeHandled)
            let promoted = rankAfter.level > rankBefore.level ? rankAfter : nil
            env.gameCenter.submit(result)
            env.gameCenter.evaluateAchievements(run: result, profile: env.player.profile)
            finished = (result, reason, newBest, promoted)
        }
    }
}
