import SwiftData
import SwiftUI

@main
struct GolfLabApp: App {
    @StateObject private var watchService = WatchConnectivityService.shared
    @StateObject private var session = GolfLabSession()

    private let container: ModelContainer

    init() {
        let container = GolfLabPersistence.makeContainer()
        SwiftDataGolfLabStore.shared.configure(container: container)
        self.container = container
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.phase {
                case .loading:
                    SplashView()
                case .needsICloud:
                    ICloudRequiredView(message: AccountService.shared.iCloudStatusMessage) {
                        await session.retry()
                    }
                case .migrating:
                    MigrationProgressView(detail: session.migrationDetail)
                case .ready:
                    MainTabView()
                case .failed(let message):
                    MigrationFailedView(
                        message: message,
                        onRetry: { await session.retry() },
                        onImport: { data in
                            Task { await session.importFromFile(data) }
                        },
                        onContinueEmpty: { await session.continueWithoutImport() }
                    )
                }
            }
            .environmentObject(watchService)
            .environment(\.modelContext, container.mainContext)
            .dynamicTypeSize(.medium ... .xxLarge)
            .task {
                await session.start()
            }
        }
        .modelContainer(container)
    }
}
