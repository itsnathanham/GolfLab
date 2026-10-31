import Foundation

private enum WatchCodablePayload {
    static func dictionary<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict
    }

    static func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let value = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return value
    }
}

enum WatchMessageKey {
    static let type              = "type"
    static let companionSnapshot = "companionSnapshot"
    static let holeData          = "holeData"
    static let practiceData      = "practiceData"
    static let syncRequest       = "syncRequest"
    static let sessionId         = "sessionId"
    static let revision          = "revision"
    static let celebrationData   = "celebrationData"
}

enum WatchMessageType: String {
    case companionSnapshot = "companionSnapshot"
    case holeEntry          = "holeEntry"
    case practiceEntry      = "practiceEntry"
    case endRound           = "endRound"
    case companionEnded     = "companionEnded"
    case syncRequest        = "syncRequest"
    case weeklyGoalCelebration = "weeklyGoalCelebration"
}

/// Scorecard replicated between iPhone and Watch.
/// `revision` orders snapshots from one sender. Hole truth is per-hole `WatchHoleEntry.revision`.
struct WatchCompanionSnapshot: Codable, Equatable {
    var sessionId: UUID
    var revision: UInt64
    var setup: WatchRoundSetup
    var state: WatchRoundState
    /// Explicit end or discard. A missing local file is not a tombstone.
    var tombstone: Bool
    /// Phone is intentionally replacing whatever session the watch still has.
    var replacesSession: Bool
    var datePlayed: Date?
    var userId: UUID?

    enum CodingKeys: String, CodingKey {
        case sessionId, revision, setup, state, tombstone, replacesSession, datePlayed, userId
    }

    init(
        sessionId: UUID,
        revision: UInt64,
        setup: WatchRoundSetup,
        state: WatchRoundState,
        tombstone: Bool = false,
        replacesSession: Bool = false,
        datePlayed: Date? = nil,
        userId: UUID? = nil
    ) {
        self.sessionId = sessionId
        self.revision = revision
        self.setup = setup
        self.state = state
        self.tombstone = tombstone
        self.replacesSession = replacesSession
        self.datePlayed = datePlayed
        self.userId = userId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        revision = try container.decode(UInt64.self, forKey: .revision)
        setup = try container.decode(WatchRoundSetup.self, forKey: .setup)
        state = try container.decode(WatchRoundState.self, forKey: .state)
        tombstone = try container.decodeIfPresent(Bool.self, forKey: .tombstone) ?? false
        replacesSession = try container.decodeIfPresent(Bool.self, forKey: .replacesSession) ?? false
        datePlayed = try container.decodeIfPresent(Date.self, forKey: .datePlayed)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(revision, forKey: .revision)
        try container.encode(setup, forKey: .setup)
        try container.encode(state, forKey: .state)
        try container.encode(tombstone, forKey: .tombstone)
        try container.encode(replacesSession, forKey: .replacesSession)
        try container.encodeIfPresent(datePlayed, forKey: .datePlayed)
        try container.encodeIfPresent(userId, forKey: .userId)
    }

    static func tombstone(sessionId: UUID) -> WatchCompanionSnapshot {
        WatchCompanionSnapshot(
            sessionId: sessionId,
            revision: 0,
            setup: WatchRoundSetup(courseName: "", tee: nil, totalHoles: 0, holeSetups: []),
            state: WatchRoundState(currentHoleIndex: 0, savedEntries: []),
            tombstone: true
        )
    }
}

extension WatchCompanionSnapshot {
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> WatchCompanionSnapshot? {
        try? JSONDecoder().decode(WatchCompanionSnapshot.self, from: data)
    }

    static func from(message: [String: Any]) -> WatchCompanionSnapshot? {
        guard let data = message[WatchMessageKey.companionSnapshot] as? Data else { return nil }
        return decode(from: data)
    }
}

struct WatchRoundSetup: Codable, Equatable {
    let courseName: String
    let tee: String?
    let totalHoles: Int
    let holeSetups: [WatchHoleSetup]
}

struct WatchHoleSetup: Codable, Equatable {
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    let strokeIndex: Int?
}

struct WatchRoundState: Codable, Equatable {
    let currentHoleIndex: Int
    let savedEntries: [WatchHoleEntry]
}

