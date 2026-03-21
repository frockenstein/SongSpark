import SwiftUI

@main
struct SongSparkApp: App {
    @StateObject private var dropboxManager = DropboxManager()
    @StateObject private var clipStore = ClipStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(dropboxManager)
                    .environmentObject(clipStore)
                    .onOpenURL { url in
                        dropboxManager.handleAuthCallback(url: url)
                    }
                    .task {
                        if dropboxManager.isAuthorized {
                            await clipStore.loadClips()
                        }
                    }
                    .onChange(of: dropboxManager.isAuthorized) { _, authorized in
                        if authorized { Task { await clipStore.loadClips() } }
                    }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Hold for 1.8 s, then fade out over 0.6 s
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
    }
}
