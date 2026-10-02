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
    /// Kept for installs that already completed the Supabase → iCloud copy.
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
        case migrating
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .loading
    @Published var migrationDetail = "Checking iCloud for existing Golf Lab data…"

    func start(roundStore: RoundStore) async {
        NSUbiquitousKeyValueStore.default.synchronize()
        await AccountService.shared.refreshICloudStatus()
        guard AccountService.shared.iCloudAvailable else {
            phase = .needsICloud
            return
        }

        if let userId = AccountService.shared.currentUserId, MigrationState.isComplete {
            GolfLabUserID.save(userId)
            _ = try? GolfLabData.store.ensureProfile(userId: userId)
            await finishReady(roundStore: roundStore)
            return
        }

        if GolfLabData.store.hasLocalData {
            adoptExistingStore()
            await finishReady(roundStore: roundStore)
            return
        }

        migrationDetail = "Checking iCloud for existing Golf Lab data…"
        phase = .migrating
        if await waitForCloudKitData() {
            adoptExistingStore()
            await finishReady(roundStore: roundStore)
            return
        }

        phase = .failed("Golf Lab didn’t find rounds in iCloud yet. Wait a moment and try again, or import a JSON backup.")
    }

    func retry(roundStore: RoundStore) async {
        phase = .loading
        await start(roundStore: roundStore)
    }

    func continueWithoutImport(roundStore: RoundStore) async {
        let userId = GolfLabUserID.load() ?? UUID()
        GolfLabUserID.save(userId)
        _ = try? GolfLabData.store.ensureProfile(userId: userId)
        MigrationState.markComplete()
        await finishReady(roundStore: roundStore)
    }

    func importFromFile(_ data: Data, roundStore: RoundStore) async {
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
            await finishReady(roundStore: roundStore)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func finishReady(roundStore: RoundStore) async {
        await roundStore.hydrateForLaunch()
        phase = .ready
    }

    private func adoptExistingStore() {
        if let id = AccountService.shared.currentUserId {
            GolfLabUserID.save(id)
            _ = try? GolfLabData.store.ensureProfile(userId: id)
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
}
