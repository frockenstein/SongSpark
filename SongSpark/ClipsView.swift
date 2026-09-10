import SwiftUI

enum ClipSection: String, CaseIterable {
    case audio  = "AUDIO"
    case lyrics = "LYRICS"
}

struct ClipsView: View {
    @EnvironmentObject var clipStore: ClipStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeSection: ClipSection = .audio
    @State private var activeTags: Set<String> = []
    @State private var editingClip: Clip?
    @State private var deletingClip: Clip?

    private var sectionClips: [Clip] {
        clipStore.clips.filter { activeSection == .audio ? $0.type == .audio : $0.type == .lyric }
    }

    private var filteredClips: [Clip] {
        guard !activeTags.isEmpty else { return sectionClips }
        return sectionClips.filter { activeTags.isSubset(of: $0.tags) }
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

                // ── Section picker ────────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(ClipSection.allCases, id: \.self) { section in
                        Button { activeSection = section } label: {
                            Text(section.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(activeSection == section
                                    ? Color(red: 0.12, green: 0.10, blue: 0.08)
                                    : Color.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(activeSection == section
                                    ? Color(red: 1.0, green: 0.75, blue: 0.3)
                                    : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: activeSection)
                    }
                }
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.08))

                // ── Tag filter bar ────────────────────────────────────────
                if !clipStore.availableTags.isEmpty {
                    Text("FILTER BY TAG")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagFilterPill(label: "ALL", isActive: activeTags.isEmpty) {
                                activeTags = []
                            }
                            ForEach(clipStore.availableTags, id: \.self) { tag in
                                TagFilterPill(
                                    label: tag.uppercased(),
                                    isActive: activeTags.contains(tag)
                                ) {
                                    if activeTags.contains(tag) {
                                        activeTags.remove(tag)
                                    } else {
                                        activeTags.insert(tag)
                                    }
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
                        Image(systemName: activeSection == .audio ? "waveform.slash" : "text.page.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color.white.opacity(0.15))
                        Text(activeTags.isEmpty
                             ? (activeSection == .audio ? "No clips yet" : "No lyrics yet")
                             : "No \(activeSection == .audio ? "clips" : "lyrics") match selected tags")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredClips) { clip in
                                if clip.type == .lyric {
                                    LyricRow(
                                        clip: clip,
                                        onEdit:   { editingClip  = clip },
                                        onDelete: { deletingClip = clip }
                                    )
                                } else {
                                    ClipRow(
                                        clip: clip,
                                        onEdit:   { editingClip   = clip },
                                        onDelete: { deletingClip  = clip }
                                    )
                                    .environmentObject(clipStore)
                                }

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
        // Keep ClipStore's currentQueue in sync with audio clips visible.
        .onAppear { clipStore.currentQueue = activeSection == .audio ? filteredClips : [] }
        .onChange(of: activeTags)        { _, _ in clipStore.currentQueue = activeSection == .audio ? filteredClips : [] }
        .onChange(of: clipStore.clips)   { _, _ in clipStore.currentQueue = activeSection == .audio ? filteredClips : [] }
        .onChange(of: activeSection)     { _, _ in clipStore.currentQueue = activeSection == .audio ? filteredClips : [] }
        // Edit sheet
        .sheet(item: $editingClip) { clip in
            if clip.type == .lyric {
                LyricEditSheet(clip: clip, availableTags: clipStore.availableTags) { text, description, tags, newTags in
                    Task { await clipStore.updateLyric(clip, text: text, description: description, tags: tags, newAvailableTags: newTags) }
                }
            } else {
                ClipNameSheet(
                    title: "EDIT CLIP",
                    initialValue: clip.description ?? "",
                    availableTags: clipStore.availableTags,
                    initialTags: clip.tags
                ) { description, tags, newTags in
                    Task { await clipStore.renameClip(clip, description: description, tags: tags, newAvailableTags: newTags) }
                }
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
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(clip.formattedDay)
                        .font(.system(size: clip.description == nil ? 19 : 15, design: .monospaced))
                        .foregroundColor(clip.description == nil ? .white : Color.white.opacity(0.68))
                    Text(clip.formattedTime)
                        .font(.system(size: clip.description == nil ? 19 : 15, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.65))
                }

                // Tags
                if !clip.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(clip.tags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
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
                        .foregroundColor(Color.white.opacity(0.60))
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

// MARK: - Lyric row

struct LyricRow: View {
    let clip: Clip
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.3)

    private var previewLine: String? {
        clip.lyricContent?
            .components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let desc = clip.description {
                    Text(desc)
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                if let preview = previewLine {
                    Text(preview)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(clip.formattedDay)
                        .font(.system(size: clip.description == nil ? 19 : 15, design: .monospaced))
                        .foregroundColor(clip.description == nil ? .white : Color.white.opacity(0.68))
                    Text(clip.formattedTime)
                        .font(.system(size: clip.description == nil ? 19 : 15, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                if !clip.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(clip.tags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(amber.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(amber.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.60))
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

// MARK: - Lyric content viewer

struct LyricContentView: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let bg    = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LYRICS")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(amber)
                            .tracking(5)
                        if let desc = clip.description {
                            Text(desc)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.68))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    Text(clip.lyricContent ?? "")
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Button {
                    UIPasteboard.general.string = clip.lyricContent
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("COPY")
                            .tracking(2)
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(amber)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(amber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(amber.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Lyric edit sheet

struct LyricEditSheet: View {
    let clip: Clip
    let availableTags: [String]
    let onSave: (String, String?, [String], [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var description: String
    @State private var selectedTags: Set<String>
    @State private var localTags: [String]
    @State private var brandNewTags: [String] = []
    @State private var newTagText = ""
    @FocusState private var tagFieldFocused: Bool

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let bg    = Color(red: 0.12, green: 0.10, blue: 0.08)

    init(clip: Clip, availableTags: [String], onSave: @escaping (String, String?, [String], [String]) -> Void) {
        self.clip          = clip
        self.availableTags = availableTags
        self.onSave        = onSave
        _text              = State(initialValue: clip.lyricContent ?? "")
        _description       = State(initialValue: clip.description ?? "")
        _selectedTags      = State(initialValue: Set(clip.tags))
        _localTags         = State(initialValue: availableTags)
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Header ─────────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.68))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("EDIT LYRIC")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(amber)
                        .tracking(3)
                    Spacer()
                    Button { commit() } label: {
                        Text("SAVE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(amber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(amber.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 8)
                .padding(.top, 16)

                Divider().background(Color.white.opacity(0.08)).padding(.top, 8)

                // ── Text editor ────────────────────────────────────────────
                TextEditor(text: $text)
                    .font(.system(size: 17, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tint(amber)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxHeight: .infinity)

                Divider().background(Color.white.opacity(0.08))

                // ── Title + tags (scrollable) ──────────────────────────────
                ScrollView {
                    VStack(spacing: 20) {

                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TITLE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .tracking(2)
                            TextField("", text: $description, prompt:
                                Text("name this lyric...")
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.2))
                            )
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.white)
                            .tint(amber)
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 20)

                        // Tags
                        if !localTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TAGS")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(localTags, id: \.self) { tag in
                                        let on = selectedTags.contains(tag)
                                        Button {
                                            if on { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                        } label: {
                                            Text(tag)
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundColor(on ? Color(red: 0.12, green: 0.10, blue: 0.08) : .white.opacity(0.80))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .frame(maxWidth: .infinity)
                                                .background(on ? amber : Color.white.opacity(0.07))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .animation(.easeInOut(duration: 0.12), value: on)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // New tag row
                        HStack(spacing: 8) {
                            TextField("", text: $newTagText, prompt:
                                Text("new tag...")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.2))
                            )
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .tint(amber)
                            .focused($tagFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { commitNewTag() }
                            Button { commitNewTag() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(newTagText.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.15) : amber)
                            }
                            .buttonStyle(.plain)
                            .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tagFieldFocused ? amber.opacity(0.4) : Color.clear, lineWidth: 1))
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                }
                .frame(maxHeight: 260)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func commitNewTag() {
        let s = newTagText.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        newTagText = ""
        guard !s.isEmpty, !localTags.contains(s) else { return }
        localTags.append(s)
        selectedTags.insert(s)
        brandNewTags.append(s)
    }

    private func commit() {
        let desc = description.trimmingCharacters(in: .whitespaces)
        dismiss()
        onSave(text, desc.isEmpty ? nil : desc, Array(selectedTags), brandNewTags)
    }
}

#Preview {
    ClipsView().environmentObject(ClipStore())
}
