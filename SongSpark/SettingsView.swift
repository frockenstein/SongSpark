import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dropboxManager: DropboxManager
    @Environment(\.dismiss) private var dismiss
    @State private var showUnlinkConfirm = false

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                        .tracking(4)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.08))

                ScrollView {
                    VStack(spacing: 24) {
                        dropboxSection
                    }
                    .padding(20)
                }
            }
        }
        .confirmationDialog("Unlink Dropbox?", isPresented: $showUnlinkConfirm, titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                dropboxManager.unlink()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("New recordings won't be saved until you reconnect.")
        }
    }

    // MARK: - Dropbox Section

    private var dropboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DROPBOX")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)

            VStack(spacing: 0) {
                if dropboxManager.isAuthorized {
                    // Account row
                    if let name = dropboxManager.accountName {
                        settingsRow(label: "Account", value: name)
                        rowDivider()
                    }
                    if let email = dropboxManager.accountEmail {
                        settingsRow(label: "Email", value: email)
                        rowDivider()
                    }

                    // Folder row
                    settingsRow(label: "Saving to", value: dropboxManager.folderPath)
                    rowDivider()

                    // Unlink button
                    Button {
                        showUnlinkConfirm = true
                    } label: {
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
                    // Not connected
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

                    Button {
                        dropboxManager.startAuth()
                    } label: {
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
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

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
}

#Preview {
    SettingsView()
        .environmentObject(DropboxManager())
}
