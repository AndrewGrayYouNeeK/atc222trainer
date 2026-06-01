import Foundation
import Observation
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Captures the controller's voice, transcribes it with on-device speech
/// recognition, hands the transcript to `ATCPhraseology`, and speaks the pilot
/// read-back. Supports both push-to-talk (`startListening`/`stopListening`) and
/// hands-free continuous listening.
///
/// Audio never leaves the device: recognition uses `requiresOnDeviceRecognition`
/// when the device supports it.
@MainActor
@Observable
final class VoiceCommandManager {

    enum AuthState: Equatable { case notDetermined, authorized, denied, unavailable }

    private(set) var authState: AuthState = .notDetermined
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var lastError: String?

    /// Supplies the callsigns the parser can resolve against (current traffic).
    var candidatesProvider: () -> [CallsignCandidate] = { [] }
    /// Delivered on the main actor when a transmission has been recognized.
    var onTransmission: ((ParsedTransmission) -> Void)?

    private var continuous = false

    #if canImport(Speech)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    #endif

    var isAvailable: Bool {
        #if canImport(Speech)
        return recognizer?.isAvailable ?? false
        #else
        return false
        #endif
    }

    // MARK: Authorization

    /// Requests speech + microphone permission. Safe to call repeatedly.
    func requestAuthorization() async {
        #if canImport(Speech)
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            authState = (speechStatus == .notDetermined) ? .notDetermined : .denied
            return
        }
        let micGranted = await requestMicrophone()
        authState = micGranted ? .authorized : .denied
        #else
        authState = .unavailable
        #endif
    }

    private func requestMicrophone() async -> Bool {
        #if canImport(AVFoundation) && os(iOS)
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
            }
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        #else
        return true
        #endif
    }

    // MARK: Listening

    /// Begins a single listening session (push-to-talk). For hands-free, pass
    /// `continuous: true` and the manager re-arms after each utterance.
    func startListening(continuous: Bool = false) {
        #if canImport(Speech)
        guard authState == .authorized, isAvailable, !isListening else { return }
        self.continuous = continuous
        configureSession(active: true)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The tap fires on a realtime audio thread; appending to the request is
        // thread-safe. `nonisolated(unsafe)` acknowledges that explicitly.
        nonisolated(unsafe) let sink = request
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            lastError = error.localizedDescription
            teardownAudio()
            return
        }

        transcript = ""
        isListening = true
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // Extract only Sendable values before hopping to the main actor.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text { self.transcript = text }
                if isFinal || failed { self.finalize(parse: !failed) }
            }
        }
        #endif
    }

    /// Ends the current session and parses whatever was heard (push-to-talk
    /// release).
    func stopListening() {
        continuous = false
        finalize(parse: true)
    }

    /// Stops everything without parsing (e.g. pause / disappear).
    func cancel() {
        continuous = false
        finalize(parse: false)
    }

    private func finalize(parse: Bool) {
        #if canImport(Speech)
        guard isListening || task != nil else { return }
        let heard = transcript
        teardownAudio()
        isListening = false

        if parse, !heard.isEmpty {
            let transmission = ATCPhraseology.parse(heard, candidates: candidatesProvider())
            onTransmission?(transmission)
        }
        configureSession(active: false)

        if continuous {
            // Re-arm shortly so natural pauses segment commands.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard let self, self.continuous, !self.isListening else { return }
                self.startListening(continuous: true)
            }
        }
        #endif
    }

    private func teardownAudio() {
        #if canImport(Speech)
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        #endif
    }

    // MARK: Read-back

    func speak(_ text: String) {
        #if canImport(AVFoundation)
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        #endif
    }

    // MARK: Session

    private func configureSession(active: Bool) {
        #if canImport(AVFoundation) && os(iOS)
        let session = AVAudioSession.sharedInstance()
        if active {
            try? session.setCategory(.playAndRecord, mode: .spokenAudio,
                                     options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try? session.setActive(true, options: .notifyOthersOnDeactivation)
        } else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }
}
