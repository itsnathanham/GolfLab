import Foundation

enum WatchMessageKey {
    static let type              = "type"
    static let companionSnapshot = "companionSnapshot"
    static let holeData          = "holeData"
    static let syncRequest       = "syncRequest"
    static let sessionId         = "sessionId"
    static let revision          = "revision"
}

enum WatchMessageType: String {
    case companionSnapshot = "companionSnapshot"
    case holeEntry          = "holeEntry"
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
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict
    }

    static func from(dictionary: [String: Any]) -> WatchHoleEntry? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let entry = try? JSONDecoder().decode(WatchHoleEntry.self, from: data)
        else { return nil }
        return entry
    }
}
