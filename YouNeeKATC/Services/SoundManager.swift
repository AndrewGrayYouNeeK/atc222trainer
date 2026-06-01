import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Procedurally synthesizes the game's short UI tones at runtime, so the app
/// ships with zero bundled audio files. Each cue is a tiny sine-burst (with a
/// quick fade to avoid clicks) rendered into a PCM buffer once and replayed via
/// a shared `AVAudioEngine`.
///
/// Everything is wrapped defensively: if audio setup fails (e.g. on a platform
/// without an output device), the manager silently becomes a no-op.
@MainActor
final class SoundManager {
    var enabled = true

    #if canImport(AVFoundation)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var started = false
    #endif

    enum Cue { case select, command, success, milestone, conflict, strike, gameOver }

    func prepare() {
        #if canImport(AVFoundation)
        guard !started, let format else { return }
        configureSession()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffers[.select]    = tone([(880, 0.06)], volume: 0.25)
        buffers[.command]   = tone([(660, 0.05), (990, 0.05)], volume: 0.22)
        buffers[.success]   = tone([(660, 0.09), (880, 0.12)], volume: 0.3)
        buffers[.milestone] = tone([(784, 0.08), (988, 0.08), (1175, 0.14)], volume: 0.32)
        buffers[.conflict]  = tone([(440, 0.12), (0, 0.05), (440, 0.12)], volume: 0.3)
        buffers[.strike]    = tone([(196, 0.18), (147, 0.22)], volume: 0.35)
        buffers[.gameOver]  = tone([(392, 0.16), (294, 0.16), (196, 0.3)], volume: 0.35)
        do {
            try engine.start()
            player.play()
            started = true
        } catch {
            started = false
        }
        #endif
    }

    func play(_ cue: Cue) {
        guard enabled else { return }
        #if canImport(AVFoundation)
        guard started, let buffer = buffers[cue] else { return }
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        #endif
    }

    #if canImport(AVFoundation)
    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // Ambient + mixWithOthers means our blips never stop the player's music.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    /// Renders a sequence of (frequency, duration) segments into one buffer.
    /// A frequency of 0 produces a short silence (used for stutter alerts).
    private func tone(_ segments: [(freq: Double, dur: Double)], volume: Float) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let sampleRate = format.sampleRate
        let totalFrames = segments.reduce(0) { $0 + Int($1.dur * sampleRate) }
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        var frame = 0
        for segment in segments {
            let frames = Int(segment.dur * sampleRate)
            for n in 0..<frames {
                let t = Double(n) / sampleRate
                // 8 ms fade in/out envelope to kill clicks.
                let fade = min(1.0, Double(n) / (0.008 * sampleRate))
                let fadeOut = min(1.0, Double(frames - n) / (0.008 * sampleRate))
                let env = Float(min(fade, fadeOut))
                let sample = segment.freq == 0 ? 0 : Float(sin(2 * .pi * segment.freq * t))
                channel[frame] = sample * env * volume
                frame += 1
            }
        }
        return buffer
    }
    #endif
}
