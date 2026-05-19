import Foundation

enum ActiveRoundDraftStore {
    private static let defaultsKey = "golflab.activeRoundDraft"
    /// Drafts older than this are discarded on load.
    private static let maxDraftAge: TimeInterval = 7 * 24 * 60 * 60

    struct Envelope: Codable {
        let savedAt: Date
        let companionSessionId: UUID
        let companionRevision: UInt64
        let round: ActiveRound
    }

    static func save(
        round: ActiveRound,
        companionSessionId: UUID,
        companionRevision: UInt64
    ) {
        let envelope = Envelope(
            savedAt: Date(),
            companionSessionId: companionSessionId,
            companionRevision: companionRevision,
            round: round
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func load() -> Envelope? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else { return nil }
        if Date().timeIntervalSince(envelope.savedAt) > maxDraftAge {
            clear()
            return nil
        }
        return envelope
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
