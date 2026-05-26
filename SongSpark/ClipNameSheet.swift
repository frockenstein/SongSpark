import SwiftUI

struct ClipNameSheet: View {
    let title: String
    let availableTags: [String]
    let onCancel: (() -> Void)?
    // (description, selectedTags, brandNewTags)
    // brandNewTags = tags the user created here that don't exist in availableTags yet
    let onSave: (String?, [String], [String]) -> Void

    @State private var text: String
    @State private var selectedTags: Set<String>
    @State private var localTags: [String]       // availableTags + any created this session
    @State private var brandNewTags: [String] = []
    @State private var newTagText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @FocusState private var tagFieldFocused: Bool

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.3)

    init(
        title: String = "NAME THIS CLIP",
        initialValue: String = "",
        availableTags: [String] = [],
        initialTags: [String] = [],
        onCancel: (() -> Void)? = nil,
        onSave: @escaping (String?, [String], [String]) -> Void
    ) {
        self.title         = title
        self.availableTags = availableTags
        self.onCancel      = onCancel
        self.onSave        = onSave
        _text              = State(initialValue: initialValue)
        _selectedTags      = State(initialValue: Set(initialTags))
        _localTags         = State(initialValue: availableTags)
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.07).ignoresSafeArea()

            ScrollView {
              VStack(spacing: 24) {

                // Sheet header
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(amber)
                    .tracking(3)

                // ── TITLE field ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("TITLE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                        .padding(.leading, 32)

                    VStack(spacing: 6) {
                        TextField("", text: $text, prompt: Text("name this idea...")
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.2))
                        )
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white)
                        .tint(amber)
                        .multilineTextAlignment(.center)
                        .focused($titleFocused)
                        // Dismiss keyboard only — do NOT call commit() here.
                        // Pressing Done before selecting tags would save with empty tags.
                        .onSubmit { titleFocused = false }
                        .submitLabel(.continue)

                        Rectangle()
                            .fill(titleFocused
                                ? amber.opacity(0.6)
                                : Color.white.opacity(0.15))
                            .frame(height: 1)
                            .animation(.easeInOut(duration: 0.15), value: titleFocused)
                    }
                    .padding(.horizontal, 32)
                }

                // ── TAGS ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                        .padding(.leading, 32)

                    // Existing + newly created tags
                    if !localTags.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(localTags, id: \.self) { tag in
                                let on = selectedTags.contains(tag)
                                Button {
                                    if on { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                } label: {
                                    Text(tag)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(on
                                            ? Color(red: 0.12, green: 0.10, blue: 0.08)
                                            : Color.white.opacity(0.6))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity)
                                        .background(on ? amber : Color.white.opacity(0.07))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().strokeBorder(
                                                on ? Color.clear : Color.white.opacity(0.12),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.12), value: on)
                            }
                        }
                        .padding(.horizontal, 32)
                    }

                    // New tag input row
                    HStack(spacing: 8) {
                        TextField("", text: $newTagText, prompt: Text("new tag...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.2))
                        )
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white)
                        .tint(amber)
                        .focused($tagFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { commitNewTag() }
                        .submitLabel(.done)

                        Button { commitNewTag() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(
                                    newTagText.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.white.opacity(0.15)
                                        : amber
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .animation(.easeInOut(duration: 0.12), value: newTagText.isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                tagFieldFocused ? amber.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: tagFieldFocused)
                    .padding(.horizontal, 32)
                }

                // ── Buttons ──────────────────────────────────────────────
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                        if let onCancel {
                            onCancel()
                        } else {
                            onSave(nil, [], [])
                        }
                    } label: {
                        Text(onCancel != nil ? "CANCEL" : "SKIP")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button { commit() } label: {
                        Text("SAVE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.08))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(amber)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 32)
              }
              .padding(.vertical, 36)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func commitNewTag() {
        // Sanitize: lowercase, spaces → hyphens, alphanumeric + - _  only
        let sanitized = newTagText
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        newTagText = ""
        guard !sanitized.isEmpty, !localTags.contains(sanitized) else { return }
        localTags.append(sanitized)
        selectedTags.insert(sanitized)
        brandNewTags.append(sanitized)
    }

    private func commit() {
        // Snapshot State values before dismiss() so SwiftUI teardown
        // can't affect them before onSave receives them.
        let trimmed  = text.trimmingCharacters(in: .whitespaces)
        let tags     = Array(selectedTags)
        let newTags  = brandNewTags
        print("[ClipNameSheet] commit: title='\(trimmed)' selectedTags=\(tags) brandNewTags=\(newTags)")
        dismiss()
        onSave(trimmed.isEmpty ? nil : trimmed, tags, newTags)
    }
}

#Preview {
    ClipNameSheet(availableTags: ["melodic", "slow", "acoustic", "lyrics"]) { _, _, _ in }
}
