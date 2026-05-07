import SwiftUI

@main
struct GolfLabWatchApp: App {
    @StateObject private var watchSession = WatchSessionService.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(watchSession)
        }
    }
}
