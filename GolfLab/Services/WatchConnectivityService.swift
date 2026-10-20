import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedHoleEntries: [WatchHoleEntry] = []
    @Published private(set) var receivedHoleEntriesRevision: UInt64 = 0
    @Published private(set) var receivedPracticeEntriesRevision: UInt64 = 0
    @Published var isWatchReachable = false
    private(set) var latestWatchScorecard: WatchCompanionSnapshot?

    private weak var roundStore: RoundStore?
    private var pendingPracticeEntries: [WatchPracticeEntry] = []
    private var didNotifyActivation = false
    private var pendingWatchEnd = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func attach(_ store: RoundStore) {
        roundStore = store
        if let latestWatchScorecard {
            store.applyWatchScorecard(latestWatchScorecard)
        }
        if !receivedHoleEntries.isEmpty {
            store.mergeWatchEntries(receivedHoleEntries)
        }
        if pendingWatchEnd {
            pendingWatchEnd = false
            Task {
                await store.saveActiveRoundFromWatchEndRequest()
                store.presentPendingWeeklyGoalCelebrationIfNeeded()
            }
        }
        if WCSession.isSupported(), WCSession.default.activationState == .activated {
            notifyActivationIfNeeded()
        }
    }

    /// Latest scorecard only. A queued full-card transfer can arrive late and wipe newer holes, so snapshots are not queued.
    func pushCompanionSnapshot(_ snapshot: WatchCompanionSnapshot) {
        guard WCSession.isSupported(), let data = snapshot.encoded() else { return }
        let payload = snapshotPayload(snapshot, data: data)
        do {
            try WCSession.default.updateApplicationContext([
                WatchMessageKey.type: WatchMessageType.companionSnapshot.rawValue,
                WatchMessageKey.companionSnapshot: data
            ])
        } catch {
            // The next live send or a later context update still carries the card.
        }
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    func clearEntries() {
        receivedHoleEntries = []
    }

    func drainPendingPracticeEntries() -> [WatchPracticeEntry] {
        let entries = pendingPracticeEntries
        pendingPracticeEntries = []
        return entries
    }

    private func notifyActivationIfNeeded() {
        guard roundStore != nil, !didNotifyActivation else { return }
        didNotifyActivation = true
        roundStore?.connectivityDidActivate()
    }

    private func snapshotPayload(_ snapshot: WatchCompanionSnapshot, data: Data) -> [String: Any] {
        [
            WatchMessageKey.type: snapshot.tombstone
                ? WatchMessageType.companionEnded.rawValue
                : WatchMessageType.companionSnapshot.rawValue,
            WatchMessageKey.companionSnapshot: data,
            WatchMessageKey.sessionId: snapshot.sessionId.uuidString,
            WatchMessageKey.revision: snapshot.revision
        ]
    }

    private func handleHoleEntry(from dict: [String: Any]) {
        guard let entry = WatchHoleEntry.from(dictionary: dict) else { return }
        if let index = receivedHoleEntries.firstIndex(where: { $0.holeNumber == entry.holeNumber }) {
            receivedHoleEntries[index] = entry
        } else {
            receivedHoleEntries.append(entry)
        }
        receivedHoleEntries.sort { $0.holeNumber < $1.holeNumber }
        receivedHoleEntriesRevision += 1
        roundStore?.mergeWatchEntries([entry])
    }

    private func handlePracticeEntry(from dict: [String: Any]) {
        guard let entry = WatchPracticeEntry.from(dictionary: dict) else { return }
        pendingPracticeEntries.append(entry)
        receivedPracticeEntriesRevision += 1
    }

    private func handleScorecardData(_ data: Data) {
        guard let snapshot = WatchCompanionSnapshot.decode(from: data) else { return }
        latestWatchScorecard = snapshot
        roundStore?.applyWatchScorecard(snapshot)
    }

    private func handleIncomingFromWatch(_ payload: [String: Any]) {
        guard let typeRaw = payload[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        switch type {
        case .holeEntry:
            if let holeDict = payload[WatchMessageKey.holeData] as? [String: Any] {
                handleHoleEntry(from: holeDict)
            }
        case .practiceEntry:
            if let practiceDict = payload[WatchMessageKey.practiceData] as? [String: Any] {
                handlePracticeEntry(from: practiceDict)
            }
        case .endRound:
            if let data = payload[WatchMessageKey.companionSnapshot] as? Data {
                handleScorecardData(data)
            }
            guard let roundStore else {
                pendingWatchEnd = true
                return
            }
            Task {
                await roundStore.saveActiveRoundFromWatchEndRequest()
                roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
            }
        case .syncRequest:
            if roundStore?.isRoundActive == true {
                roundStore?.pushCompanionSnapshotToWatch()
            } else if let latestWatchScorecard {
                roundStore?.applyWatchScorecard(latestWatchScorecard)
            }
            NotificationCenter.default.post(name: .watchRequestedCompanionSync, object: nil)
        case .companionSnapshot:
            if let data = payload[WatchMessageKey.companionSnapshot] as? Data {
                handleScorecardData(data)
            }
        case .companionEnded:
            if let data = payload[WatchMessageKey.companionSnapshot] as? Data {
                handleScorecardData(data)
            }
        }
    }

    private func applyReceivedApplicationContext(_ context: [String: Any]) {
        guard let data = context[WatchMessageKey.companionSnapshot] as? Data else { return }
        handleScorecardData(data)
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            isWatchReachable = reachable
            applyReceivedApplicationContext(context)
            if activationState == .activated {
                notifyActivationIfNeeded()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            isWatchReachable = reachable
            if reachable {
                NotificationCenter.default.post(name: .watchRequestedCompanionSync, object: nil)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in applyReceivedApplicationContext(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in handleIncomingFromWatch(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in handleIncomingFromWatch(userInfo) }
    }
}

extension Notification.Name {
    static let watchRequestedEndRound = Notification.Name("watchRequestedEndRound")
    static let watchRequestedCompanionSync = Notification.Name("watchRequestedCompanionSync")
}
