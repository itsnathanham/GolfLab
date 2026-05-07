import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - User Profile

    func upsertProfile(_ profile: UserProfile) async throws {
        try await client
            .from("users")
            .upsert(profile)
            .execute()
    }

    func fetchProfile(userId: UUID) async throws -> UserProfile? {
        let response: [UserProfile] = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    func updateProfile(userId: UUID, displayName: String?, homeCourseName: String?, homeCourseTee: String?, preferredUnits: String) async throws {
        struct ProfileUpdate: Encodable {
            let displayName: String?
            let homeCourseName: String?
            let homeCourseTee: String?
            let preferredUnits: String
            enum CodingKeys: String, CodingKey {
                case displayName    = "display_name"
                case homeCourseName = "home_course_name"
                case homeCourseTee  = "home_course_tee"
                case preferredUnits = "preferred_units"
            }
        }
        let update = ProfileUpdate(
            displayName: displayName,
            homeCourseName: homeCourseName,
            homeCourseTee: homeCourseTee,
            preferredUnits: preferredUnits
        )
        try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Rounds

    func insertRound(_ round: RoundInsert) async throws -> Round {
        let response: [Round] = try await client
            .from("rounds")
            .insert(round)
            .select()
            .execute()
            .value
        guard let inserted = response.first else {
            throw DatabaseError.insertFailed("Round insert returned no data")
        }
        return inserted
    }

    func fetchRounds(userId: UUID) async throws -> [Round] {
        let response: [Round] = try await client
            .from("rounds")
            .select()
            .eq("user_id", value: userId)
            .order("date_played", ascending: false)
            .execute()
            .value
        // Same calendar day has ambiguous DB order; break ties so "last round" is the most recently created.
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

    func fetchRound(id: UUID) async throws -> Round? {
        let response: [Round] = try await client
            .from("rounds")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    func updateRoundCourseName(roundId: UUID, courseName: String) async throws {
        struct CourseNameUpdate: Encodable {
            let courseName: String
            enum CodingKeys: String, CodingKey {
                case courseName = "course_name"
            }
        }
        let trimmed = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client
            .from("rounds")
            .update(CourseNameUpdate(courseName: trimmed))
            .eq("id", value: roundId)
            .execute()
    }

    func updateRoundTotals(roundId: UUID, totalScore: Int, totalPutts: Int, totalGir: Int, totalFir: Int) async throws {
        struct TotalsUpdate: Encodable {
            let totalScore: Int
            let totalPutts: Int
            let totalGir: Int
            let totalFir: Int
            enum CodingKeys: String, CodingKey {
                case totalScore     = "total_score"
                case totalPutts     = "total_putts"
                case totalGir       = "total_gir"
                case totalFir       = "total_fir"
            }
        }
        let update = TotalsUpdate(
            totalScore: totalScore,
            totalPutts: totalPutts,
            totalGir: totalGir,
            totalFir: totalFir
        )
        try await client
            .from("rounds")
            .update(update)
            .eq("id", value: roundId)
            .execute()
    }

    func deleteRound(id: UUID) async throws {
        try await client
            .from("rounds")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Practice sessions

    func fetchPracticeSessions(userId: UUID, fromInclusiveYMD: String, toInclusiveYMD: String) async throws -> [PracticeSession] {
        let rows: [PracticeSession] = try await client
            .from("practice_sessions")
            .select()
            .eq("user_id", value: userId)
            .gte("session_date", value: fromInclusiveYMD)
            .lte("session_date", value: toInclusiveYMD)
            .order("session_date", ascending: false)
            .execute()
            .value
        return rows.sorted { lhs, rhs in
            if lhs.sessionDate != rhs.sessionDate {
                return lhs.sessionDate > rhs.sessionDate
            }
            let lc = lhs.createdAt ?? ""
            let rc = rhs.createdAt ?? ""
            if lc != rc {
                return lc > rc
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    func insertPracticeSession(_ insert: PracticeSessionInsert) async throws -> PracticeSession {
        let rows: [PracticeSession] = try await client
            .from("practice_sessions")
            .insert(insert)
            .select()
            .execute()
            .value
        guard let inserted = rows.first else {
            throw DatabaseError.insertFailed("Practice insert returned no data")
        }
        return inserted
    }

    // MARK: - Holes

    func insertHoles(_ holes: [HoleInsert]) async throws -> [Hole] {
        let response: [Hole] = try await client
            .from("holes")
            .insert(holes)
            .select()
            .execute()
            .value
        return response
    }

    func fetchHoles(roundId: UUID) async throws -> [Hole] {
        let response: [Hole] = try await client
            .from("holes")
            .select()
            .eq("round_id", value: roundId)
            .order("hole_number", ascending: true)
            .execute()
            .value
        return response
    }

    /// One query: `round_id`, `par`, and `score` for every hole row, aggregated client-side (counts, par sums, vs-par, par-type scoring).
    func fetchHoleAggregatesByUser(userId: UUID) async throws -> HoleAggregates {
        let rows: [HoleRoundParRow] = try await client
            .from("holes")
            .select("round_id, par, score")
            .eq("user_id", value: userId)
            .execute()
            .value
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
        try await client
            .from("holes")
            .update(update)
            .eq("id", value: holeId)
            .execute()
    }

    // MARK: - Stats helpers

    func fetchAllRoundsWithHoles(userId: UUID) async throws -> [(round: Round, holes: [Hole])] {
        let rounds = try await fetchRounds(userId: userId)
        var result: [(round: Round, holes: [Hole])] = []
        for round in rounds {
            let holes = try await fetchHoles(roundId: round.id)
            result.append((round: round, holes: holes))
        }
        return result
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

private struct HoleRoundParRow: Decodable {
    let roundId: UUID
    let par: Int
    let score: Int

    enum CodingKeys: String, CodingKey {
        case roundId = "round_id"
        case par
        case score
    }
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
