import SwiftUI

struct ClipNameSheet: View {
    let title: String
    let availableTags: [String]
    let onSave: (String?, [String]) -> Void   // (description, selectedTags)

    @State private var text: String
    @State private var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(
        title: String = "NAME THIS CLIP",
        initialValue: String = "",
        availableTags: [String] = [],
        initialTags: [String] = [],
        onSave: @escaping (String?, [String]) -> Void
    ) {
        self.title         = title
        self.availableTags = availableTags
        self.onSave        = onSave
        _text              = State(initialValue: initialValue)
        _selectedTags      = State(initialValue: Set(initialTags))
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .tracking(3)

                // Description field
                VStack(spacing: 6) {
                    TextField("", text: $text, prompt: Text("add a description...")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.2))
                    )
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.white)
                    .tint(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .onSubmit { commit() }
                    .submitLabel(.done)

                    Rectangle()
                        .fill(focused
                            ? Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.6)
                            : Color.white.opacity(0.15))
                        .frame(height: 1)
                        .animation(.easeInOut(duration: 0.15), value: focused)
                }
                .padding(.horizontal, 32)

                // Tag picker
                if !availableTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(2)
                            .padding(.leading, 32)

                        // Adaptive grid so tags wrap naturally
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(availableTags, id: \.self) { tag in
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
                                        .background(on
                                            ? Color(red: 1.0, green: 0.75, blue: 0.3)
                                            : Color.white.opacity(0.07))
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
                }

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                        onSave(nil, [])
                    } label: {
                        Text("SKIP")
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
                            .background(Color(red: 1.0, green: 0.75, blue: 0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 36)
        }
        .presentationDetents([availableTags.isEmpty ? .height(240) : .height(370)])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        dismiss()
        onSave(trimmed.isEmpty ? nil : trimmed, Array(selectedTags))
    }
}

#Preview {
    ClipNameSheet(availableTags: ["melodic", "slow", "acoustic", "lyrics"]) { _, _ in }
}
