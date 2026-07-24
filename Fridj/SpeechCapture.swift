//
//  SpeechCapture.swift
//  Fridj
//
//  Live, on-device speech-to-text for the pantry's voice input. Wraps Apple's
//  Speech framework + AVAudioEngine and exposes a running transcript the UI can
//  render as the user talks. The transcript is then fed to /api/parse-ingredients
//  — the same parser the typed field uses — so voice reuses the whole pipeline.
//
//  Deliberately Apple-only: no audio ever leaves the device (on-device
//  recognition when the locale supports it), no Whisper, no backend audio.
//

import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechCapture {
    enum Status: Equatable {
        case idle
        case listening
        case denied        // mic or speech permission refused
        case unavailable   // recognizer missing / engine failed to start
    }

    private(set) var status: Status = .idle
    private(set) var transcript = ""

    var isListening: Bool { status == .listening }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: Control

    func start() async {
        guard status != .listening else { return }
        transcript = ""

        guard await authorizeSpeech(), await authorizeMic() else {
            status = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            return
        }

        do {
            try beginSession(with: recognizer)
            status = .listening
        } catch {
            teardown()
            status = .unavailable
        }
    }

    /// Stops listening and leaves `transcript` holding the final text.
    func stop() {
        teardown()
        status = .idle
    }

    // MARK: Engine

    private func beginSession(with recognizer: SFSpeechRecognizer) throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep audio on the device when the model is present.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The tap runs on the audio thread; appending a buffer is safe there.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Callback arrives off the main actor — hop back before touching state.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    if self.status == .listening { self.stop() }
                }
            }
        }
    }

    private func teardown() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Authorization

    private func authorizeSpeech() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    private func authorizeMic() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}
