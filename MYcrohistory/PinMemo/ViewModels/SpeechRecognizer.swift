import Foundation
import Speech
import AVFoundation
import Observation
import WhisperKit

@Observable final class SpeechRecognizer {
    var transcript: String = ""
    var finalTranscript: String? = nil
    var isRecording: Bool = false
    var isModelLoading: Bool = false
    var errorMessage: String? = nil

    private var whisperKit: WhisperKit?

    // Apple STT — live partial display
    private var appleRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Audio engine shared by both Apple STT and Whisper buffering
    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private let whisperSampleRate: Double = 16000

    // Whisper state
    private var whisperSampleBuffer: [Float] = []   // current 5s window samples
    private var committedText: String = ""           // Whisper-confirmed text
    private var applePartial: String = ""            // Apple live partial
    private var whisperTimer: Timer?
    private let whisperInterval: TimeInterval = 5.0

    init() {
        appleRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
        Task { await loadModel() }
    }

    @MainActor
    private func loadModel() async {
        isModelLoading = true
        do {
            whisperKit = try await WhisperKit(model: "openai_whisper-small")
        } catch {
            errorMessage = "Model load failed: \(error.localizedDescription)"
        }
        isModelLoading = false
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
        whisperTimer?.invalidate()
        whisperTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        // Run Whisper on whatever's left in the buffer
        let remaining = whisperSampleBuffer
        whisperSampleBuffer = []
        if !remaining.isEmpty {
            Task { await runWhisper(on: remaining, isFinal: true) }
        }
    }

    // MARK: - Session Setup

    private func beginSession() {
        // Fallback to English if Korean recognizer unavailable
        if !(appleRecognizer?.isAvailable ?? false) {
            appleRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        // Converter: native rate → 16kHz mono float for Whisper
        if let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: whisperSampleRate,
            channels: 1,
            interleaved: false
        ) {
            audioConverter = AVAudioConverter(from: nativeFormat, to: whisperFormat)
        }

        committedText = ""
        applePartial = ""
        whisperSampleBuffer = []
        transcript = ""
        finalTranscript = nil

        startAppleSTT()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Feed to Apple STT
            self.recognitionRequest?.append(buffer)
            // Accumulate downsampled samples for Whisper
            self.accumulateSamples(from: buffer, nativeFormat: nativeFormat)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Audio engine failed: \(error.localizedDescription)"
            return
        }

        // Fire Whisper every 5 seconds
        whisperTimer = Timer.scheduledTimer(withTimeInterval: whisperInterval, repeats: true) { [weak self] _ in
            self?.flushToWhisper()
        }
    }

    // MARK: - Apple STT

    private func startAppleSTT() {
        guard let appleRecognizer else { return }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        recognitionTask = appleRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.applePartial = text
                    self.updateTranscript()
                }
            }
            // Silently restart on isFinal or non-fatal error
            if result?.isFinal == true || (error != nil && self.isRecording) {
                DispatchQueue.main.async { self.resetAppleSTT() }
            }
        }
    }

    private func resetAppleSTT() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        applePartial = ""
        if isRecording { startAppleSTT() }
    }

    // MARK: - Whisper

    private func accumulateSamples(from buffer: AVAudioPCMBuffer, nativeFormat: AVAudioFormat) {
        guard let converter = audioConverter,
              let whisperFormat = converter.outputFormat as? AVAudioFormat else { return }

        let ratio = whisperSampleRate / nativeFormat.sampleRate
        let outCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: outCapacity) else { return }

        var inputConsumed = false
        converter.convert(to: outBuffer, error: nil) { _, status in
            if inputConsumed { status.pointee = .noDataNow; return nil }
            status.pointee = .haveData
            inputConsumed = true
            return buffer
        }

        if let data = outBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: data, count: Int(outBuffer.frameLength)))
            whisperSampleBuffer.append(contentsOf: samples)
        }
    }

    private func flushToWhisper() {
        guard !whisperSampleBuffer.isEmpty else { return }
        let samples = whisperSampleBuffer
        whisperSampleBuffer = []
        resetAppleSTT()  // reset Apple window to match Whisper window
        Task { await runWhisper(on: samples, isFinal: false) }
    }

    @MainActor
    private func runWhisper(on samples: [Float], isFinal: Bool) async {
        guard let whisperKit, samples.count > Int(whisperSampleRate * 0.5) else { return }
        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: "ko",
                temperature: 0.0,
                temperatureFallbackCount: 3,
                withoutTimestamps: true
            )
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return }
            let sep = committedText.isEmpty ? "" : " "
            committedText += sep + text
            if isFinal { applePartial = "" }
            updateTranscript()
            if isFinal { finalTranscript = transcript }
        } catch {
            // Silently ignore mid-session Whisper errors
            if isFinal { errorMessage = error.localizedDescription }
        }
    }

    private func updateTranscript() {
        let sep = (committedText.isEmpty || applePartial.isEmpty) ? "" : " "
        transcript = committedText + sep + applePartial
    }
}
