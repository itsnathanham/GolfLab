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
}

enum WatchMessageType: String {
    case companionSnapshot = "companionSnapshot"
    case holeEntry          = "holeEntry"
    case practiceEntry      = "practiceEntry"
    case endRound           = "endRound"
    case companionEnded     = "companionEnded"
    case syncRequest        = "syncRequest"
}

/// Authoritative iPhone → Watch payload (setup + progress). Also written to `applicationContext`.
struct WatchCompanionSnapshot: Codable {
    let sessionId: UUID
    let revision: UInt64
    let setup: WatchRoundSetup
    let state: WatchRoundState
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

struct WatchRoundSetup: Codable {
    let courseName: String
    let tee: String?
    let totalHoles: Int
    let holeSetups: [WatchHoleSetup]
}

struct WatchHoleSetup: Codable {
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    let strokeIndex: Int?
}

struct WatchRoundState: Codable {
    let currentHoleIndex: Int
    let savedEntries: [WatchHoleEntry]
}

struct WatchHoleEntry: Codable {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int
    let gir: Bool
    let fir: Bool?
    let penalty: Bool?
}

extension WatchHoleEntry {
    func toDictionary() -> [String: Any] {
        WatchCodablePayload.dictionary(self)
    }

    static func from(dictionary: [String: Any]) -> WatchHoleEntry? {
        WatchCodablePayload.decode(WatchHoleEntry.self, from: dictionary)
    }
}

/// Watch → iPhone practice log payload (today's session by default on Watch).
struct WatchPracticeEntry: Codable, Equatable {
    let sessionDate: String
    let practicedRange: Bool
    let practicedChipping: Bool
    let practicedPutting: Bool
    let rangeBallsHit: Int?

    enum CodingKeys: String, CodingKey {
        case sessionDate = "session_date"
        case practicedRange = "practiced_range"
        case practicedChipping = "practiced_chipping"
        case practicedPutting = "practiced_putting"
        case rangeBallsHit = "range_balls_hit"
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
