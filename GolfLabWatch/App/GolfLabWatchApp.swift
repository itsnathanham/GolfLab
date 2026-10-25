import SwiftUI
import WidgetKit

@main
struct GolfLabWatchApp: App {
    @StateObject private var watchSession = WatchSessionService.shared

    init() {
        // TODO: Remove this once green background is confirmed working on device
        // Temporary force reload to clear widget cache
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(watchSession)
        }
    }
}
