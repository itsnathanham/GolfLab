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
}
