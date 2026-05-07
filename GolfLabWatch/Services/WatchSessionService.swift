import Foundation
import WatchConnectivity

@MainActor
class WatchSessionService: NSObject, ObservableObject {
    static let shared = WatchSessionService()

    @Published var roundSetup: WatchRoundSetup?
    @Published var isRoundActive = false
    @Published var currentHoleIndex = 0
    @Published var holeEntries: [WatchHoleEntry] = []
    /// Increments whenever `roundSetup`/`roundState` arrives from iPhone — refresh transient stepper defaults.
    @Published private(set) var syncGeneration: UInt64 = 0

    func applyRoundStateFromPhone(_ state: WatchRoundState) {
        guard roundSetup != nil else { return }
        let holeCount = roundSetup?.holeSetups.count ?? 0
        guard holeCount > 0 else { return }
        let maxIdx = holeCount - 1
        currentHoleIndex = min(max(0, state.currentHoleIndex), maxIdx)
        holeEntries = state.savedEntries.sorted { $0.holeNumber < $1.holeNumber }
        isRoundActive = true
        syncGeneration += 1
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Hole management

    var currentHole: WatchHoleSetup? {
        guard let setup = roundSetup, currentHoleIndex < setup.holeSetups.count else { return nil }
        return setup.holeSetups[currentHoleIndex]
    }

    var totalHoles: Int { roundSetup?.holeSetups.count ?? 18 }

    var scoreVsPar: Int {
        holeEntries.reduce(0) { $0 + ($1.score - $1.par) }
    }

    // MARK: - Send hole entry to iPhone

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
        }
        isRoundActive = false
        roundSetup = nil
        currentHoleIndex = 0
        holeEntries = []
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw)
        else { return }

        Task { @MainActor in
            switch type {
            case .roundSetup:
                if let dict = message[WatchMessageKey.roundSetup] as? [String: Any],
                   let setup = WatchRoundSetup.from(dictionary: dict) {
                    roundSetup = setup
                    isRoundActive = true
                    currentHoleIndex = 0
                    holeEntries = []
                    syncGeneration += 1
                }
            case .roundState:
                if let data = message[WatchMessageKey.roundState] as? Data,
                   let state = WatchRoundState.decode(from: data) {
                    applyRoundStateFromPhone(state)
                }
            case .holeEntry, .endRound, .syncRequest:
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
            case .roundSetup:
                if let dataRaw = userInfo[WatchMessageKey.roundSetup] as? Data,
                   let setup = try? JSONDecoder().decode(WatchRoundSetup.self, from: dataRaw) {
                    roundSetup = setup
                    isRoundActive = true
                    currentHoleIndex = 0
                    holeEntries = []
                    syncGeneration += 1
                }
            case .roundState:
                if let data = userInfo[WatchMessageKey.roundState] as? Data,
                   let state = WatchRoundState.decode(from: data) {
                    applyRoundStateFromPhone(state)
                }
            case .holeEntry, .endRound, .syncRequest:
                break
            }
        }
    }
}
