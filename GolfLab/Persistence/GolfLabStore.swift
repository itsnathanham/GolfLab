import Foundation
import SwiftData

@MainActor
protocol GolfLabStore: AnyObject {
    func fetchProfile(userId: UUID) async throws -> UserProfile?
    func updateProfile(
        userId: UUID,
        displayName: String?,
        homeCourseName: String?,
        homeCourseTee: String?,
        preferredUnits: String,
        weeklyRoundTarget: Int?,
        weeklyPracticeTarget: Int?,
        weeklyGoalTargetRevisions: [WeeklyGoalTargetRevision]?,
        stockClubYardages: [StockClubYardage]?
    ) async throws -> UserProfile
    func ensureProfile(userId: UUID) throws -> UserProfile

    func insertRound(_ round: RoundInsert) async throws -> Round
    func fetchRounds(userId: UUID) async throws -> [Round]
    func updateRoundCourseName(roundId: UUID, courseName: String) async throws
    func updateRoundTotals(roundId: UUID, totalScore: Int, totalPutts: Int, totalGir: Int, totalFir: Int) async throws
    func deleteRound(id: UUID) async throws

    func fetchAllPracticeSessions(userId: UUID) async throws -> [PracticeSession]
    func insertPracticeSession(_ insert: PracticeSessionInsert) async throws -> PracticeSession

    func insertHoles(_ holes: [HoleInsert]) async throws -> [Hole]
    func fetchHoles(roundId: UUID) async throws -> [Hole]
    func fetchHoleAggregatesByUser(userId: UUID) async throws -> HoleAggregates
    func updateHole(holeId: UUID, update: HoleUpdate) async throws

    func importSnapshot(_ snapshot: GolfLabDataExport) throws
    var hasLocalData: Bool { get }
    var storedProfileUserId: UUID? { get }
}

struct GolfLabDataExport: Codable {
    var profile: UserProfile?
    var rounds: [Round]
    var holes: [Hole]
    var practiceSessions: [PracticeSession]
}

enum DatabaseError: LocalizedError {
    case insertFailed(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .insertFailed(let msg): return "Insert failed: \(msg)"
        case .notFound: return "Record not found."
        }
    }
}

struct HoleAggregates {
    let rowCountByRound: [UUID: Int]
    let parSumByRound: [UUID: Int]
    /// One entry per persisted hole row (used for season-scoped par averages on Hole Entry).
    let holeParScoreSamples: [HoleParScoreSample]
}

struct HoleParScoreSample: Equatable, Sendable {
    let roundId: UUID
    let par: Int
    let score: Int
}

enum GolfLabData {
    @MainActor
    static var store: SwiftDataGolfLabStore { .shared }
}

@MainActor
final class SwiftDataGolfLabStore: GolfLabStore {
    static let shared = SwiftDataGolfLabStore()

    private var context: ModelContext?

    private init() {}

    func configure(container: ModelContainer) {
        context = container.mainContext
        context?.autosaveEnabled = true
    }

    private func requireContext() throws -> ModelContext {
        guard let context else {
            throw DatabaseError.insertFailed("Persistence is not ready yet.")
        }
        return context
    }

    var hasLocalData: Bool {
        firstModel(SDProfile.self) != nil || firstModel(SDRound.self) != nil
    }

    var storedProfileUserId: UUID? {
        firstModel(SDProfile.self)?.id ?? firstModel(SDRound.self)?.userId
    }

    func fetchProfile(userId: UUID) async throws -> UserProfile? {
        guard let profile = try findProfile(userId: userId) else { return nil }
        return profile.asUserProfile()
    }

    func ensureProfile(userId: UUID) throws -> UserProfile {
        if let existing = try findProfile(userId: userId) {
            return existing.asUserProfile()
        }
        let context = try requireContext()
        let profile = SDProfile(id: userId, preferredUnits: "yards", weeklyRoundTarget: 1, weeklyPracticeTarget: 2)
        context.insert(profile)
        try context.save()
        GolfLabUserID.save(userId)
        return profile.asUserProfile()
    }

