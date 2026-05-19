import Foundation
import WatchConnectivity

@MainActor
class WatchSessionService: NSObject, ObservableObject {
    static let shared = WatchSessionService()

    @Published var roundSetup: WatchRoundSetup?
    @Published var isRoundActive = false
    @Published var currentHoleIndex = 0
    @Published var holeEntries: [WatchHoleEntry] = []
    @Published private(set) var syncGeneration: UInt64 = 0

    private var appliedSessionId: UUID?
    private var lastAppliedRevision: UInt64 = 0

    private override init() {
        super.init()
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

    func requestCompanionSyncFromPhone() {
        guard WCSession.isSupported() else { return }
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.syncRequest.rawValue
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
        applyApplicationContextIfPresent()
    }

    func applyCompanionSnapshot(_ snapshot: WatchCompanionSnapshot) {
        if let appliedSessionId, appliedSessionId == snapshot.sessionId {
            guard snapshot.revision > lastAppliedRevision else { return }
        }
        appliedSessionId = snapshot.sessionId
        lastAppliedRevision = snapshot.revision
        roundSetup = snapshot.setup
        applyRoundState(snapshot.state)
    }

    private func applyRoundState(_ state: WatchRoundState) {
        guard let setup = roundSetup else { return }
        let holeCount = setup.holeSetups.count
        guard holeCount > 0 else { return }
        let maxIdx = holeCount - 1
        currentHoleIndex = min(max(0, state.currentHoleIndex), maxIdx)
        holeEntries = state.savedEntries.sorted { $0.holeNumber < $1.holeNumber }
        isRoundActive = true
        syncGeneration += 1
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
        case .companionSnapshot:
            if let data = context[WatchMessageKey.companionSnapshot] as? Data,
               let snapshot = WatchCompanionSnapshot.decode(from: data) {
                applyCompanionSnapshot(snapshot)
            }
        case .companionEnded:
            clearCompanionSession()
        default:
            break
        }
    }

    private func clearCompanionSession() {
        isRoundActive = false
        roundSetup = nil
        currentHoleIndex = 0
        holeEntries = []
        appliedSessionId = nil
        lastAppliedRevision = 0
    }

    func sendHoleEntry(_ entry: WatchHoleEntry) {
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.holeEntry.rawValue,
            WatchMessageKey.holeData: entry.toDictionary()
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }

        if let index = holeEntries.firstIndex(where: { $0.holeNumber == entry.holeNumber }) {
            holeEntries[index] = entry
        } else {
            holeEntries.append(entry)
        }
    }

    func advanceHole() {
        guard let setup = roundSetup, currentHoleIndex < setup.holeSetups.count - 1 else { return }
        currentHoleIndex += 1
    }

    func endRound() {
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.endRound.rawValue
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
        clearCompanionSession()
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let typeRaw = payload[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        switch type {
        case .companionSnapshot:
            if let snapshot = WatchCompanionSnapshot.from(message: payload) {
                applyCompanionSnapshot(snapshot)
            }
        case .companionEnded:
            clearCompanionSession()
        case .holeEntry, .endRound, .syncRequest:
            break
        }
    }
}

extension WatchSessionService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in applyApplicationContextIfPresent() }
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
}
