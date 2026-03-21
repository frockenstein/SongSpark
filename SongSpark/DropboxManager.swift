import Foundation
import SwiftyDropbox

// MARK: - Setup
// 1. Create a Dropbox app at https://www.dropbox.com/developers/apps
//    - Choose "Scoped access" → "App folder"
//    - Add permission: files.content.write
// 2. Replace DROPBOX_APP_KEY below with your app key
// 3. In Info.plist add URL scheme: db-<YOUR_APP_KEY>
// 4. In Dropbox app console, add OAuth redirect URI: db-<YOUR_APP_KEY>://2/token

private let dropboxAppKey = "DROPBOX_APP_KEY"

@MainActor
final class DropboxManager: ObservableObject {
    @Published var isAuthorized: Bool = false

    init() {
        DropboxClientsManager.setupWithAppKey(dropboxAppKey)
        isAuthorized = DropboxClientsManager.authorizedClient != nil
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
                    // Clean up temp file after successful upload
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
