import SwiftData
import SwiftUI

@main
struct GolfLabApp: App {
    @StateObject private var watchService = WatchConnectivityService.shared
    @StateObject private var session = GolfLabSession()
    @StateObject private var roundStore = RoundStore()

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
                        await session.retry(roundStore: roundStore)
                    }
                case .migrating:
                    MigrationProgressView(detail: session.migrationDetail)
                case .ready:
                    MainTabView()
                case .failed(let message):
                    MigrationFailedView(
                        message: message,
                        onRetry: { await session.retry(roundStore: roundStore) },
                        onImport: { data in
                            Task { await session.importFromFile(data, roundStore: roundStore) }
                        },
                        onContinueEmpty: { await session.continueWithoutImport(roundStore: roundStore) }
                    )
                }
            }
            .environmentObject(watchService)
            .environmentObject(roundStore)
            .environment(\.modelContext, container.mainContext)
            .dynamicTypeSize(.medium ... .xxLarge)
            .task {
                await session.start(roundStore: roundStore)
            }
        }
        .modelContainer(container)
    }
}
