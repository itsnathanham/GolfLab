import Foundation

/// On-disk in-progress scorecard. Survives a hard kill. Finished rounds stay in SwiftData.
enum ActiveRoundDraftStore {
    private static let defaultsKey = "golflab.activeRoundDraft"
    private static let maxDraftAge: TimeInterval = 7 * 24 * 60 * 60
    private static let maxTombstones = 16

    struct Envelope: Codable {
        var savedAt: Date
        var holeClock: UInt64
        var companionSessionId: UUID?
        var companionRevision: UInt64
        var round: ActiveRound?
        var tombstones: [UUID]
    }

    private struct LegacyEnvelope: Codable {
        let savedAt: Date
        let companionSessionId: UUID
        let companionRevision: UInt64
        let round: ActiveRound
    }

    static func load() -> Envelope? {
        if var envelope = readFile() {
            if let expired = expiring(envelope) {
                envelope = expired
                write(envelope)
            }
            return envelope
        }
        guard let migrated = migrateLegacyDefaults() else { return nil }
        write(migrated)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        return migrated
    }

    static func save(
        round: ActiveRound,
        companionSessionId: UUID,
        companionRevision: UInt64,
        holeClock: UInt64
    ) {
        var tombstones = readFile()?.tombstones ?? []
        tombstones.removeAll { $0 == companionSessionId }
        let envelope = Envelope(
            savedAt: Date(),
            holeClock: holeClock,
            companionSessionId: companionSessionId,
            companionRevision: companionRevision,
            round: round,
            tombstones: tombstones
        )
        write(envelope)
    }

    static func tombstone(sessionId: UUID, holeClock: UInt64) {
        var envelope = readFile() ?? Envelope(
            savedAt: Date(),
            holeClock: holeClock,
            companionSessionId: nil,
            companionRevision: 0,
            round: nil,
            tombstones: []
        )
        if envelope.companionSessionId == sessionId {
            envelope.round = nil
            envelope.companionSessionId = nil
        }
        envelope.holeClock = max(envelope.holeClock, holeClock)
        envelope.savedAt = Date()
        envelope.tombstones = cappedTombstones(envelope.tombstones, adding: sessionId)
        write(envelope)
    }

    static func isTombstoned(_ sessionId: UUID) -> Bool {
        readFile()?.tombstones.contains(sessionId) ?? false
    }

    static func clear() {
        let url = fileURL()
        try? FileManager.default.removeItem(at: url)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Returns an updated envelope when the live round is past the age limit.
    private static func expiring(_ envelope: Envelope) -> Envelope? {
        guard envelope.round != nil, let sessionId = envelope.companionSessionId else { return nil }
        guard Date().timeIntervalSince(envelope.savedAt) > maxDraftAge else { return nil }
        var expired = envelope
        expired.round = nil
        expired.companionSessionId = nil
        expired.savedAt = Date()
        expired.tombstones = cappedTombstones(envelope.tombstones, adding: sessionId)
        return expired
    }

    private static func cappedTombstones(_ existing: [UUID], adding sessionId: UUID) -> [UUID] {
        var tombstones = existing.filter { $0 != sessionId }
        tombstones.append(sessionId)
        if tombstones.count > maxTombstones {
            tombstones.removeFirst(tombstones.count - maxTombstones)
        }
        return tombstones
    }

    private static func migrateLegacyDefaults() -> Envelope? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        let decoder = JSONDecoder()
        guard let legacy = try? decoder.decode(LegacyEnvelope.self, from: data) else { return nil }
        let clock = legacy.round.holes.map(\.revision).max() ?? legacy.companionRevision
        return Envelope(
            savedAt: legacy.savedAt,
            holeClock: clock,
            companionSessionId: legacy.companionSessionId,
            companionRevision: legacy.companionRevision,
            round: legacy.round,
            tombstones: []
        )
    }

    private static func readFile() -> Envelope? {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Envelope.self, from: data)
    }

    private static func write(_ envelope: Envelope) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(envelope) else { return }
        let url = fileURL()
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GolfLab", isDirectory: true)
            .appendingPathComponent("active-round.json")
    }
}
