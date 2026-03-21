import Foundation
import UIKit
@preconcurrency import SwiftyDropbox

// MARK: - Setup
// 1. Create a Dropbox app at https://www.dropbox.com/developers/apps
//    - Choose "Scoped access" → "App folder"
//    - Add permission: files.content.write
// 2. Copy Config/Secrets.xcconfig.example → Config/Secrets.xcconfig
//    and set DROPBOX_APP_KEY = <your key>
// 3. Dropbox OAuth redirect URI in app console: db-<YOUR_APP_KEY>://2/token

private func loadDropboxAppKey() -> String {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "DropboxAppKey") as? String,
          !key.isEmpty, key != "your_app_key_here" else {
        fatalError("Missing Dropbox app key. Copy Config/Secrets.xcconfig.example → Config/Secrets.xcconfig and set DROPBOX_APP_KEY.")
    }
    return key
}

@MainActor
final class DropboxManager: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var accountName: String?
    @Published var accountEmail: String?

    // App folder scope always stores at Dropbox/Apps/<app-name>/
    let folderPath = "Dropbox / Apps / SongSpark"

    init() {
        DropboxClientsManager.setupWithAppKey(loadDropboxAppKey())
        if DropboxClientsManager.authorizedClient != nil {
            isAuthorized = true
            fetchAccountInfo()
        }
    }

    // MARK: - Auth

    func startAuth() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController
        else { return }

        let scopeRequest = ScopeRequest(
            scopeType: .user,
            scopes: ["files.content.write", "files.content.read"],
            includeGrantedScopes: false
        )
        DropboxClientsManager.authorizeFromControllerV2(
            UIApplication.shared,
            controller: rootViewController,
            loadingStatusDelegate: nil,
            openURL: { UIApplication.shared.open($0) },
            scopeRequest: scopeRequest
        )
    }

    func handleAuthCallback(url: URL) {
        let oauthCompletion: DropboxOAuthCompletion = { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success:
                    self.isAuthorized = DropboxClientsManager.authorizedClient != nil
                    self.fetchAccountInfo()
                case .cancel:
                    print("Dropbox auth cancelled")
                case .error(_, let description):
                    print("Dropbox auth error: \(description ?? "unknown")")
                case .none:
                    break
                }
            }
        }
        DropboxClientsManager.handleRedirectURL(url, includeBackgroundClient: false, completion: oauthCompletion)
    }

    func unlink() {
        DropboxClientsManager.unlinkClients()
        isAuthorized = false
        accountName = nil
        accountEmail = nil
    }

    // MARK: - Account

    func fetchAccountInfo() {
        guard let client = DropboxClientsManager.authorizedClient else { return }
        client.users.getCurrentAccount().response { [weak self] account, error in
            guard let self, let account else { return }
            Task { @MainActor in
                self.accountName = account.name.displayName
                self.accountEmail = account.email
            }
        }
    }

    // MARK: - Upload

    func upload(fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let client = DropboxClientsManager.authorizedClient else {
            completion(.failure(DropboxError.notAuthorized))
            return
        }

        let filename = fileURL.lastPathComponent
        let dropboxPath = "/\(filename)"

        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(DropboxError.fileReadFailed))
            return
        }

        client.files.upload(path: dropboxPath, input: fileData)
            .response { response, error in
                if let error {
                    completion(.failure(DropboxError.uploadFailed(error.description)))
                } else {
                    try? FileManager.default.removeItem(at: fileURL)
                    completion(.success(()))
                }
            }
            .progress { progressData in
                print("Upload progress: \(progressData.fractionCompleted * 100)%")
            }
    }
}

// MARK: - Errors

enum DropboxError: LocalizedError {
    case notAuthorized
    case fileReadFailed
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Not connected to Dropbox. Please connect first."
        case .fileReadFailed: return "Could not read the recorded audio file."
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        }
    }
}
