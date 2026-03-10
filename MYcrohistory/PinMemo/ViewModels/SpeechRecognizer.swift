import Foundation
import Speech
import AVFoundation
import Observation

@Observable final class SpeechRecognizer {
    var transcript: String = ""
    var isRecording: Bool = false
    var errorMessage: String? = nil

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var previousText: String = ""

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    }

    // MARK: - Public

    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self, authStatus == .authorized else { return }
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard let self, granted else { return }
                DispatchQueue.main.async { self.beginSession() }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        previousText = transcript

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Session Setup

    private func beginSession() {
        // Fallback to English if Korean recognizer unavailable
        if !(speechRecognizer?.isAvailable ?? false) {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let speechRecognizer, let recognitionRequest else {
            errorMessage = "Speech recognizer unavailable"
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async {
                    let current = result.bestTranscription.formattedString
                    if self.previousText.isEmpty {
                        self.transcript = current
                    } else {
                        self.transcript = self.previousText + " " + current
                    }
                }
            }
            if error != nil && self.isRecording {
                DispatchQueue.main.async {
                    self.errorMessage = error?.localizedDescription
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Audio engine failed: \(error.localizedDescription)"
        }
    }
}
