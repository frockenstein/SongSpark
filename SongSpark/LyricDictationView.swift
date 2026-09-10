import SwiftUI

struct LyricDictationView: View {
    @EnvironmentObject var clipStore: ClipStore
    @StateObject private var recognizer = SpeechRecognizer()
    @Environment(\.dismiss) private var dismiss
    @State private var showNameSheet = false

    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let danger  = Color(red: 1.0, green: 0.35, blue: 0.35)
    private let bg      = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                HStack {
                    // Listening indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(recognizer.isListening ? danger : Color.clear)
                            .frame(width: 8, height: 8)
                            .opacity(recognizer.isListening ? 1 : 0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recognizer.isListening)
                        Text(recognizer.isListening ? "LIVE" : "")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(danger)
                            .tracking(2)
                    }
                    .frame(width: 52, alignment: .leading)
                    .padding(.leading, 12)

                    Spacer()

                    Text("LYRICS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(amber)
                        .tracking(5)

                    Spacer()

                    HStack(spacing: 4) {
                        if !recognizer.transcript.isEmpty {
                            Button {
                                recognizer.stopListening()
                                showNameSheet = true
                            } label: {
                                Text("SAVE")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(amber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(amber.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.68))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .padding(.top, 12)

                // ── Transcript area ───────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(recognizer.transcript.isEmpty
                             ? "Tap the mic and start speaking…"
                             : recognizer.transcript)
                            .font(.system(size: 18, weight: .regular, design: .monospaced))
                            .foregroundColor(
                                recognizer.transcript.isEmpty
                                    ? .white.opacity(0.40)
                                    : .white.opacity(0.9)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .id("bottom")
                    }
                    .onChange(of: recognizer.transcript) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // ── Error ─────────────────────────────────────────────────
                if let msg = recognizer.errorMessage {
                    Text(msg)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                }

                // ── Controls ──────────────────────────────────────────────
                HStack(alignment: .center, spacing: 0) {
                    // Clear
                    Button {
                        recognizer.clearTranscript()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                            Text("CLEAR")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundColor(
                            recognizer.transcript.isEmpty ? .white.opacity(0.45) : danger
                        )
                        .frame(width: 72)
                    }
                    .disabled(recognizer.transcript.isEmpty)

                    Spacer()

                    // Mic button
                    Button {
                        if recognizer.isListening {
                            recognizer.stopListening()
                        } else {
                            recognizer.startListening()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    recognizer.isListening
                                        ? danger
                                        : Color(red: 0.6, green: 0.5, blue: 0.4),
                                    lineWidth: 4
                                )
                                .frame(width: 90, height: 90)

                            Circle()
                                .fill(
                                    recognizer.isListening
                                        ? Color(red: 0.85, green: 0.2, blue: 0.2)
                                        : Color(red: 0.8, green: 0.3, blue: 0.2)
                                )
                                .frame(width: 74, height: 74)

                            Image(systemName: recognizer.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                        }
                        .animation(.easeInOut(duration: 0.2), value: recognizer.isListening)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Copy
                    Button {
                        UIPasteboard.general.string = recognizer.transcript
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 20))
                            Text("COPY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundColor(
                            recognizer.transcript.isEmpty ? .white.opacity(0.45) : amber
                        )
                        .frame(width: 72)
                    }
                    .disabled(recognizer.transcript.isEmpty)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 44)
            }
        }
        .onDisappear {
            recognizer.stopListening()
        }
        .sheet(isPresented: $showNameSheet) {
            let capturedText = recognizer.transcript
            ClipNameSheet(
                title: "NAME THIS LYRIC",
                availableTags: clipStore.availableTags,
                onCancel: { },
                onSave: { description, tags, newTags in
                    Task {
                        await clipStore.addLyric(
                            text: capturedText,
                            description: description,
                            tags: tags,
                            newAvailableTags: newTags
                        )
                    }
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    LyricDictationView()
}
