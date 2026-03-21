import AVFoundation
import Foundation
@preconcurrency import SwiftyDropbox

@MainActor
final class ClipStore: NSObject, ObservableObject {
    @Published var clips: [Clip] = []
    @Published var isLoading = false
    @Published var playingFilename: String?
    @Published var playbackProgress: Double = 0
    @Published var isDownloading = false
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private static let metadataPath = "/clips.json"

    // MARK: - Metadata

    func loadClips() async {
        guard let client = DropboxClientsManager.authorizedClient else { return }
        isLoading = true
        defer { isLoading = false }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.files.download(path: Self.metadataPath)
                .response { [weak self] response, error in
                    Task { @MainActor [weak self] in
                        guard let self else { continuation.resume(); return }

                        if let error {
                            // 409 / path not found = no clips yet, not a real error
                            let desc = "\(error)"
                            if desc.contains("notFound") || desc.contains("not_found") || desc.contains("path/not_found") {
                                self.clips = []
                            } else {
                                self.errorMessage = "Could not load clips: \(desc)"
                            }
                            continuation.resume()
                            return
                        }

                        if let (_, data) = response {
                            do {
                                self.clips = try Self.decoder.decode([Clip].self, from: data)
                            } catch {
                                self.errorMessage = "Could not parse clips: \(error.localizedDescription)"
                            }
                        }
                        continuation.resume()
                    }
                }
        }
    }

    func addClip(filename: String, createdAt: Date = Date()) async {
        let clip = Clip(filename: filename, createdAt: createdAt)
        clips.insert(clip, at: 0)
        await saveMetadata()
    }

    func renameClip(_ clip: Clip, description: String?) async {
        let newFilename = buildFilename(from: clip.filename, description: description)
        guard newFilename != clip.filename else { return }

        guard let client = DropboxClientsManager.authorizedClient else {
            errorMessage = "Not connected to Dropbox."
            return
        }

        // Move in Dropbox
        let moved = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            client.files.moveV2(fromPath: "/\(clip.filename)", toPath: "/\(newFilename)")
                .response { [weak self] _, error in
                    Task { @MainActor [weak self] in
                        if let error {
                            self?.errorMessage = "Rename failed: \(error.description)"
                            continuation.resume(returning: false)
                        } else {
                            continuation.resume(returning: true)
                        }
                    }
                }
        }

        guard moved else { return }

        // Rename local cache file if present
        let oldCache = cacheURL(for: clip.filename)
        let newCache = cacheURL(for: newFilename)
        if FileManager.default.fileExists(atPath: oldCache.path) {
            try? FileManager.default.moveItem(at: oldCache, to: newCache)
        }

        // If this clip was playing, stop so we don't hold a stale reference
        if playingFilename == clip.filename { stop() }

        // Update in-memory array and persist
        if let idx = clips.firstIndex(of: clip) {
            clips[idx] = Clip(filename: newFilename, createdAt: clip.createdAt)
        }
        await saveMetadata()
    }

    func deleteClip(_ clip: Clip) async {
        guard let client = DropboxClientsManager.authorizedClient else {
            errorMessage = "Not connected to Dropbox."
            return
        }

        let deleted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            client.files.deleteV2(path: "/\(clip.filename)")
                .response { [weak self] _, error in
                    Task { @MainActor [weak self] in
                        if let error {
                            self?.errorMessage = "Delete failed: \(error.description)"
                            continuation.resume(returning: false)
                        } else {
                            continuation.resume(returning: true)
                        }
                    }
                }
        }

        guard deleted else { return }

        // Remove local cache
        let cache = cacheURL(for: clip.filename)
        try? FileManager.default.removeItem(at: cache)

        if playingFilename == clip.filename { stop() }

        clips.removeAll { $0.id == clip.id }
        await saveMetadata()
    }

    // MARK: - Filename helpers

    /// Sanitize a user-entered description for use in a filename.
    static func sanitize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// Rebuild a filename, replacing or removing the description part.
    /// Format: {year}-{day}-{month}-{unix}[-{description}].m4a
    private func buildFilename(from original: String, description: String?) -> String {
        let base = (original as NSString).deletingPathExtension
        let parts = base.components(separatedBy: "-")
        let timestamp = parts.prefix(4).joined(separator: "-")
        if let desc = description, !desc.isEmpty {
            let sanitized = Self.sanitize(desc)
            return sanitized.isEmpty ? "\(timestamp).m4a" : "\(timestamp)-\(sanitized).m4a"
        }
        return "\(timestamp).m4a"
    }

    private func saveMetadata() async {
        guard let client = DropboxClientsManager.authorizedClient else { return }

        let data: Data
        do {
            data = try Self.encoder.encode(clips)
        } catch {
            errorMessage = "Could not encode clips: \(error.localizedDescription)"
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.files.upload(path: Self.metadataPath, mode: .overwrite, input: data)
                .response { [weak self] _, error in
                    Task { @MainActor [weak self] in
                        if let error {
                            self?.errorMessage = "Could not save clips metadata: \(error.description)"
                        }
                        continuation.resume()
                    }
                }
        }
    }

    // MARK: - Playback

    func togglePlayback(clip: Clip) async {
        if playingFilename == clip.filename {
            stop()
            return
        }
        stop()
        await startPlayback(clip: clip)
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingFilename = nil
        playbackProgress = 0
        stopProgressTimer()
    }

    private func startPlayback(clip: Clip) async {
        isDownloading = true
        let url: URL
        do {
            url = try await ensureLocalFile(for: clip)
        } catch {
            isDownloading = false
            errorMessage = "Could not load audio: \(error.localizedDescription)"
            return
        }
        isDownloading = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            playingFilename = clip.filename
            startProgressTimer()
        } catch {
            errorMessage = "Playback error: \(error.localizedDescription)"
        }
    }

    // MARK: - File cache

    private func ensureLocalFile(for clip: Clip) async throws -> URL {
        let dest = cacheURL(for: clip.filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest
        }
        return try await downloadFile(filename: clip.filename, to: dest)
    }

    private func downloadFile(filename: String, to destination: URL) async throws -> URL {
        guard let client = DropboxClientsManager.authorizedClient else {
            throw ClipError.notAuthorized
        }

        // Create cache directory if needed
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            client.files.download(path: "/\(filename)")
                .response { response, error in
                    if let error {
                        continuation.resume(throwing: ClipError.downloadFailed(error.description))
                        return
                    }
                    guard let (_, data) = response else {
                        continuation.resume(throwing: ClipError.downloadFailed("Empty response"))
                        return
                    }
                    do {
                        try data.write(to: destination)
                        continuation.resume(returning: destination)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    private func cacheURL(for filename: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("songspark")
            .appendingPathComponent(filename)
    }

    // MARK: - Progress timer

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.audioPlayer, player.duration > 0 else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - JSON helpers

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

// MARK: - AVAudioPlayerDelegate

extension ClipStore: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard let current = self.playingFilename,
                  let idx = self.clips.firstIndex(where: { $0.filename == current }),
                  idx + 1 < self.clips.count else {
                self.stop()
                return
            }
            self.stop()
            await self.startPlayback(clip: self.clips[idx + 1])
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stop()
            self.errorMessage = "Playback decode error: \(error?.localizedDescription ?? "unknown")"
        }
    }
}

// MARK: - Errors

enum ClipError: LocalizedError {
    case notAuthorized
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Not connected to Dropbox."
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        }
    }
}
