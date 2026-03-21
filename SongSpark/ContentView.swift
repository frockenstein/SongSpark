import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dropboxManager: DropboxManager
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 4) {
                    Text("SONGSPARK")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                        .tracking(6)

                    Text("v0.1")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Status display
                VStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(statusColor)
                        .animation(.easeInOut, value: recorder.state)

                    if recorder.state == .error, let errorMessage = recorder.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else if let filename = recorder.lastFilename {
                        Text(filename)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(minHeight: 50)

                // Record button
                RecordButton(isRecording: recorder.state == .recording) {
                    handleRecordTap()
                }

                // Dropbox status / auth
                DropboxStatusView()
                    .environmentObject(dropboxManager)
            }
            .padding()
        }
    }

    private var statusText: String {
        switch recorder.state {
        case .idle: return "READY"
        case .recording: return "● REC"
        case .uploading: return "UPLOADING..."
        case .done: return "SAVED ✓"
        case .error: return "ERROR —"
        }
    }

    private var statusColor: Color {
        switch recorder.state {
        case .idle: return .gray
        case .recording: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .uploading: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .done: return Color(red: 0.4, green: 0.9, blue: 0.4)
        case .error: return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

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
                dropboxManager.upload(fileURL: fileURL) { result in
                    switch result {
                    case .success:
                        recorder.state = .done
                    case .failure(let error):
                        recorder.errorMessage = error.localizedDescription
                        recorder.state = .error
                    }
                }
            }
        case .uploading:
            break
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
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
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)

                // Inner button
                Circle()
                    .fill(
                        isRecording
                            ? Color(red: 0.85, green: 0.2, blue: 0.2)
                            : Color(red: 0.8, green: 0.3, blue: 0.2)
                    )
                    .frame(width: 96, height: 96)
                    .shadow(
                        color: isRecording
                            ? Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.6)
                            : .black.opacity(0.5),
                        radius: isRecording ? 16 : 6,
                        x: 0,
                        y: isRecording ? 0 : 4
                    )

                // Icon
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .scaleEffect(isPressing ? 0.94 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressing)
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
        VStack(spacing: 8) {
            if dropboxManager.isAuthorized {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.4, green: 0.9, blue: 0.4))
                        .frame(width: 6, height: 6)
                    Text("Dropbox connected")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
            } else {
                Button("Connect Dropbox") {
                    dropboxManager.startAuth()
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(red: 0.3, green: 0.6, blue: 1.0), lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DropboxManager())
}
