import AVFoundation
import Foundation

enum RecorderState: Equatable {
    case idle
    case recording
    case uploading
    case done
    case error
}

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var state: RecorderState = .idle
    @Published var lastFilename: String?
    @Published var errorMessage: String?
    /// Normalised audio level while recording (0 = silence, 1 = peak). Smoothed with fast attack / slow decay.
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var currentFileURL: URL?
    private var meterTimer: Timer?

    // MARK: - Recording

    func startRecording() {
        Task {
            guard await requestMicrophonePermission() else {
                state = .error
                errorMessage = "Microphone access denied. Enable it in Settings."
                return
            }
            beginRecording()
        }
    }

    private func beginRecording() {
        let filename = makeFilename()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            currentFileURL = url
            lastFilename = filename
            state = .recording
            startMeterTimer()
        } catch {
            let detail = audioSessionErrorDetail(error)
            assertionFailure("AudioRecorder.beginRecording failed: \(detail)")
            state = .error
            errorMessage = detail
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let recorder = audioRecorder, recorder.isRecording else {
            completion(nil)
            return
        }
        stopMeterTimer()
        recorder.stop()
        completion(currentFileURL)
    }

    // MARK: - Metering

    private func startMeterTimer() {
        // ~30 fps is plenty for a smooth visual response
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let rec = self.audioRecorder, rec.isRecording else { return }
                rec.updateMeters()
                // averagePower returns dB in roughly -160…0; map -50…0 dB → 0…1
                let db  = rec.averagePower(forChannel: 0)
                let raw = max(0, min(1, (db + 50) / 50))
                // Fast attack, slow decay — feels like a proper VU meter
                if raw > self.audioLevel {
                    self.audioLevel += (raw - self.audioLevel) * 0.75
                } else {
                    self.audioLevel += (raw - self.audioLevel) * 0.20
                }
            }
        }
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioLevel = 0
    }

    // MARK: - Helpers

    /// Filename format: {year}-{day}-{month}-{unix}.m4a  (AAC in MPEG-4 container)
    private func makeFilename() -> String {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let day = calendar.component(.day, from: now)
        let month = calendar.component(.month, from: now)
        let unix = Int(now.timeIntervalSince1970)
        return "\(year)-\(String(format: "%02d", day))-\(String(format: "%02d", month))-\(unix).m4a"
    }

    private func audioSessionErrorDetail(_ error: Error) -> String {
        let ns = error as NSError
        // AVFoundation/CoreAudio OSStatus codes are four-char codes or negative ints.
        // Surface domain + code + description so the raw value is visible in Xcode.
        return "[\(ns.domain) \(ns.code)] \(ns.localizedDescription)"
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let detail: String
        if let error {
            let ns = error as NSError
            detail = "[\(ns.domain) \(ns.code)] \(ns.localizedDescription)"
        } else {
            detail = "Audio encoding error (no details)"
        }
        assertionFailure("audioRecorderEncodeErrorDidOccur: \(detail)")
        Task { @MainActor in
            self.state = .error
            self.errorMessage = detail
        }
    }
}
