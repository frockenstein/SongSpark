import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dropboxManager: DropboxManager
    @EnvironmentObject var clipStore: ClipStore
    @Environment(\.dismiss) private var dismiss

    @State private var showUnlinkConfirm = false
    @State private var newTagText = ""
    @FocusState private var tagFieldFocused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
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

                ScrollView {
                    VStack(spacing: 24) {
                        dropboxSection
                        tagsSection
                    }
                    .padding(20)
                }
            }
        }
        .confirmationDialog("Unlink Dropbox?", isPresented: $showUnlinkConfirm, titleVisibility: .visible) {
            Button("Unlink", role: .destructive) { dropboxManager.unlink() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("New recordings won't be saved until you reconnect.")
        }
    }

    // MARK: - Dropbox section

    private var dropboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DROPBOX")

            VStack(spacing: 0) {
                if dropboxManager.isAuthorized {
                    if let name = dropboxManager.accountName {
                        settingsRow(label: "Account", value: name)
                        rowDivider()
                    }
                    if let email = dropboxManager.accountEmail {
                        settingsRow(label: "Email", value: email)
                        rowDivider()
                    }
                    settingsRow(label: "Saving to", value: dropboxManager.folderPath)
                    rowDivider()

                    Button { showUnlinkConfirm = true } label: {
                        HStack {
                            Text("Unlink Dropbox")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not connected")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Recordings won't be saved without Dropbox.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    rowDivider()

                    Button { dropboxManager.startAuth() } label: {
                        HStack {
                            Text("Connect Dropbox")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .settingsCard()
        }
    }

    // MARK: - Tags section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TAGS")

            VStack(spacing: 0) {
                if clipStore.availableTags.isEmpty {
                    HStack {
                        Text("No tags yet")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    rowDivider()
                } else {
                    ForEach(clipStore.availableTags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                Task { await clipStore.removeTag(tag) }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        rowDivider()
                    }
                }

                // Add tag row
                HStack(spacing: 10) {
                    TextField("", text: $newTagText, prompt:
                        Text("new tag...")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.25))
                    )
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .tint(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .submitLabel(.done)
                    .focused($tagFieldFocused)
                    .onSubmit { commitNewTag() }

                    Button { commitNewTag() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(
                                newTagText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.white.opacity(0.15)
                                    : Color(red: 1.0, green: 0.75, blue: 0.3)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .settingsCard()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
            .tracking(2)
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func rowDivider() -> some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 16)
    }

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        newTagText = ""
        tagFieldFocused = false
        Task { await clipStore.addTag(trimmed) }
    }
}

// MARK: - Card modifier

private extension View {
    func settingsCard() -> some View {
        self
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(DropboxManager())
        .environmentObject(ClipStore())
}
