import Foundation
import WatchConnectivity

private struct WatchScorecardFile: Codable {
    var savedAt: Date
    var holeClock: UInt64
    var awaitingPhoneSave: Bool
    var snapshot: WatchCompanionSnapshot?
    var tombstones: [UUID]
}

@MainActor
class WatchSessionService: NSObject, ObservableObject {
    static let shared = WatchSessionService()

    @Published var roundSetup: WatchRoundSetup?
    @Published var isRoundActive = false
    @Published var currentHoleIndex = 0
    @Published var holeEntries: [WatchHoleEntry] = []
    @Published private(set) var syncGeneration: UInt64 = 0
    /// The watch already asked the phone to save. The card is still on disk until the phone confirms.
    @Published private(set) var isWaitingForPhoneToSave = false

    private var appliedSessionId: UUID?
    private var holeClock: UInt64 = 0
    private var tombstones: [UUID] = []
    private var datePlayed: Date?
    private var userId: UUID?
    private var heldSnapshot: WatchCompanionSnapshot?

    private override init() {
        super.init()
        restoreLocalScorecard()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var currentHole: WatchHoleSetup? {
        guard let setup = roundSetup, currentHoleIndex < setup.holeSetups.count else { return nil }
        return setup.holeSetups[currentHoleIndex]
    }

    var totalHoles: Int { roundSetup?.holeSetups.count ?? 18 }

    var scoreVsPar: Int {
        holeEntries.reduce(0) { $0 + ($1.score - $1.par) }
    }

    var displayHoleNumber: Int {
        currentHole?.holeNumber ?? (currentHoleIndex + 1)
    }

    func requestCompanionSyncFromPhone() {
        republishLocalContext()
        guard WCSession.isSupported() else { return }
        sendLiveOrQueued([WatchMessageKey.type: WatchMessageType.syncRequest.rawValue], alwaysQueue: false)
        applyApplicationContextIfPresent()
    }

    func applyCompanionSnapshot(_ snapshot: WatchCompanionSnapshot) {
        if snapshot.tombstone {
            rememberTombstone(snapshot.sessionId)
            if appliedSessionId == snapshot.sessionId || heldSnapshot?.sessionId == snapshot.sessionId {
                clearCompanionSession(keepTombstoneFor: snapshot.sessionId)
            }
            return
        }
        if isWaitingForPhoneToSave {
            return
        }
        if tombstones.contains(snapshot.sessionId), !snapshot.replacesSession {
            return
        }
        if appliedSessionId == nil || snapshot.replacesSession && appliedSessionId != snapshot.sessionId {
            adopt(snapshot)
            return
        }
        // Merge holes even if session IDs don't match, as long as hole metadata is compatible
        // This handles cases where phone and watch got out of sync on session IDs
        if appliedSessionId != snapshot.sessionId {
            // Only adopt if the snapshot has more holes or different setup
            let hasMoreHoles = snapshot.state.savedEntries.count > holeEntries.count
            let differentSetup = snapshot.setup.courseName != roundSetup?.courseName 
                || snapshot.setup.totalHoles != roundSetup?.totalHoles
            if hasMoreHoles || differentSetup || holeEntries.isEmpty {
                adopt(snapshot)
                return
            }
            // Otherwise just merge the holes using revision numbers
        }
        let remoteVersions = snapshot.state.savedEntries.map(\.version)
        mergeSavedEntries(snapshot.state.savedEntries)
        datePlayed = snapshot.datePlayed ?? datePlayed
        userId = snapshot.userId ?? userId
        if snapshot.setup.holeSetups.count == (roundSetup?.holeSetups.count ?? 0) {
            roundSetup = snapshot.setup
        }
        
        // Apply currentHoleIndex from phone so both devices advance together when one saves
        let holeCount = roundSetup?.holeSetups.count ?? 0
        if holeCount > 0 {
            currentHoleIndex = min(max(0, snapshot.state.currentHoleIndex), holeCount - 1)
        }
        
        syncGeneration += 1
        persistLocalScorecard(awaitingPhoneSave: false)
        syncComplication()
        let localVersions = holeEntries.map(\.version)
        if ScorecardSync.localHasProgressRemoteLacks(local: localVersions, remote: remoteVersions) {
            republishLocalContext()
        }
    }

    func sendHoleEntry(_ entry: WatchHoleEntry) {
        guard let sessionId = appliedSessionId else { return }
        holeClock += 1
        let stamped = WatchHoleEntry(
            sessionId: sessionId,
            holeNumber: entry.holeNumber,
            par: entry.par,
            score: entry.score,
            putts: entry.putts,
            gir: entry.gir,
            fir: entry.fir,
            penalty: entry.penalty,
            revision: holeClock,
            editedAt: Date()
        )
        if let index = holeEntries.firstIndex(where: { $0.holeNumber == stamped.holeNumber }) {
            holeEntries[index] = stamped
        } else {
            holeEntries.append(stamped)
        }
        holeEntries.sort { $0.holeNumber < $1.holeNumber }
        persistLocalScorecard(awaitingPhoneSave: false)
        syncComplication()
        republishLocalContext()
        sendLiveOrQueued([
            WatchMessageKey.type: WatchMessageType.holeEntry.rawValue,
            WatchMessageKey.holeData: stamped.toDictionary()
        ], alwaysQueue: true)
    }

    func sendPracticeEntry(_ entry: WatchPracticeEntry) {
        sendLiveOrQueued([
            WatchMessageKey.type: WatchMessageType.practiceEntry.rawValue,
            WatchMessageKey.practiceData: entry.toDictionary()
        ], alwaysQueue: true)
    }

    func advanceHole() {
        guard let setup = roundSetup, currentHoleIndex < setup.holeSetups.count - 1 else { return }
        currentHoleIndex += 1
        persistLocalScorecard(awaitingPhoneSave: false)
        syncComplication()
    }

    func endRound() {
        guard let snapshot = makeSnapshot() else { return }
        persistLocalScorecard(awaitingPhoneSave: true)
        publish(snapshot)
        var payload: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.endRound.rawValue
        ]
        if let data = snapshot.encoded() {
            payload[WatchMessageKey.companionSnapshot] = data
        }
        sendLiveOrQueued(payload, alwaysQueue: true)
        clearInMemoryRound()
        isWaitingForPhoneToSave = true
        heldSnapshot = snapshot
    }

