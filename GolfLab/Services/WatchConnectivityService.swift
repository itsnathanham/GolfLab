import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var receivedHoleEntries: [WatchHoleEntry] = []
    /// Bumps when `handleHoleEntry` runs so the app can merge into `RoundStore` immediately (not only on End round).
    @Published private(set) var receivedHoleEntriesRevision: UInt64 = 0
    @Published var isWatchReachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send round setup to Watch

    func sendRoundSetup(_ setup: WatchRoundSetup) {
        guard WCSession.default.isReachable else {
            // Store for transfer when Watch reconnects
            if let data = try? JSONEncoder().encode(setup) {
                WCSession.default.transferUserInfo([
                    WatchMessageKey.type: WatchMessageType.roundSetup.rawValue,
                    WatchMessageKey.roundSetup: data
                ])
            }
            return
        }
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.roundSetup.rawValue,
            WatchMessageKey.roundSetup: setup.toDictionary()
        ]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    // MARK: - Push live round progress to Watch

    func sendRoundState(_ state: WatchRoundState) {
        guard let data = state.encoded() else { return }
        let message: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.roundState.rawValue,
            WatchMessageKey.roundState: data
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - Handle incoming hole data from Watch

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

    func clearEntries() {
        receivedHoleEntries = []
    }
}

// MARK: - WCSessionDelegate

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
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        Task { @MainActor in
            switch type {
            case .holeEntry:
                if let holeDict = message[WatchMessageKey.holeData] as? [String: Any] {
                    handleHoleEntry(from: holeDict)
                }
            case .endRound:
                NotificationCenter.default.post(name: .watchRequestedEndRound, object: nil)
            case .roundSetup, .roundState, .syncRequest:
                break
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let typeRaw = userInfo[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        Task { @MainActor in
            switch type {
            case .holeEntry:
                if let holeDict = userInfo[WatchMessageKey.holeData] as? [String: Any] {
                    handleHoleEntry(from: holeDict)
                }
            case .roundSetup, .roundState, .syncRequest, .endRound:
                break
            }
        }
    }
}

extension Notification.Name {
    static let watchRequestedEndRound = Notification.Name("watchRequestedEndRound")
}
