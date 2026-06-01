import Foundation
import Observation

/// Dependency container shared through the SwiftUI environment. Created once by
/// the app and injected so every screen can reach settings, the save store,
/// Game Center and the feedback services without singletons.
@MainActor
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let player: PlayerStore
    let gameCenter: GameCenterManager
    let haptics = Haptics()
    let sound = SoundManager()
    let voice = VoiceCommandManager()

    init(settings: AppSettings = AppSettings(),
         player: PlayerStore = PlayerStore(),
         gameCenter: GameCenterManager = GameCenterManager()) {
        self.settings = settings
        self.player = player
        self.gameCenter = gameCenter
    }

    /// One-time startup: warm feedback engines and sign into Game Center.
    func bootstrap() {
        haptics.prepare()
        sound.prepare()
        syncFeedbackToggles()
        gameCenter.authenticate()
    }

    func syncFeedbackToggles() {
        haptics.enabled = settings.hapticsEnabled
        sound.enabled = settings.soundEnabled
    }

    /// Translates a gameplay event into haptic + audio feedback. Called by the
    /// game coordinator for each event drained from the engine.
    func feedback(for event: GameEvent) {
        syncFeedbackToggles()
        switch event {
        case .aircraftSelected:
            haptics.tap(); sound.play(.select)
        case .commandIssued:
            haptics.light(); sound.play(.command)
        case .clearedToLand:
            haptics.medium(); sound.play(.command)
        case .landed, .departed:
            haptics.success(); sound.play(.success)
        case .conflictBegan, .emergencyBegan:
            haptics.warning(); sound.play(.conflict)
        case .emergencyResolved:
            haptics.success(); sound.play(.success)
        case .strike:
            haptics.error(); sound.play(.strike)
        case .scoreMilestone:
            haptics.light(); sound.play(.milestone)
        case .gameOver:
            haptics.error(); sound.play(.gameOver)
        }
    }
}
