import SwiftUI

struct ClipsView: View {
    @EnvironmentObject var clipStore: ClipStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingClip: Clip?
    @State private var deletingClip: Clip?

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
                                ClipRow(clip: clip, onEdit: { editingClip = clip }, onDelete: { deletingClip = clip })
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

                if clipStore.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.gray).scaleEffect(0.7)
                        Text("Saving...").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
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
        .sheet(item: $editingClip) { clip in
            ClipNameSheet(
                title: "RENAME CLIP",
                initialValue: clip.description ?? ""
            ) { description in
                Task { await clipStore.renameClip(clip, description: description) }
            }
        }
        .confirmationDialog("Delete this clip?", isPresented: Binding(
            get: { deletingClip != nil },
            set: { if !$0 { deletingClip = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let clip = deletingClip {
                    Task { await clipStore.deleteClip(clip) }
                }
                deletingClip = nil
            }
            Button("Cancel", role: .cancel) { deletingClip = nil }
        } message: {
            if let clip = deletingClip {
                Text(clip.description ?? clip.filename)
            }
        }
    }
}

// MARK: - Clip Row

struct ClipRow: View {
    let clip: Clip
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject var clipStore: ClipStore

    private var isPlaying: Bool { clipStore.playingFilename == clip.filename }
    private var isThisDownloading: Bool { clipStore.isDownloading && clipStore.playingFilename == nil }

    var body: some View {
        HStack(spacing: 12) {
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

                    if isThisDownloading {
                        ProgressView().tint(.white).scaleEffect(0.7)
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
            VStack(alignment: .leading, spacing: 3) {
                if let desc = clip.description {
                    Text(desc)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(clip.formattedDay)
                        .font(.system(size: clip.description == nil ? 14 : 11, design: .monospaced))
                        .foregroundColor(clip.description == nil ? .white : Color.white.opacity(0.45))
                    Text(clip.formattedTime)
                        .font(.system(size: clip.description == nil ? 14 : 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                }

                if isPlaying {
                    ProgressBar(progress: clipStore.playbackProgress)
                        .frame(height: 2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            // Edit / delete
            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.35))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
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