    func updateProfile(
        userId: UUID,
        displayName: String?,
        homeCourseName: String?,
        homeCourseTee: String?,
        preferredUnits: String,
        weeklyRoundTarget: Int?,
        weeklyPracticeTarget: Int?,
        weeklyGoalTargetRevisions: [WeeklyGoalTargetRevision]?,
        stockClubYardages: [StockClubYardage]?
    ) async throws -> UserProfile {
        let context = try requireContext()
        let profile = try findProfile(userId: userId) ?? {
            let created = SDProfile(id: userId)
            context.insert(created)
            return created
        }()
        profile.displayName = displayName
        profile.homeCourseName = homeCourseName
        profile.homeCourseTee = homeCourseTee
        profile.preferredUnits = preferredUnits
        profile.weeklyRoundTarget = weeklyRoundTarget
        profile.weeklyPracticeTarget = weeklyPracticeTarget
        if let weeklyGoalTargetRevisions {
            profile.weeklyGoalTargetRevisionsData = try JSONEncoder().encode(weeklyGoalTargetRevisions)
        }
        if let stockClubYardages {
            try replaceStockClubYardages(on: profile, userId: userId, rows: stockClubYardages)
        }
        try context.save()
        return profile.asUserProfile()
    }

    func insertRound(_ round: RoundInsert) async throws -> Round {
        let context = try requireContext()
        let now = GolfLabTimestamp.now()
        let model = SDRound(
            userId: round.userId,
            courseName: round.courseName,
            tee: round.tee,
            holesCount: round.holes,
            datePlayed: round.datePlayed,
            totalScore: round.totalScore,
            totalPutts: round.totalPutts,
            totalGir: round.totalGir,
            totalFir: round.totalFir,
            createdAt: now,
            updatedAt: now
        )
        context.insert(model)
        try context.save()
        return model.asRound()
    }

