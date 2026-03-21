import SwiftUI

@main
struct SongSparkApp: App {
    @StateObject private var dropboxManager = DropboxManager()
    @StateObject private var clipStore = ClipStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dropboxManager)
                .environmentObject(clipStore)
                .onOpenURL { url in
                    dropboxManager.handleAuthCallback(url: url)
                }
                .onChange(of: dropboxManager.isAuthorized) { _, authorized in
                    if authorized {
                        Task { await clipStore.loadClips() }
                    }
                }
        }
    }
}
