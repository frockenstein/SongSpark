import SwiftUI

struct ClipsView: View {
    @EnvironmentObject var clipStore: ClipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("CLIPS")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                        .tracking(4)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.08))

                if clipStore.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color(red: 1.0, green: 0.75, blue: 0.3))
                    Spacer()
                } else if clipStore.clips.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color.white.opacity(0.15))
                        Text("No clips yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(clipStore.clips) { clip in
                                ClipRow(clip: clip)
                                    .environmentObject(clipStore)
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 64)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        await clipStore.loadClips()
                    }
                }

                if let error = clipStore.errorMessage {
                    HStack {
                        Text(error)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        Spacer()
                        Button {
                            clipStore.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 16)
                        }
                    }
                    .background(Color(red: 0.18, green: 0.10, blue: 0.10))
                }
            }
        }
    }
}

// MARK: - Clip Row

struct ClipRow: View {
    let clip: Clip
    @EnvironmentObject var clipStore: ClipStore

    private var isPlaying: Bool { clipStore.playingFilename == clip.filename }
    private var isDownloading: Bool { clipStore.isDownloading && clipStore.playingFilename == nil }

    var body: some View {
        HStack(spacing: 16) {
            // Play / stop button
            Button {
                Task { await clipStore.togglePlayback(clip: clip) }
            } label: {
                ZStack {
                    Circle()
                        .fill(isPlaying
                            ? Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15)
                            : Color.white.opacity(0.07))
                        .frame(width: 40, height: 40)

                    if isDownloading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isPlaying
                                ? Color(red: 1.0, green: 0.4, blue: 0.4)
                                : Color.white.opacity(0.7))
                    }
                }
            }
            .buttonStyle(.plain)

            // Clip info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(clip.formattedDay)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(clip.formattedTime)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Text(clip.filename)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.25))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if isPlaying {
                    ProgressBar(progress: clipStore.playbackProgress)
                        .frame(height: 2)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.12))

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 1.0, green: 0.4, blue: 0.4))
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 0.05), value: progress)
            }
        }
    }
}

#Preview {
    ClipsView()
        .environmentObject(ClipStore())
}
