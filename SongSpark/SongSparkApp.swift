import SwiftUI

@main
struct SongSparkApp: App {
    @StateObject private var dropboxManager = DropboxManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dropboxManager)
                .onOpenURL { url in
                    dropboxManager.handleAuthCallback(url: url)
                }
        }
    }
}
