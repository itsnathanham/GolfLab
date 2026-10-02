import CloudKit
import Combine
import Foundation

enum GolfLabUserID {
    private static let localKey = "golflab.userId"
    private static let ubiquityKey = "golflab.userId"

    static func load() -> UUID? {
        if let raw = NSUbiquitousKeyValueStore.default.string(forKey: ubiquityKey),
           let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = UserDefaults.standard.string(forKey: localKey),
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    static func save(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: localKey)
        NSUbiquitousKeyValueStore.default.set(id.uuidString, forKey: ubiquityKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

enum MigrationState {
    private static let localKey = "golflab.didMigrateFromSupabase"
    private static let ubiquityKey = "golflab.didMigrateFromSupabase"

    static var isComplete: Bool {
        NSUbiquitousKeyValueStore.default.bool(forKey: ubiquityKey)
            || UserDefaults.standard.bool(forKey: localKey)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: localKey)
        NSUbiquitousKeyValueStore.default.set(true, forKey: ubiquityKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

@MainActor
final class AccountService: ObservableObject {
    static let shared = AccountService()

    @Published var iCloudAvailable = false
    @Published var iCloudStatusMessage: String?

    private init() {}

    var currentUserId: UUID? {
        GolfLabUserID.load() ?? GolfLabData.store.storedProfileUserId
    }

    func refreshICloudStatus() async {
        do {
            let status = try await CKContainer(identifier: GolfLabCloud.containerIdentifier).accountStatus()
            switch status {
            case .available:
                iCloudAvailable = true
                iCloudStatusMessage = nil
            case .noAccount:
                iCloudAvailable = false
                iCloudStatusMessage = "Sign in to iCloud in Settings to keep Golf Lab synced."
            case .restricted:
                iCloudAvailable = false
                iCloudStatusMessage = "iCloud is restricted on this device."
            case .temporarilyUnavailable:
                iCloudAvailable = false
                iCloudStatusMessage = "iCloud is temporarily unavailable. Try again in a moment."
            case .couldNotDetermine:
                iCloudAvailable = false
                iCloudStatusMessage = "Couldn’t determine iCloud status. Try again."
            @unknown default:
                iCloudAvailable = false
                iCloudStatusMessage = "iCloud is unavailable."
            }
        } catch {
            iCloudAvailable = false
            iCloudStatusMessage = error.localizedDescription
        }
    }
}

@MainActor
final class GolfLabSession: ObservableObject {
    enum Phase: Equatable {
        case loading
        case needsICloud
        case needsAppleSignIn
        case migrating
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .loading
    @Published var migrationDetail = "Copying your rounds from the old servers…"

    func start() async {
        NSUbiquitousKeyValueStore.default.synchronize()
        await AccountService.shared.refreshICloudStatus()
        guard AccountService.shared.iCloudAvailable else {
            phase = .needsICloud
            return
        }

        if MigrationState.isComplete || GolfLabData.store.hasLocalData {
            adoptExistingStore()
            phase = .ready
            return
        }

        migrationDetail = "Checking iCloud for existing Golf Lab data…"
        phase = .migrating
        if await waitForCloudKitData() {
            adoptExistingStore()
            phase = .ready
            return
        }

        await AuthService.shared.checkSession()
        if AuthService.shared.isAuthenticated {
            await runMigration()
        } else {
            phase = .needsAppleSignIn
        }
    }

    func handleSignedIn() async {
        guard phase == .needsAppleSignIn || isFailed else { return }
        await runMigration()
    }

    func retry() async {
        await start()
    }

    func continueWithoutImport() async {
        let userId = GolfLabUserID.load() ?? UUID()
        GolfLabUserID.save(userId)
        _ = try? GolfLabData.store.ensureProfile(userId: userId)
        MigrationState.markComplete()
        phase = .ready
    }

    func importFromFile(_ data: Data) async {
        phase = .migrating
        migrationDetail = "Importing your exported Golf Lab data…"
        do {
            let snapshot = try JSONDecoder().decode(GolfLabDataExport.self, from: data)
            try GolfLabData.store.importSnapshot(snapshot)
            if let id = snapshot.profile?.id ?? snapshot.rounds.first?.userId {
                GolfLabUserID.save(id)
                _ = try GolfLabData.store.ensureProfile(userId: id)
            }
            MigrationState.markComplete()
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func adoptExistingStore() {
        if let id = AccountService.shared.currentUserId {
            GolfLabUserID.save(id)
        }
        MigrationState.markComplete()
    }

    private func waitForCloudKitData() async -> Bool {
        for _ in 0..<16 {
            if GolfLabData.store.hasLocalData { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return GolfLabData.store.hasLocalData
    }

    private func runMigration() async {
        phase = .migrating
        migrationDetail = "Copying your rounds from the old servers…"
        do {
            try await SupabaseMigrator.migrate()
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