struct WatchHoleEntry: Codable, Equatable {
    var sessionId: UUID?
    var holeNumber: Int
    var par: Int
    var score: Int
    var putts: Int
    var gir: Bool
    var fir: Bool?
    var penalty: Bool?
    var revision: UInt64
    var editedAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionId, holeNumber, par, score, putts, gir, fir, penalty, revision, editedAt
    }

    init(
        sessionId: UUID? = nil,
        holeNumber: Int,
        par: Int,
        score: Int,
        putts: Int,
        gir: Bool,
        fir: Bool? = nil,
        penalty: Bool? = nil,
        revision: UInt64 = 0,
        editedAt: Date = .distantPast
    ) {
        self.sessionId = sessionId
        self.holeNumber = holeNumber
        self.par = par
        self.score = score
        self.putts = putts
        self.gir = gir
        self.fir = fir
        self.penalty = penalty
        self.revision = revision
        self.editedAt = editedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(UUID.self, forKey: .sessionId)
        holeNumber = try container.decode(Int.self, forKey: .holeNumber)
        par = try container.decode(Int.self, forKey: .par)
        score = try container.decode(Int.self, forKey: .score)
        putts = try container.decode(Int.self, forKey: .putts)
        gir = try container.decode(Bool.self, forKey: .gir)
        fir = try container.decodeIfPresent(Bool.self, forKey: .fir)
        penalty = try container.decodeIfPresent(Bool.self, forKey: .penalty)
        revision = try container.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt) ?? .distantPast
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encode(holeNumber, forKey: .holeNumber)
        try container.encode(par, forKey: .par)
        try container.encode(score, forKey: .score)
        try container.encode(putts, forKey: .putts)
        try container.encode(gir, forKey: .gir)
        try container.encodeIfPresent(fir, forKey: .fir)
        try container.encodeIfPresent(penalty, forKey: .penalty)
        try container.encode(revision, forKey: .revision)
        try container.encode(editedAt, forKey: .editedAt)
    }
}

extension WatchHoleEntry {
    func toDictionary() -> [String: Any] {
        WatchCodablePayload.dictionary(self)
    }

    static func from(dictionary: [String: Any]) -> WatchHoleEntry? {
        WatchCodablePayload.decode(WatchHoleEntry.self, from: dictionary)
    }

    var version: HoleVersion {
        HoleVersion(holeNumber: holeNumber, isSaved: true, revision: revision, editedAt: editedAt)
    }
}

/// Watch → iPhone practice log payload (today's session by default on Watch).
struct WatchPracticeEntry: Codable, Equatable {
    /// Stable for one tap of Save. The phone inserts this id once.
    let id: UUID
    let sessionDate: String
    let practicedRange: Bool
    let practicedChipping: Bool
    let practicedPutting: Bool
    let rangeBallsHit: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionDate = "session_date"
        case practicedRange = "practiced_range"
        case practicedChipping = "practiced_chipping"
        case practicedPutting = "practiced_putting"
        case rangeBallsHit = "range_balls_hit"
    }

    init(
        id: UUID = UUID(),
        sessionDate: String,
        practicedRange: Bool,
        practicedChipping: Bool,
        practicedPutting: Bool,
        rangeBallsHit: Int?
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.practicedRange = practicedRange
        self.practicedChipping = practicedChipping
        self.practicedPutting = practicedPutting
        self.rangeBallsHit = rangeBallsHit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Queued payloads from before ids existed still decode. They cannot be collapsed.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sessionDate = try container.decode(String.self, forKey: .sessionDate)
        practicedRange = try container.decode(Bool.self, forKey: .practicedRange)
        practicedChipping = try container.decode(Bool.self, forKey: .practicedChipping)
        practicedPutting = try container.decode(Bool.self, forKey: .practicedPutting)
        rangeBallsHit = try container.decodeIfPresent(Int.self, forKey: .rangeBallsHit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionDate, forKey: .sessionDate)
        try container.encode(practicedRange, forKey: .practicedRange)
        try container.encode(practicedChipping, forKey: .practicedChipping)
        try container.encode(practicedPutting, forKey: .practicedPutting)
        try container.encodeIfPresent(rangeBallsHit, forKey: .rangeBallsHit)
    }
}

extension WatchPracticeEntry {
    func toDictionary() -> [String: Any] {
        WatchCodablePayload.dictionary(self)
    }

    static func from(dictionary: [String: Any]) -> WatchPracticeEntry? {
        WatchCodablePayload.decode(WatchPracticeEntry.self, from: dictionary)
    }
}

/// iPhone → Watch weekly goal celebration notification.
struct WatchWeeklyGoalCelebration: Codable, Equatable {
    let completedWeeksStreak: Int
    
    func toDictionary() -> [String: Any] {
        WatchCodablePayload.dictionary(self)
    }
    
    static func from(dictionary: [String: Any]) -> WatchWeeklyGoalCelebration? {
        WatchCodablePayload.decode(WatchWeeklyGoalCelebration.self, from: dictionary)
    }
}
