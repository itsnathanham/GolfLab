import SwiftUI

struct Round: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var courseName: String
    var tee: String?
    var holes: Int
    var datePlayed: String
    var totalScore: Int?
    var totalPutts: Int?
    var totalGir: Int?
    var totalFir: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case courseName     = "course_name"
        case tee
        case holes
        case datePlayed     = "date_played"
        case totalScore     = "total_score"
        case totalPutts     = "total_putts"
        case totalGir       = "total_gir"
        case totalFir       = "total_fir"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    var scoreVsPar: Int? {
        guard let totalScore, let par = holePars else { return nil }
        return totalScore - par
    }

    // Computed only if we have full hole data attached
    var holePars: Int? { nil }

    /// Stored as `yyyy-MM-dd` (API / sorting). Shown in UI as **MM/dd/yy**.
    var datePlayedDisplay: String {
        Self.displayMMDDYY(fromYMD: datePlayed)
    }

    /// Parses `yyyy-MM-dd` and returns `MM/dd/yy`, or the original string if parsing fails.
    static func displayMMDDYY(fromYMD ymd: String) -> String {
        let head = String(ymd.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return ymd }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        guard let date = Calendar.current.date(from: dc) else { return ymd }
        return displayDateFormatter.string(from: date)
    }

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "MM/dd/yy"
        return f
    }()
}

extension Round {
    /// Leading **`yyyy-MM-dd`** from `datePlayed` (matches calendar keys and Postgres `date`).
    var datePlayedYMD: String {
        String(datePlayed.prefix(10))
    }

    /// Fewer stored hole rows than the round’s configured hole count (e.g. 8 of 9 on disk).
    func isScorecardIncomplete(storedHoleRows: Int) -> Bool {
        holes > 0 && storedHoleRows < holes
    }

    /// Home / History / Last Round header: strokes vs par (`%+.1f`) and teal/coral, or `--` when par is unknown.
    func vsParHeadline(totalParFromStoredHoles: Int?) -> (text: String, color: Color) {
        guard let score = totalScore,
              let par = totalParFromStoredHoles,
              par > 0
        else { return ("--", .textTertiary) }
        let delta = score - par
        let text = String(format: "%+.1f", Double(delta))
        let color: Color = delta <= 0 ? .chartPositive : .chartNegative
        return (text, color)
    }
}

extension [Round] {
    /// Sort by **`datePlayed`** (`yyyy-MM-dd` string order matches chronological), newest first; ties broken by **`createdAt`**, then **`id`** (same as History list and Supabase `fetchRounds`).
    func sortedByDatePlayedDescending() -> [Round] {
        sorted { lhs, rhs in
            if lhs.datePlayed != rhs.datePlayed { return lhs.datePlayed > rhs.datePlayed }
            if let lc = lhs.createdAt, let rc = rhs.createdAt, lc != rc { return lc > rc }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    /// The **`limit`** most recent rounds by **date played**, not by list or insert order.
    func lastRoundsByDatePlayed(_ limit: Int) -> [Round] {
        guard limit > 0 else { return [] }
        return Array(sortedByDatePlayedDescending().prefix(limit))
    }
}

struct RoundInsert: Codable {
    let userId: UUID
    let courseName: String
    let tee: String?
    let holes: Int
    let datePlayed: String
    let totalScore: Int
    let totalPutts: Int
    let totalGir: Int
    let totalFir: Int

    enum CodingKeys: String, CodingKey {
        case userId         = "user_id"
        case courseName     = "course_name"
        case tee
        case holes
        case datePlayed     = "date_played"
        case totalScore     = "total_score"
        case totalPutts     = "total_putts"
        case totalGir       = "total_gir"
        case totalFir       = "total_fir"
    }
}
