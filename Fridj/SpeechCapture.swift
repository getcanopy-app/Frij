//
//  SpeechCapture.swift
//  Fridj
//
//  Live, on-device speech-to-text for the pantry's voice input. Wraps Apple's
//  Speech framework + AVAudioEngine and exposes a running transcript the UI can
//  render as the user talks. The transcript is then fed to /api/parse-ingredients
//  — the same parser the typed field uses — so voice reuses the whole pipeline.
//
//  Built for LONG dictation. SFSpeechRecognizer cuts a single recognition off
//  around a minute and tends to finalize when the speaker pauses to think, both
//  of which are exactly what happens when someone reads their whole pantry out
//  loud. So the audio engine stays live for the entire session and recognition
//  runs in SEGMENTS: whenever a segment ends — the 1-minute limit, a pause, or
//  an error — its text is committed and a fresh segment starts, seamlessly, for
//  as long as the user holds the mic. A safety cap stops a runaway session.
//
//  Deliberately Apple-only: on-device recognition where the locale supports it,
//  so no audio leaves the phone, no Whisper, no backend audio.
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
    /// Everything heard so far this session (committed segments + the live one).
    private(set) var transcript = ""

    var isListening: Bool { status == .listening }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Text already finalized from earlier segments, plus the current segment's
    // partial. `transcript` is their join, kept in sync via refresh().
    private var committed = ""
    private var partial = ""
    private var segmentCount = 0
    private var safetyTimer: Task<Void, Never>?

    private let maxSeconds: UInt64 = 180   // hard stop so a session can't run forever
    private let maxSegments = 90           // ~ maxSeconds / a short segment

    // MARK: Control

    func start() async {
        guard status != .listening else { return }
        committed = ""; partial = ""; transcript = ""; segmentCount = 0

        guard await authorizeSpeech(), await authorizeMic() else {
            status = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            return
        }

        do {
            try startEngine()
            status = .listening
            startSegment(with: recognizer)
            armSafetyTimer()
        } catch {
            teardown()
            status = .unavailable
        }
    }

    /// Stops listening and leaves `transcript` holding the full text.
    func stop() {
        commitPartial()
        teardown()
        status = .idle
    }

    // MARK: Engine (runs for the whole session)

    private func startEngine() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Runs on the audio thread. Appends to whichever request is current, so
        // it keeps feeding across segment restarts without being reinstalled.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    // MARK: Segments

    private func startSegment(with recognizer: SFSpeechRecognizer) {
        segmentCount += 1
        partial = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Callback arrives off the main actor — hop back before touching state.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.partial = result.bestTranscription.formattedString
                    self.refresh()
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.rollSegment(recognizer)
                }
            }
        }
    }

    /// A segment ended (1-min cutoff, a pause finalizing, or an error). Bank its
    /// text and, if the mic is still held, start another so dictation continues.
    private func rollSegment(_ recognizer: SFSpeechRecognizer) {
        commitPartial()
        task = nil
        request?.endAudio()
        request = nil

        guard status == .listening else { return }
        guard segmentCount < maxSegments else { stop(); return }

        // A tiny gap before restarting avoids a tight loop on repeated errors.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, self.status == .listening,
                  let recognizer = self.recognizer, recognizer.isAvailable else { return }
            self.startSegment(with: recognizer)
        }
    }

    private func commitPartial() {
        guard !partial.isEmpty else { return }
        committed = [committed, partial].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        partial = ""
        refresh()
    }

    private func refresh() {
        transcript = [committed, partial].joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private func armSafetyTimer() {
        safetyTimer?.cancel()
        let seconds = maxSeconds
        safetyTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard let self, self.status == .listening else { return }
            self.stop()
        }
    }

    private func teardown() {
        safetyTimer?.cancel()
        safetyTimer = nil
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
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
