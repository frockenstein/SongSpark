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

    private var audioRecorder: AVAudioRecorder?
    private var currentFileURL: URL?

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
            audioRecorder?.record()

            currentFileURL = url
            lastFilename = filename
            state = .recording
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

        recorder.stop()
        state = .uploading
        completion(currentFileURL)
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
