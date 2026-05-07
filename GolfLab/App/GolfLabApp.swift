import SwiftUI

@main
struct GolfLabApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var watchService = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    SplashView()
                } else if authService.isAuthenticated {
                    MainTabView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(authService)
            .environmentObject(watchService)
            .dynamicTypeSize(.medium ... .xxLarge)
            .task {
                await authService.checkSession()
            }
        }
    }
}
