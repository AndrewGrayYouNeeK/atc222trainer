import Foundation

/// One-shot signals the engine emits so the presentation layer can react with
/// haptics, sound and Game Center reporting without the engine depending on any
/// of them. Drained by the game coordinator each frame.
enum GameEvent: Equatable, Sendable {
    case aircraftSelected
    case commandIssued
    case clearedToLand
    case landed(points: Int, callsign: String)
    case departed(points: Int, callsign: String)
    case conflictBegan
    case strike(remaining: Int)
    case emergencyBegan(EmergencyType, callsign: String)
    case emergencyResolved(EmergencyType)
    case scoreMilestone(Int)
    case gameOver(RunResult, GameOverReason)
}
