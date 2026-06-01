import Foundation
import Observation

/// User preferences, persisted to `UserDefaults` and observed app-wide. Each
/// property writes through on change so settings survive relaunches without an
/// explicit save call.
@MainActor
@Observable
final class AppSettings {

    var soundEnabled: Bool { didSet { store(soundEnabled, .soundEnabled) } }
    var hapticsEnabled: Bool { didSet { store(hapticsEnabled, .hapticsEnabled) } }
    var preferredDifficulty: Difficulty { didSet { store(preferredDifficulty.rawValue, .difficulty) } }
    var colorBlindMode: Bool { didSet { store(colorBlindMode, .colorBlind) } }
    var showDataBlocks: Bool { didSet { store(showDataBlocks, .dataBlocks) } }
    var hasOnboarded: Bool { didSet { store(hasOnboarded, .onboarded) } }
    var hasCompletedTutorial: Bool { didSet { store(hasCompletedTutorial, .tutorialDone) } }
    /// Set when the player passes the academy check ride. Unlocks the "certified"
    /// status shown around the app.
    var isCertified: Bool { didSet { store(isCertified, .certified) } }

    // Voice control
    var voiceControlEnabled: Bool { didSet { store(voiceControlEnabled, .voiceEnabled) } }
    var handsFreeVoice: Bool { didSet { store(handsFreeVoice, .handsFree) } }
    var spokenReadback: Bool { didSet { store(spokenReadback, .readback) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Register sensible first-launch defaults.
        defaults.register(defaults: [
            Key.soundEnabled.rawValue: true,
            Key.hapticsEnabled.rawValue: true,
            Key.dataBlocks.rawValue: true,
            Key.difficulty.rawValue: Difficulty.standard.rawValue,
            Key.voiceEnabled.rawValue: true,
            Key.readback.rawValue: true
        ])
        soundEnabled = defaults.bool(forKey: Key.soundEnabled.rawValue)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled.rawValue)
        colorBlindMode = defaults.bool(forKey: Key.colorBlind.rawValue)
        showDataBlocks = defaults.bool(forKey: Key.dataBlocks.rawValue)
        hasOnboarded = defaults.bool(forKey: Key.onboarded.rawValue)
        hasCompletedTutorial = defaults.bool(forKey: Key.tutorialDone.rawValue)
        isCertified = defaults.bool(forKey: Key.certified.rawValue)
        voiceControlEnabled = defaults.bool(forKey: Key.voiceEnabled.rawValue)
        handsFreeVoice = defaults.bool(forKey: Key.handsFree.rawValue)
        spokenReadback = defaults.bool(forKey: Key.readback.rawValue)
        preferredDifficulty = Difficulty(rawValue: defaults.string(forKey: Key.difficulty.rawValue) ?? "")
            ?? .standard
    }

    private enum Key: String {
        case soundEnabled, hapticsEnabled, difficulty, colorBlind
        case dataBlocks, onboarded, tutorialDone, certified
        case voiceEnabled, handsFree, readback
    }

    private func store(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
