import Foundation

/// Row in `practice_sessions` (day + focus flags).
struct PracticeSession: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let sessionDate: String
    let practicedRange: Bool
    let practicedChipping: Bool
    let practicedPutting: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionDate = "session_date"
        case practicedRange = "practiced_range"
        case practicedChipping = "practiced_chipping"
        case practicedPutting = "practiced_putting"
        case createdAt = "created_at"
    }
}

struct PracticeSessionInsert: Encodable {
    let userId: UUID
    let sessionDate: String
    let practicedRange: Bool
    let practicedChipping: Bool
    let practicedPutting: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionDate = "session_date"
        case practicedRange = "practiced_range"
        case practicedChipping = "practiced_chipping"
        case practicedPutting = "practiced_putting"
    }
}

extension PracticeSession {
    var focusSubtitle: String {
        var bits: [String] = []
        if practicedRange { bits.append("Range") }
        if practicedChipping { bits.append("Chipping") }
        if practicedPutting { bits.append("Putting") }
        return bits.joined(separator: " · ")
    }

    /// Newest session date first; ties broken by `createdAt`, then `id` (matches Supabase list ordering).
    static func sortedForDisplay(_ rows: [PracticeSession]) -> [PracticeSession] {
        rows.sorted { lhs, rhs in
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
}
