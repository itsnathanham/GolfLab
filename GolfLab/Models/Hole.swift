import Foundation

struct Hole: Codable, Identifiable {
    let id: UUID
    let roundId: UUID
    let userId: UUID
    var holeNumber: Int
    var par: Int
    var yardage: Int?
    var strokeIndex: Int?
    var score: Int
    var putts: Int
    var gir: Bool
    var fir: Bool?
    /// Stroke penalty on this hole (OB / water, etc.). Optional for rows created before the `penalty` column existed.
    var penalty: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roundId      = "round_id"
        case userId       = "user_id"
        case holeNumber   = "hole_number"
        case par
        case yardage
        case strokeIndex  = "stroke_index"
        case score
        case putts
        case gir
        case fir
        case penalty
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    var scoreVsPar: Int { score - par }
}

/// Totals derived from persisted hole rows (same FIR rule as in-round: par 3 has no FIR).
struct HoleAggregatedTotals {
    let score: Int
    let putts: Int
    let gir: Int
    let fir: Int
    let penalties: Int
}

extension Array where Element == Hole {
    var aggregatedRoundTotals: HoleAggregatedTotals {
        let firEligible = filter { $0.par > 3 }
        return HoleAggregatedTotals(
            score: reduce(0) { $0 + $1.score },
            putts: reduce(0) { $0 + $1.putts },
            gir: filter(\.gir).count,
            fir: firEligible.filter { $0.fir == true }.count,
            penalties: filter { $0.penalty == true }.count
        )
    }

    var totalParFromHoles: Int {
        reduce(0) { $0 + $1.par }
    }
}

struct HoleInsert: Codable {
    let roundId: UUID
    let userId: UUID
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    let strokeIndex: Int?
    let score: Int
    let putts: Int
    let gir: Bool
    let fir: Bool?
    let penalty: Bool

    enum CodingKeys: String, CodingKey {
        case roundId    = "round_id"
        case userId     = "user_id"
        case holeNumber = "hole_number"
        case par
        case yardage
        case strokeIndex = "stroke_index"
        case score
        case putts
        case gir
        case fir
        case penalty
    }
}

struct HoleUpdate: Codable {
    let score: Int
    let putts: Int
    let gir: Bool
    let fir: Bool?
    let penalty: Bool

    enum CodingKeys: String, CodingKey {
        case score
        case putts
        case gir
        case fir
        case penalty
    }
}
