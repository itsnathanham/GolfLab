import SwiftUI
import WidgetKit

@main
struct GolfLabWatchApp: App {
    @StateObject private var watchSession = WatchSessionService.shared

    init() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(watchSession)
        }
    }
}
