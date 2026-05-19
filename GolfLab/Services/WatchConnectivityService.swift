import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedHoleEntries: [WatchHoleEntry] = []
    @Published private(set) var receivedHoleEntriesRevision: UInt64 = 0
    @Published var isWatchReachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func pushCompanionSnapshot(_ snapshot: WatchCompanionSnapshot) {
        guard WCSession.isSupported(), let data = snapshot.encoded() else { return }

        let payload: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.companionSnapshot.rawValue,
            WatchMessageKey.companionSnapshot: data,
            WatchMessageKey.sessionId: snapshot.sessionId.uuidString,
            WatchMessageKey.revision: snapshot.revision
        ]

        do {
            try WCSession.default.updateApplicationContext([
                WatchMessageKey.type: WatchMessageType.companionSnapshot.rawValue,
                WatchMessageKey.companionSnapshot: data
            ])
        } catch {
            // Live messages still apply if context is too large or pending.
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func notifyCompanionEnded() {
        guard WCSession.isSupported() else { return }
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.companionEnded.rawValue
        ]
        do {
            try WCSession.default.updateApplicationContext([
                WatchMessageKey.type: WatchMessageType.companionEnded.rawValue
            ])
        } catch {}
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    func clearEntries() {
        receivedHoleEntries = []
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
        case .endRound:
            NotificationCenter.default.post(name: .watchRequestedEndRound, object: nil)
        case .syncRequest:
            NotificationCenter.default.post(name: .watchRequestedCompanionSync, object: nil)
        case .companionSnapshot, .companionEnded:
            break
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            if session.isReachable {
                NotificationCenter.default.post(name: .watchRequestedCompanionSync, object: nil)
            }
        }
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
