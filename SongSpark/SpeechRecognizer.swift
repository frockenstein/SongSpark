import Speech
import AVFoundation

// Not @MainActor — Swift would insert _swift_task_checkIsolatedSwift at the
// entry of every closure passed to TCC/AVAudioEngine callbacks, which fire on
// background queues and cause _dispatch_assert_queue_fail on real devices.
// All @Published mutations happen explicitly on DispatchQueue.main instead.
final class SpeechRecognizer: ObservableObject, @unchecked Sendable {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var errorMessage: String?
    @Published var permissionsReady = false

    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    private var baseText = ""
    private var userStopped = false
    private var hasTap = false
    private var currentCycleID: UUID?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestPermissionsEagerly()
    }

    // MARK: - Public API (call from main thread)

    func startListening() {
        guard permissionsReady else {
            errorMessage = "Microphone or speech recognition not authorized. Check Settings."
            return
        }
        guard !hasTap else { return }
        userStopped = false
        errorMessage = nil
        beginCycle()
    }

    func stopListening() {
        userStopped = true
        baseText = transcript
        tearDown()
        isListening = false
    }

    func clearTranscript() {
        baseText = ""
        transcript = ""
    }

    // MARK: - Private

    private func requestPermissionsEagerly() {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            // No @MainActor here — TCC fires this on a background queue.
            guard speechStatus == .authorized else {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Speech recognition access denied. Enable it in Settings."
                }
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if granted { self.permissionsReady = true }
                    else { self.errorMessage = "Microphone access denied. Enable it in Settings." }
                }
            }
        }
    }

    private func beginCycle() {
        let cycleID = UUID()
        currentCycleID = cycleID

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let inputNode = engine.inputNode
            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buffer, _ in
                req.append(buffer)
            }
            hasTap = true
            engine.prepare()
            try engine.start()
        } catch {
            errorMessage = error.localizedDescription
            hasTap = false
            return
        }

        isListening = true

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            // No @MainActor here — SFSpeechRecognitionTask fires this on a background queue.
            let text      = result?.bestTranscription.formattedString
            let isFinal   = result?.isFinal ?? false
            let errDomain = (error as NSError?)?.domain
            let errCode   = (error as NSError?)?.code
            let errDesc   = error?.localizedDescription

            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentCycleID == cycleID else { return }

                if let text {
                    self.transcript = self.baseText.isEmpty
                        ? text
                        : self.baseText + "\n" + text
                    if isFinal { self.baseText = self.transcript }
                }

                if let errDesc {
                    let cancelled = errDomain == "kAFAssistantErrorDomain" && errCode == 301
                    if !cancelled && !self.userStopped { self.errorMessage = errDesc }
                    self.tearDown()
                    self.isListening = false
                } else if isFinal {
                    self.tearDown()
                    if self.userStopped { self.isListening = false } else { self.beginCycle() }
                }
            }
        }
    }

    private func tearDown() {
        currentCycleID = nil
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        engine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
