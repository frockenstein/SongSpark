import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dropboxManager: DropboxManager
    @EnvironmentObject var clipStore: ClipStore
    @StateObject private var recorder = AudioRecorder()
    @State private var showSettings = false
    @State private var showClips = false
    @State private var pendingUploadURL: URL?
    @State private var showNamingSheet = false

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ──────────────────────────────────────────────
                HStack {
                    Button { showClips = true } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.55))
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text("SONGSPARK")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                        .tracking(5)

                    Spacer()

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.55))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                // ── Status ───────────────────────────────────────────────
                VStack(spacing: 10) {
                    Text(statusText)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(statusColor)
                        .animation(.easeInOut, value: recorder.state)

                    if recorder.state == .error, let msg = recorder.errorMessage {
                        Text(msg)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else if let filename = recorder.lastFilename {
                        Text(filename)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 32)
                    }
                }
                .frame(minHeight: 52)

                Spacer()

                // ── Record button ─────────────────────────────────────────
                RecordButton(
                    isRecording: recorder.state == .recording,
                    audioLevel: recorder.audioLevel
                ) {
                    handleRecordTap()
                }

                Spacer()

                // ── Dropbox status ────────────────────────────────────────
                DropboxStatusView()
                    .environmentObject(dropboxManager)
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(dropboxManager)
                .environmentObject(clipStore)
        }
        .sheet(isPresented: $showClips) {
            ClipsView().environmentObject(clipStore)
        }
        .sheet(isPresented: $showNamingSheet) {
            ClipNameSheet(availableTags: clipStore.availableTags, onCancel: cancelPendingRecording) { description, tags in
                uploadPendingRecording(description: description, tags: tags)
            }
        }
    }

    // MARK: - Status helpers

    private var statusText: String {
        switch recorder.state {
        case .idle:      return "READY"
        case .recording: return "● REC"
        case .uploading: return "UPLOADING..."
        case .done:      return "SAVED ✓"
        case .error:     return "ERROR —"
        }
    }

    private var statusColor: Color {
        switch recorder.state {
        case .idle:      return .gray
        case .recording: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .uploading: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .done:      return Color(red: 0.4, green: 0.9, blue: 0.4)
        case .error:     return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    // MARK: - Actions

    private func handleRecordTap() {
        switch recorder.state {
        case .idle, .done, .error:
            recorder.errorMessage = nil
            recorder.startRecording()
        case .recording:
            recorder.stopRecording { fileURL in
                guard let fileURL else {
                    recorder.errorMessage = "Failed to finalize the recording file."
                    recorder.state = .error
                    return
                }
                pendingUploadURL = fileURL
                recorder.state = .idle
                showNamingSheet = true
            }
        case .uploading:
            break
        }
    }

    private func cancelPendingRecording() {
        if let url = pendingUploadURL {
            try? FileManager.default.removeItem(at: url)
            pendingUploadURL = nil
        }
        recorder.state = .idle
    }

    private func uploadPendingRecording(description: String?, tags: [String]) {
        guard let fileURL = pendingUploadURL else { return }
        pendingUploadURL = nil

        var uploadURL = fileURL
        if let desc = description, !desc.trimmingCharacters(in: .whitespaces).isEmpty {
            let sanitized = ClipStore.sanitize(desc)
            if !sanitized.isEmpty {
                let base = (fileURL.lastPathComponent as NSString).deletingPathExtension
                let newName = "\(base)-\(sanitized).m4a"
                let newURL = fileURL.deletingLastPathComponent().appendingPathComponent(newName)
                if (try? FileManager.default.moveItem(at: fileURL, to: newURL)) != nil {
                    uploadURL = newURL
                }
            }
        }

        recorder.state = .uploading
        let filename = uploadURL.lastPathComponent
        dropboxManager.upload(fileURL: uploadURL) { result in
            switch result {
            case .success:
                recorder.state = .done
                Task { await clipStore.addClip(filename: filename, tags: tags) }
            case .failure(let error):
                recorder.errorMessage = error.localizedDescription
                recorder.state = .error
            }
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let audioLevel: Float   // 0–1, live metered level while recording
    let action: () -> Void

    @State private var isPressing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(
                        isRecording
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : Color(red: 0.6, green: 0.5, blue: 0.4),
                        lineWidth: 5
                    )
                    .frame(width: 200, height: 200)

                // Inner button — scales and glows with live audio level
                Circle()
                    .fill(
                        isRecording
                            ? Color(red: 0.85, green: 0.2, blue: 0.2)
                            : Color(red: 0.8, green: 0.3, blue: 0.2)
                    )
                    .frame(width: 168, height: 168)
                    .scaleEffect(isRecording ? 1.0 + CGFloat(audioLevel) * 0.30 : 1.0)
                    .shadow(
                        color: isRecording
                            ? Color(red: 1.0, green: 0.2, blue: 0.2)
                                .opacity(0.2 + Double(audioLevel) * 1.0)
                            : .black.opacity(0.5),
                        radius: isRecording ? 8 + CGFloat(audioLevel) * 74 : 10,
                        x: 0,
                        y: isRecording ? 0 : 6
                    )
                    .animation(.easeOut(duration: 0.08), value: audioLevel)

                // Icon
                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white)
                        .frame(width: 48, height: 48)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 56, height: 56)
                }
            }
        }
        .scaleEffect(isPressing ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressing = true }
                .onEnded { _ in isPressing = false }
        )
        .buttonStyle(.plain)
    }
}

// MARK: - Dropbox Status View

struct DropboxStatusView: View {
    @EnvironmentObject var dropboxManager: DropboxManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dropboxManager.isAuthorized
                    ? Color(red: 0.4, green: 0.9, blue: 0.4)
                    : Color(red: 0.9, green: 0.4, blue: 0.4))
                .frame(width: 8, height: 8)
            Text(dropboxManager.isAuthorized ? "Dropbox connected" : "Dropbox not connected")
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(dropboxManager.isAuthorized
                    ? Color.white.opacity(0.5)
                    : Color(red: 0.9, green: 0.5, blue: 0.4))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DropboxManager())
        .environmentObject(ClipStore())
}

#Preview("RecordButton") {
    ZStack {
        Color(red: 0.12, green: 0.10, blue: 0.08).ignoresSafeArea()
        RecordButton(isRecording: true, audioLevel: 0.6) {}
    }
}