    func fetchRounds(userId: UUID) async throws -> [Round] {
        let context = try requireContext()
        let uid = userId
        let descriptor = FetchDescriptor<SDRound>(
            predicate: #Predicate { $0.userId == uid }
        )
        let response = try context.fetch(descriptor).map { $0.asRound() }
        return response.sorted { lhs, rhs in
            if lhs.datePlayed != rhs.datePlayed {
                return lhs.datePlayed > rhs.datePlayed
            }
            if let lc = lhs.createdAt, let rc = rhs.createdAt, lc != rc {
                return lc > rc
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    func updateRoundCourseName(roundId: UUID, courseName: String) async throws {
        let context = try requireContext()
        guard let round = try findRound(id: roundId) else {
            throw DatabaseError.notFound
        }
        round.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        round.updatedAt = GolfLabTimestamp.now()
        try context.save()
    }

    func updateRoundTotals(roundId: UUID, totalScore: Int, totalPutts: Int, totalGir: Int, totalFir: Int) async throws {
        let context = try requireContext()
        guard let round = try findRound(id: roundId) else {
            throw DatabaseError.notFound
        }
        round.totalScore = totalScore
        round.totalPutts = totalPutts
        round.totalGir = totalGir
        round.totalFir = totalFir
        round.updatedAt = GolfLabTimestamp.now()
        try context.save()
    }

    func deleteRound(id: UUID) async throws {
        let context = try requireContext()
        guard let round = try findRound(id: id) else { return }
        context.delete(round)
        try context.save()
    }

    func fetchAllPracticeSessions(userId: UUID) async throws -> [PracticeSession] {
        let context = try requireContext()
        let uid = userId
        let descriptor = FetchDescriptor<SDPracticeSession>(
            predicate: #Predicate { $0.userId == uid }
        )
        let rows = try context.fetch(descriptor).map { $0.asPracticeSession() }
        return PracticeSession.sortedForDisplay(rows)
    }

    func insertPracticeSession(_ insert: PracticeSessionInsert) async throws -> PracticeSession {
        let context = try requireContext()
        let model = SDPracticeSession(
            userId: insert.userId,
            sessionDate: insert.sessionDate,
            practicedRange: insert.practicedRange,
            practicedChipping: insert.practicedChipping,
            practicedPutting: insert.practicedPutting,
            rangeBallsHit: insert.rangeBallsHit,
            createdAt: GolfLabTimestamp.now()
        )
        context.insert(model)
        try context.save()
        return model.asPracticeSession()
    }

    func insertHoles(_ holes: [HoleInsert]) async throws -> [Hole] {
        let context = try requireContext()
        let now = GolfLabTimestamp.now()
        var inserted: [Hole] = []
        for hole in holes {
            let model = SDHole(
                roundId: hole.roundId,
                userId: hole.userId,
                holeNumber: hole.holeNumber,
                par: hole.par,
                yardage: hole.yardage,
                strokeIndex: hole.strokeIndex,
                score: hole.score,
                putts: hole.putts,
                gir: hole.gir,
                fir: hole.fir,
                penalty: hole.penalty,
                createdAt: now,
                updatedAt: now
            )
            model.round = try findRound(id: hole.roundId)
            context.insert(model)
            inserted.append(model.asHole())
        }
        try context.save()
        return inserted
    }

    func fetchHoles(roundId: UUID) async throws -> [Hole] {
        let context = try requireContext()
        let rid = roundId
        let descriptor = FetchDescriptor<SDHole>(
            predicate: #Predicate { $0.roundId == rid },
            sortBy: [SortDescriptor(\.holeNumber, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.asHole() }
    }

    func fetchHoleAggregatesByUser(userId: UUID) async throws -> HoleAggregates {
        let context = try requireContext()
        let uid = userId
        let descriptor = FetchDescriptor<SDHole>(
            predicate: #Predicate { $0.userId == uid }
        )
        let rows = try context.fetch(descriptor)
        var counts: [UUID: Int] = [:]
        var parSums: [UUID: Int] = [:]
        var parScoreSamples: [HoleParScoreSample] = []
        parScoreSamples.reserveCapacity(rows.count)
        for row in rows {
            counts[row.roundId, default: 0] += 1
            parSums[row.roundId, default: 0] += row.par
            parScoreSamples.append(HoleParScoreSample(roundId: row.roundId, par: row.par, score: row.score))
        }
        return HoleAggregates(
            rowCountByRound: counts,
            parSumByRound: parSums,
            holeParScoreSamples: parScoreSamples
        )
    }

    func updateHole(holeId: UUID, update: HoleUpdate) async throws {
        let context = try requireContext()
        guard let hole = try findHole(id: holeId) else {
            throw DatabaseError.notFound
        }
        hole.score = update.score
        hole.putts = update.putts
        hole.gir = update.gir
        hole.fir = update.fir
        hole.penalty = update.penalty
        hole.updatedAt = GolfLabTimestamp.now()
        try context.save()
    }

    func importSnapshot(_ snapshot: GolfLabDataExport) throws {
        let context = try requireContext()
        if let profile = snapshot.profile {
            if try findProfile(userId: profile.id) == nil {
                let model = SDProfile.from(profile)
                context.insert(model)
                if let rows = profile.stockClubYardages {
                    try replaceStockClubYardages(on: model, userId: profile.id, rows: rows)
                }
            }
            GolfLabUserID.save(profile.id)
        }
        let holesByRound = Dictionary(grouping: snapshot.holes, by: \.roundId)
        for round in snapshot.rounds {
            if try findRound(id: round.id) == nil {
                let model = SDRound.from(round)
                context.insert(model)
                for hole in holesByRound[round.id] ?? [] {
                    if try findHole(id: hole.id) == nil {
                        let holeModel = SDHole.from(hole)
                        holeModel.round = model
                        context.insert(holeModel)
                    }
                }
            }
        }
        for session in snapshot.practiceSessions {
            if try findPractice(id: session.id) == nil {
                context.insert(SDPracticeSession.from(session))
            }
        }
        try context.save()
    }

    func exportSnapshot(userId: UUID) async throws -> GolfLabDataExport {
        let rounds = try await fetchRounds(userId: userId)
        var holes: [Hole] = []
        for round in rounds {
            holes.append(contentsOf: try await fetchHoles(roundId: round.id))
        }
        return GolfLabDataExport(
            profile: try await fetchProfile(userId: userId),
            rounds: rounds,
            holes: holes,
            practiceSessions: try await fetchAllPracticeSessions(userId: userId)
        )
    }

    private func firstModel<T: PersistentModel>(_ type: T.Type) -> T? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func findProfile(userId: UUID) throws -> SDProfile? {
        let context = try requireContext()
        let uid = userId
        var descriptor = FetchDescriptor<SDProfile>(
            predicate: #Predicate { $0.id == uid }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func findRound(id: UUID) throws -> SDRound? {
        let context = try requireContext()
        let rid = id
        var descriptor = FetchDescriptor<SDRound>(
            predicate: #Predicate { $0.id == rid }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func findHole(id: UUID) throws -> SDHole? {
        let context = try requireContext()
        let hid = id
        var descriptor = FetchDescriptor<SDHole>(
            predicate: #Predicate { $0.id == hid }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func findPractice(id: UUID) throws -> SDPracticeSession? {
        let context = try requireContext()
        let pid = id
        var descriptor = FetchDescriptor<SDPracticeSession>(
            predicate: #Predicate { $0.id == pid }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Replaces all stock-yardage rows for a profile (CloudKit-synced relationship).
    private func replaceStockClubYardages(
        on profile: SDProfile,
        userId: UUID,
        rows: [StockClubYardage]
    ) throws {
        let context = try requireContext()
        let existing = profile.stockClubYardages ?? []
        for row in existing {
            context.delete(row)
        }
        profile.stockClubYardages = []
        var inserted: [SDStockClubYardage] = []
        inserted.reserveCapacity(rows.count)
        for row in GLStockClubYardages.sorted(rows) {
            let model = SDStockClubYardage(
                id: row.id,
                userId: userId,
                clubRaw: row.club.rawValue,
                yardage: row.yardage,
                profile: profile
            )
            context.insert(model)
            inserted.append(model)
        }
        profile.stockClubYardages = inserted
        profile.hasConfiguredStockClubYardages = true
        // Clear legacy blob once relationship rows are the source of truth.
        profile.stockClubYardagesData = nil
    }
}

private extension SDProfile {
    func asUserProfile() -> UserProfile {
        let revisions: [WeeklyGoalTargetRevision]? = {
            guard let weeklyGoalTargetRevisionsData else { return nil }
            return try? JSONDecoder().decode([WeeklyGoalTargetRevision].self, from: weeklyGoalTargetRevisionsData)
        }()
        let stockYardages: [StockClubYardage]? = resolvedStockClubYardages()
        return UserProfile(
            id: id,
            displayName: displayName,
            homeCourseName: homeCourseName,
            homeCourseTee: homeCourseTee,
            preferredUnits: preferredUnits,
            weeklyRoundTarget: weeklyRoundTarget,
            weeklyPracticeTarget: weeklyPracticeTarget,
            weeklyGoalTargetRevisions: revisions,
            stockClubYardages: stockYardages
        )
    }

    /// Prefer relationship rows once configured; otherwise legacy JSON or nil (default template).
    func resolvedStockClubYardages() -> [StockClubYardage]? {
        let related = (stockClubYardages ?? []).compactMap { row -> StockClubYardage? in
            guard let club = StockClub(rawValue: row.clubRaw) else { return nil }
            return StockClubYardage(id: row.id, club: club, yardage: row.yardage)
        }
        if hasConfiguredStockClubYardages {
            return GLStockClubYardages.sorted(related)
        }
        if !related.isEmpty {
            return GLStockClubYardages.sorted(related)
        }
        guard let stockClubYardagesData,
              let decoded = try? JSONDecoder().decode([StockClubYardage].self, from: stockClubYardagesData)
        else {
            return nil
        }
        return GLStockClubYardages.sorted(decoded)
    }

    static func from(_ profile: UserProfile) -> SDProfile {
        let revisionsData: Data? = {
            guard let weeklyGoalTargetRevisions = profile.weeklyGoalTargetRevisions else { return nil }
            return try? JSONEncoder().encode(weeklyGoalTargetRevisions)
        }()
        // Relationship rows are attached by `replaceStockClubYardages` after insert.
        return SDProfile(
            id: profile.id,
            displayName: profile.displayName,
            homeCourseName: profile.homeCourseName,
            homeCourseTee: profile.homeCourseTee,
            preferredUnits: profile.preferredUnits,
            weeklyRoundTarget: profile.weeklyRoundTarget,
            weeklyPracticeTarget: profile.weeklyPracticeTarget,
            weeklyGoalTargetRevisionsData: revisionsData,
            stockClubYardagesData: nil,
            hasConfiguredStockClubYardages: profile.stockClubYardages != nil
        )
    }
}

private extension SDRound {
    func asRound() -> Round {
        Round(
            id: id,
            userId: userId,
            courseName: courseName,
            tee: tee,
            holes: holesCount,
            datePlayed: datePlayed,
            totalScore: totalScore,
            totalPutts: totalPutts,
            totalGir: totalGir,
            totalFir: totalFir,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func from(_ round: Round) -> SDRound {
        SDRound(
            id: round.id,
            userId: round.userId,
            courseName: round.courseName,
            tee: round.tee,
            holesCount: round.holes,
            datePlayed: round.datePlayed,
            totalScore: round.totalScore,
            totalPutts: round.totalPutts,
            totalGir: round.totalGir,
            totalFir: round.totalFir,
            createdAt: round.createdAt,
            updatedAt: round.updatedAt
        )
    }
}

private extension SDHole {
    func asHole() -> Hole {
        Hole(
            id: id,
            roundId: roundId,
            userId: userId,
            holeNumber: holeNumber,
            par: par,
            yardage: yardage,
            strokeIndex: strokeIndex,
            score: score,
            putts: putts,
            gir: gir,
            fir: fir,
            penalty: penalty,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func from(_ hole: Hole) -> SDHole {
        SDHole(
            id: hole.id,
            roundId: hole.roundId,
            userId: hole.userId,
            holeNumber: hole.holeNumber,
            par: hole.par,
            yardage: hole.yardage,
            strokeIndex: hole.strokeIndex,
            score: hole.score,
            putts: hole.putts,
            gir: hole.gir,
            fir: hole.fir,
            penalty: hole.penalty,
            createdAt: hole.createdAt,
            updatedAt: hole.updatedAt
        )
    }
}

private extension SDPracticeSession {
    func asPracticeSession() -> PracticeSession {
        PracticeSession(
            id: id,
            userId: userId,
            sessionDate: sessionDate,
            practicedRange: practicedRange,
            practicedChipping: practicedChipping,
            practicedPutting: practicedPutting,
            rangeBallsHit: rangeBallsHit,
            createdAt: createdAt
        )
    }

    static func from(_ session: PracticeSession) -> SDPracticeSession {
        SDPracticeSession(
            id: session.id,
            userId: session.userId,
            sessionDate: session.sessionDate,
            practicedRange: session.practicedRange,
            practicedChipping: session.practicedChipping,
            practicedPutting: session.practicedPutting,
            rangeBallsHit: session.rangeBallsHit,
            createdAt: session.createdAt
        )
    }
}

enum GolfLabPersistence {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            SDProfile.self,
            SDStockClubYardage.self,
            SDRound.self,
            SDHole.self,
            SDPracticeSession.self
        ])
        let cloud = ModelConfiguration(
            "GolfLab",
            schema: schema,
            cloudKitDatabase: .private(GolfLabCloud.containerIdentifier)
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloud])
        } catch {
            let local = ModelConfiguration(
                "GolfLabLocal",
                schema: schema,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Could not create Golf Lab persistence: \(error)")
            }
        }
    }
}
