import Foundation

// Keys for WatchConnectivity message dictionaries
enum WatchMessageKey {
    static let type         = "type"
    static let roundSetup   = "roundSetup"
    static let roundState   = "roundState"
    static let holeData     = "holeData"
    static let endRound     = "endRound"
    static let syncRequest  = "syncRequest"
}

enum WatchMessageType: String {
    case roundSetup  = "roundSetup"
    case roundState  = "roundState"
    case holeEntry   = "holeEntry"
    case endRound    = "endRound"
    case syncRequest = "syncRequest"
}

// Sent from iPhone → Watch when a round begins
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

/// Sent from iPhone → Watch whenever in-round progress changes (current hole + saved holes).
struct WatchRoundState: Codable {
    let currentHoleIndex: Int
    let savedEntries: [WatchHoleEntry]
}

// Sent from Watch → iPhone after each hole save
struct WatchHoleEntry: Codable {
    let holeNumber: Int
    let par: Int
    let score: Int
    let putts: Int
    let gir: Bool
    let fir: Bool?
    /// Omitted on older Watch builds; treated as `false` when merging on iPhone.
    let penalty: Bool?
}

extension WatchRoundSetup {
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict
    }

    static func from(dictionary: [String: Any]) -> WatchRoundSetup? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let setup = try? JSONDecoder().decode(WatchRoundSetup.self, from: data)
        else { return nil }
        return setup
    }
}

extension WatchRoundState {
    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> WatchRoundState? {
        try? JSONDecoder().decode(WatchRoundState.self, from: data)
    }
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
