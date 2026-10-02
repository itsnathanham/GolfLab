import Foundation

struct GolfLabDataExport: Codable {
    var profile: UserProfile?
    var rounds: [Round]
    var holes: [Hole]
    var practiceSessions: [PracticeSession]
}

enum SupabaseMigrator {
    @MainActor
    static func migrate() async throws {
        if MigrationState.isComplete, GolfLabData.store.hasLocalData { return }

        guard let service = SupabaseService.configured, let client = service.client else {
            throw DatabaseError.insertFailed("The old database isn’t configured on this install. Restore the Supabase project or import a JSON export.")
        }
        let userId: UUID
        do {
            userId = try await client.auth.session.user.id
        } catch {
            throw DatabaseError.insertFailed("Sign in with Apple to copy your existing rounds.")
        }

        let profile = try await service.fetchProfile(userId: userId)
        let rounds = try await service.fetchRounds(userId: userId)
        let practice = try await service.fetchAllPracticeSessions(userId: userId)
        var holes: [Hole] = []
        holes.reserveCapacity(rounds.count * 18)
        for round in rounds {
            holes.append(contentsOf: try await service.fetchHoles(roundId: round.id))
        }

        let snapshot = GolfLabDataExport(
            profile: profile ?? UserProfile(
                id: userId,
                displayName: nil,
                homeCourseName: nil,
                homeCourseTee: nil,
                preferredUnits: "yards",
                weeklyRoundTarget: 1,
                weeklyPracticeTarget: 2,
                weeklyGoalTargetRevisions: nil
            ),
            rounds: rounds,
            holes: holes,
            practiceSessions: practice
        )
        try GolfLabData.store.importSnapshot(snapshot)
        _ = try GolfLabData.store.ensureProfile(userId: userId)
        GolfLabUserID.save(userId)
        MigrationState.markComplete()
    }
}
