import SwiftUI

struct ClipsView: View {
    @EnvironmentObject var clipStore: ClipStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeTag: String?   // nil = show all
    @State private var editingClip: Clip?
    @State private var deletingClip: Clip?

    private var filteredClips: [Clip] {
        guard let tag = activeTag else { return clipStore.clips }
        return clipStore.clips.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ───────────────────────────────────────────────
                HStack {
                    Text("CLIPS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
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
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.08))

                // ── Tag filter bar ────────────────────────────────────────
                if !clipStore.availableTags.isEmpty {
                    Text("FILTER BY TAG")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagFilterPill(label: "ALL", isActive: activeTag == nil) {
                                activeTag = nil
                            }
                            ForEach(clipStore.availableTags, id: \.self) { tag in
                                TagFilterPill(
                                    label: tag.uppercased(),
                                    isActive: activeTag == tag
                                ) {
                                    activeTag = (activeTag == tag) ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    Divider().background(Color.white.opacity(0.08))
                }

                // ── Clip list ─────────────────────────────────────────────
                if clipStore.isLoading {
                    Spacer()
                    ProgressView().tint(Color(red: 1.0, green: 0.75, blue: 0.3))
                    Spacer()
                } else if filteredClips.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color.white.opacity(0.15))
                        Text(activeTag == nil ? "No clips yet" : "No clips tagged \"\(activeTag!)\"")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredClips) { clip in
                                ClipRow(
                                    clip: clip,
                                    onEdit:   { editingClip   = clip },
                                    onDelete: { deletingClip  = clip }
                                )
                                .environmentObject(clipStore)

                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 64)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable { await clipStore.loadClips() }
                }

                // ── Error banner ──────────────────────────────────────────
                if let error = clipStore.errorMessage {
                    HStack {
                        Text(error)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        Spacer()
                        Button { clipStore.errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 16)
                        }
                    }
                    .background(Color(red: 0.18, green: 0.10, blue: 0.10))
                }
            }
        }
        // Keep ClipStore's currentQueue in sync with whatever is visible.
        .onAppear { clipStore.currentQueue = filteredClips }
        .onChange(of: activeTag)         { _, _ in clipStore.currentQueue = filteredClips }
        .onChange(of: clipStore.clips)   { _, _ in clipStore.currentQueue = filteredClips }
        // Edit sheet
        .sheet(item: $editingClip) { clip in
            ClipNameSheet(
                title: "EDIT CLIP",
                initialValue: clip.description ?? "",
                availableTags: clipStore.availableTags,
                initialTags: clip.tags
            ) { description, tags in
                Task { await clipStore.renameClip(clip, description: description, tags: tags) }
            }
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete this clip?",
            isPresented: Binding(
                get: { deletingClip != nil },
                set: { if !$0 { deletingClip = nil } }
            ),
            titleVisibility: .visible
        ) {
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

// MARK: - Tag filter pill

struct TagFilterPill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(isActive
                    ? Color(red: 0.12, green: 0.10, blue: 0.08)
                    : Color.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive
                    ? Color(red: 1.0, green: 0.75, blue: 0.3)
                    : Color.white.opacity(0.07))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(
                    isActive ? Color.clear : Color.white.opacity(0.12),
                    lineWidth: 1
                ))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Clip row

struct ClipRow: View {
    let clip: Clip
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject var clipStore: ClipStore

    private var isPlaying: Bool { clipStore.playingFilename == clip.filename }
    private var isThisDownloading: Bool {
        clipStore.isDownloading && clipStore.playingFilename == nil
    }

    var body: some View {
        HStack(spacing: 12) {

            // Play / stop
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
            VStack(alignment: .leading, spacing: 4) {
                if let desc = clip.description {
                    Text(desc)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(clip.formattedDay)
                        .font(.system(size: clip.description == nil ? 17 : 13, design: .monospaced))
                        .foregroundColor(clip.description == nil ? .white : Color.white.opacity(0.45))
                    Text(clip.formattedTime)
                        .font(.system(size: clip.description == nil ? 17 : 13, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                }

                // Tags
                if !clip.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(clip.tags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Playback progress bar
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

// MARK: - Progress bar

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 1.0, green: 0.4, blue: 0.4))
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 0.05), value: progress)
            }
        }
    }
}

#Preview {
    ClipsView().environmentObject(ClipStore())
}