    private func adopt(_ snapshot: WatchCompanionSnapshot) {
        appliedSessionId = snapshot.sessionId
        roundSetup = snapshot.setup
        datePlayed = snapshot.datePlayed
        userId = snapshot.userId
        holeEntries = snapshot.state.savedEntries.sorted { $0.holeNumber < $1.holeNumber }
        holeClock = holeEntries.map(\.revision).max() ?? holeClock
        let holeCount = snapshot.setup.holeSetups.count
        if holeCount > 0 {
            currentHoleIndex = min(max(0, snapshot.state.currentHoleIndex), holeCount - 1)
        } else {
            currentHoleIndex = 0
        }
        isRoundActive = holeCount > 0
        isWaitingForPhoneToSave = false
        heldSnapshot = nil
        syncGeneration += 1
        persistLocalScorecard(awaitingPhoneSave: false)
        syncComplication()
    }

    private func mergeSavedEntries(_ remote: [WatchHoleEntry]) {
        for entry in remote {
            holeClock = max(holeClock, entry.revision)
            if let index = holeEntries.firstIndex(where: { $0.holeNumber == entry.holeNumber }) {
                if ScorecardSync.prefersRemote(local: holeEntries[index].version, remote: entry.version) {
                    holeEntries[index] = entry
                }
            } else {
                holeEntries.append(entry)
            }
        }
        holeEntries.sort { $0.holeNumber < $1.holeNumber }
    }

    private func applyApplicationContextIfPresent() {
        guard WCSession.isSupported() else { return }
        applyReceivedApplicationContext(WCSession.default.receivedApplicationContext)
    }

    private func applyReceivedApplicationContext(_ context: [String: Any]) {
        guard let typeRaw = context[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }
        switch type {
        case .companionSnapshot, .companionEnded:
            if let data = context[WatchMessageKey.companionSnapshot] as? Data,
               let snapshot = WatchCompanionSnapshot.decode(from: data) {
                applyCompanionSnapshot(snapshot)
            }
        case .holeEntry, .endRound, .syncRequest, .practiceEntry:
            break
        }
    }

