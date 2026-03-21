import SwiftUI

struct ClipNameSheet: View {
    let title: String
    let initialValue: String
    let onSave: (String?) -> Void   // nil = skip / clear description

    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(title: String = "NAME THIS CLIP", initialValue: String = "", onSave: @escaping (String?) -> Void) {
        self.title = title
        self.initialValue = initialValue
        self.onSave = onSave
        _text = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .tracking(3)

                // Text field
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

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                        onSave(nil)
                    } label: {
                        Text("SKIP")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        commit()
                    } label: {
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
            .padding(.vertical, 40)
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        dismiss()
        onSave(trimmed.isEmpty ? nil : trimmed)
    }
}

#Preview {
    ClipNameSheet { _ in }
}