    private func sendLiveOrQueued(_ message: [String: Any], alwaysQueue: Bool) {
        guard WCSession.isSupported() else { return }
        if alwaysQueue {
            WCSession.default.transferUserInfo(message)
        }
        guard WCSession.default.isReachable else {
            if !alwaysQueue {
                WCSession.default.transferUserInfo(message)
            }
            return
        }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { _ in
            if !alwaysQueue {
                WCSession.default.transferUserInfo(message)
            }
        })
    }

    private func republishLocalContext() {
        if isWaitingForPhoneToSave, let heldSnapshot {
            publish(heldSnapshot)
            return
        }
        guard let snapshot = makeSnapshot() else { return }
        publish(snapshot)
    }

    private func publish(_ snapshot: WatchCompanionSnapshot) {
        guard WCSession.isSupported(), let data = snapshot.encoded() else { return }
        try? WCSession.default.updateApplicationContext([
            WatchMessageKey.type: WatchMessageType.companionSnapshot.rawValue,
            WatchMessageKey.companionSnapshot: data
        ])
    }

    private func makeSnapshot() -> WatchCompanionSnapshot? {
        guard let sessionId = appliedSessionId, let setup = roundSetup else { return nil }
        let lastIdx = max(0, setup.holeSetups.count - 1)
        let idx = min(max(0, currentHoleIndex), lastIdx)
        return WatchCompanionSnapshot(
            sessionId: sessionId,
            revision: holeClock,
            setup: setup,
            state: WatchRoundState(currentHoleIndex: idx, savedEntries: holeEntries),
            datePlayed: datePlayed,
            userId: userId
        )
    }

    private func rememberTombstone(_ sessionId: UUID) {
        tombstones.removeAll { $0 == sessionId }
        tombstones.append(sessionId)
        if tombstones.count > 16 {
            tombstones.removeFirst(tombstones.count - 16)
        }
    }

    private func clearCompanionSession(keepTombstoneFor sessionId: UUID?) {
        isRoundActive = false
        isWaitingForPhoneToSave = false
        roundSetup = nil
        currentHoleIndex = 0
        holeEntries = []
        appliedSessionId = nil
        heldSnapshot = nil
        datePlayed = nil
        userId = nil
        if let sessionId {
            rememberTombstone(sessionId)
        }
        persistLocalScorecard(awaitingPhoneSave: false)
        WatchComplicationStore.publish(displayHoleNumber: nil)
    }

    private func clearInMemoryRound() {
        isRoundActive = false
        roundSetup = nil
        currentHoleIndex = 0
        holeEntries = []
        appliedSessionId = nil
        WatchComplicationStore.publish(displayHoleNumber: nil)
    }

    private func syncComplication() {
        guard isRoundActive else {
            WatchComplicationStore.publish(displayHoleNumber: nil)
            return
        }
        WatchComplicationStore.publish(displayHoleNumber: displayHoleNumber)
    }

    private func restoreLocalScorecard() {
        guard let file = readScorecardFile() else { return }
        holeClock = file.holeClock
        tombstones = file.tombstones
        guard let snapshot = file.snapshot, !snapshot.tombstone else { return }
        if tombstones.contains(snapshot.sessionId) { return }
        if file.awaitingPhoneSave {
            heldSnapshot = snapshot
            isWaitingForPhoneToSave = true
            appliedSessionId = snapshot.sessionId
            return
        }
        adopt(snapshot)
    }

    private func persistLocalScorecard(awaitingPhoneSave: Bool) {
        let snapshot = awaitingPhoneSave ? (heldSnapshot ?? makeSnapshot()) : makeSnapshot()
        if awaitingPhoneSave {
            heldSnapshot = snapshot
        }
        let file = WatchScorecardFile(
            savedAt: Date(),
            holeClock: holeClock,
            awaitingPhoneSave: awaitingPhoneSave,
            snapshot: snapshot,
            tombstones: tombstones
        )
        writeScorecardFile(file)
    }

    private func scorecardURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GolfLab", isDirectory: true)
            .appendingPathComponent("watch-scorecard.json")
    }

    private func readScorecardFile() -> WatchScorecardFile? {
        let url = scorecardURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchScorecardFile.self, from: data)
    }

    private func writeScorecardFile(_ file: WatchScorecardFile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(file) else { return }
        let url = scorecardURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

extension WatchSessionService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            applyApplicationContextIfPresent()
            republishLocalContext()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in applyReceivedApplicationContext(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in handleIncomingPayload(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in handleIncomingPayload(userInfo) }
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let typeRaw = payload[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        switch type {
        case .companionSnapshot, .companionEnded:
            if let snapshot = WatchCompanionSnapshot.from(message: payload) {
                applyCompanionSnapshot(snapshot)
            }
        case .holeEntry, .endRound, .syncRequest, .practiceEntry:
            break
        }
    }
}
