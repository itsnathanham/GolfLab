import Foundation
import SwiftUI

// Central state object for an active round, shared across iPhone tabs and Watch sync
@MainActor
class RoundStore: ObservableObject {

    // MARK: - Active round state

    @Published var activeRound: ActiveRound?
    @Published var isRoundActive = false

    // MARK: - Historical data (loaded on app launch / tab focus)

    @Published var allRounds: [Round] = []
    /// Increments when `loadRounds` replaces `allRounds` — use for `onChange` instead of mapping all ids.
    @Published private(set) var roundsListEpoch: UInt64 = 0
    /// Persisted hole row counts per round (from a single `holes` query). Empty until `loadRounds` succeeds.
    @Published var holeRowCountByRoundId: [UUID: Int] = [:]
    /// Sum of `par` from stored hole rows per round (same source as Home vs-par). Omitted when a round has no holes.
    @Published var totalParSumByRoundId: [UUID: Int] = [:]
    /// Persisted `(roundId, par, score)` rows from `fetchHoleAggregatesByUser` (same query as round/par sums).
    @Published private(set) var holeParScoreSamples: [HoleParScoreSample] = []
    @Published var isLoadingRounds = false

    /// Minimum holes of this par in the **resolved default season** (persisted + in-season active saved) before showing a numeric average in Hole Entry.
    private let minimumParAverageSample = 3

    /// When true, the Round tab shows **New Round** setup even if a last-round summary would normally appear (e.g. **Start round** from Home).
    @Published var preferNewRoundSetup = false

    func requestRoundSetupFromHome() {
        preferNewRoundSetup = true
    }

    func clearPreferNewRoundSetup() {
        preferNewRoundSetup = false
    }

    // MARK: - Start a new round

    func startRound(setup: RoundSetup, userId: UUID) {
        preferNewRoundSetup = false
        WatchConnectivityService.shared.clearEntries()

        let holes: [ActiveHole] = setup.holeSetups.map { h in
            ActiveHole(holeNumber: h.holeNumber, par: h.par, yardage: h.yardage, strokeIndex: h.strokeIndex)
        }
        activeRound = ActiveRound(setup: setup, userId: userId, holes: holes)
        isRoundActive = true

        let watchSetup = WatchRoundSetup(
            courseName: setup.courseName,
            tee: setup.tee,
            totalHoles: setup.totalHoles,
            holeSetups: setup.holeSetups.map {
                WatchHoleSetup(holeNumber: $0.holeNumber, par: $0.par, yardage: $0.yardage, strokeIndex: $0.strokeIndex)
            }
        )
        WatchConnectivityService.shared.sendRoundSetup(watchSetup)
    }

    /// Pushes `currentHoleIndex` and saved hole rows to Watch so picking up mid-round stays aligned with the phone.
    func pushActiveRoundStateToCompanion() {
        guard let round = activeRound, isRoundActive else { return }
        let lastIdx = max(0, round.holes.count - 1)
        let idx = min(max(0, round.currentHoleIndex), lastIdx)
        let saved = round.holes.filter(\.isSaved).map { h in
            WatchHoleEntry(
                holeNumber: h.holeNumber,
                par: h.par,
                score: h.score,
                putts: h.putts,
                gir: h.gir,
                fir: h.fir,
                penalty: h.penalty
            )
        }
        let state = WatchRoundState(currentHoleIndex: idx, savedEntries: saved)
        WatchConnectivityService.shared.sendRoundState(state)
    }

    // MARK: - Save a hole (from iPhone entry)

    func saveHole(_ entry: ActiveHole) {
        guard var round = activeRound else { return }
        guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { return }
        var saved = entry
        saved.isSaved = true
        round.holes[index] = saved
        activeRound = round
        pushActiveRoundStateToCompanion()
    }

    /// Writes score, putts, GIR, FIR, penalty, and `isSaved` on the existing hole row (no `builtHole()` rebuild).
    /// Callers pass GIR/FIR/penalty the user sees on the form (merge @State with store so toggles still save if `patchActiveHole` missed).
    func commitInProgressHoleSave(holeNumber: Int, par: Int, score: Int, putts: Int, gir: Bool, fir: Bool?, penalty: Bool) {
        guard var round = activeRound,
              let idx = round.holes.firstIndex(where: { $0.holeNumber == holeNumber }) else { return }
        round.holes[idx].score = score
        round.holes[idx].putts = putts
        round.holes[idx].gir = gir
        round.holes[idx].fir = par > 3 ? fir : nil
        round.holes[idx].penalty = penalty
        round.holes[idx].isSaved = true
        activeRound = round
        pushActiveRoundStateToCompanion()
    }

    /// Optional-chaining writes to nested `struct` fields do not persist; always copy the round, mutate, assign back.
    func updateActiveRoundCurrentHoleIndex(_ index: Int) {
        guard var round = activeRound else { return }
        round.currentHoleIndex = index
        activeRound = round
        pushActiveRoundStateToCompanion()
    }

    /// Mutate one hole on the in-progress round (single source of truth for toggles / steppers).
    func patchActiveHole(holeNumber: Int, _ patch: (inout ActiveHole) -> Void) {
        guard var round = activeRound,
              let idx = round.holes.firstIndex(where: { $0.holeNumber == holeNumber }) else { return }
        patch(&round.holes[idx])
        activeRound = round
    }

    // MARK: - Merge Watch hole data

    func mergeWatchEntries(_ entries: [WatchHoleEntry]) {
        guard var round = activeRound else { return }
        var appliedAny = false
        for entry in entries {
            guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { continue }
            // Holes already saved on iPhone keep phone data — avoids stale Watch payloads wiping edits.
            if round.holes[index].isSaved { continue }
            appliedAny = true
            round.holes[index].score = entry.score
            round.holes[index].putts = entry.putts
            round.holes[index].gir = entry.gir
            round.holes[index].fir = entry.fir
            round.holes[index].penalty = entry.penalty ?? false
            round.holes[index].isSaved = true
        }
        activeRound = round
        if appliedAny {
            reconcileCurrentHoleAfterCompanionSave()
        }
        pushActiveRoundStateToCompanion()
    }

    /// After Watch (or reconciliation) saves holes: move the scorecard to the first hole that still needs a scorecard save.
    private func reconcileCurrentHoleAfterCompanionSave() {
        guard var round = activeRound else { return }
        if let idx = round.holes.firstIndex(where: { !$0.isSaved }) {
            round.currentHoleIndex = idx
        } else if !round.holes.isEmpty {
            round.currentHoleIndex = round.holes.count - 1
        }
        activeRound = round
    }

    /// Applies any hole data received from Apple Watch so totals and inserts include every logged hole,
    /// even if the Round tab was not open while the Watch sent entries.
    func mergePendingWatchHoleEntries() {
        mergeWatchEntries(WatchConnectivityService.shared.receivedHoleEntries)
    }

    /// Marks the **current** hole as saved when every earlier hole is already saved and the user is past the first hole.
    /// This fixes losing the last hole (or any in-progress hole) when **End Round** is used without tapping **Save Hole**:
    /// score/putts live in the form until committed, while GIR/FIR already patch the store.
    func persistUnsavedCurrentHoleIfEligible() {
        guard var round = activeRound else { return }
        let idx = round.currentHoleIndex
        guard idx < round.holes.count, idx > 0 else { return }
        guard round.holes[..<idx].allSatisfy(\.isSaved), !round.holes[idx].isSaved else { return }
        round.holes[idx].isSaved = true
        activeRound = round
        pushActiveRoundStateToCompanion()
    }

    // MARK: - Save round to Supabase

    func saveRoundToSupabase() async throws -> UUID {
        mergePendingWatchHoleEntries()
        persistUnsavedCurrentHoleIfEligible()
        guard let round = activeRound else { throw RoundError.noActiveRound }

        let totals = round.computedTotals
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: round.setup.datePlayed)

        let roundInsert = RoundInsert(
            userId: round.userId,
            courseName: round.setup.courseName,
            tee: round.setup.tee,
            holes: round.setup.totalHoles,
            datePlayed: dateString,
            totalScore: totals.score,
            totalPutts: totals.putts,
            totalGir: totals.gir,
            totalFir: totals.fir
        )

        let savedRound = try await SupabaseService.shared.insertRound(roundInsert)

        let holeInserts: [HoleInsert] = round.holes.filter { $0.isSaved }.map { h in
            HoleInsert(
                roundId: savedRound.id,
                userId: round.userId,
                holeNumber: h.holeNumber,
                par: h.par,
                yardage: h.yardage,
                strokeIndex: h.strokeIndex,
                score: h.score,
                putts: h.putts,
                gir: h.gir,
                fir: h.fir,
                penalty: h.penalty
            )
        }

        _ = try await SupabaseService.shared.insertHoles(holeInserts)

        WatchConnectivityService.shared.clearEntries()

        let newId = savedRound.id
        // Clear before reload so par averages from `fetchHoleAggregatesByUser` are not merged twice with the same holes.
        activeRound = nil
        isRoundActive = false
        await loadRounds()
        return newId
    }

    func abandonRound() {
        activeRound = nil
        isRoundActive = false
        preferNewRoundSetup = false
        WatchConnectivityService.shared.clearEntries()
    }

    // MARK: - Load all rounds

    func loadRounds() async {
        guard let userId = await AuthService.shared.currentUserId else { return }
        isLoadingRounds = true
        do {
            var rounds = try await SupabaseService.shared.fetchRounds(userId: userId)
            rounds = await reconcileStoredRoundTotals(rounds: rounds)
            allRounds = rounds
            roundsListEpoch += 1

            do {
                let aggregates = try await SupabaseService.shared.fetchHoleAggregatesByUser(userId: userId)
                holeRowCountByRoundId = Dictionary(uniqueKeysWithValues: rounds.map { round in
                    (round.id, aggregates.rowCountByRound[round.id] ?? 0)
                })
                var parByRound: [UUID: Int] = [:]
                for round in rounds {
                    let c = aggregates.rowCountByRound[round.id] ?? 0
                    let sum = aggregates.parSumByRound[round.id] ?? 0
                    if c > 0, sum > 0 {
                        parByRound[round.id] = sum
                    }
                }
                totalParSumByRoundId = parByRound
                holeParScoreSamples = aggregates.holeParScoreSamples
            } catch {
                print("Error loading hole aggregates: \(error)")
                holeRowCountByRoundId = [:]
                totalParSumByRoundId = [:]
                holeParScoreSamples = []
            }
        } catch {
            print("Error loading rounds: \(error)")
        }
        isLoadingRounds = false
    }

    /// Gross score average for holes of this par in the **same calendar season as the Stats season picker** (`StatsSeasonFilter.seasonYearAlignedWithStatsPicker`).
    /// Counts persisted hole rows in that season plus **saved** holes on the active round when `datePlayed` falls in that season (those holes are not in Stats’ `holesForStats` until the round is saved).
    func averageScoreForPar(_ par: Int) -> Double? {
        let seasonYear = StatsSeasonFilter.seasonYearAlignedWithStatsPicker(rounds: allRounds)
        let roundYearById = Dictionary(uniqueKeysWithValues: allRounds.compactMap { r -> (UUID, Int)? in
            guard let y = StatsSeasonFilter.calendarYear(from: r) else { return nil }
            return (r.id, y)
        })
        var sum = 0
        var count = 0
        for sample in holeParScoreSamples {
            guard sample.par == par else { continue }
            guard roundYearById[sample.roundId] == seasonYear else { continue }
            sum += sample.score
            count += 1
        }
        if let active = activeRound {
            let activeYear = Calendar.current.component(.year, from: active.setup.datePlayed)
            if activeYear == seasonYear {
                for h in active.holes where h.isSaved && h.par == par {
                    sum += h.score
                    count += 1
                }
            }
        }
        guard count >= minimumParAverageSample else { return nil }
        return Double(sum) / Double(count)
    }

    /// When the `rounds` summary columns disagree with summed `holes`, update Supabase and the in-memory model.
    /// Uses whatever hole rows exist (even when count is below `round.holes`) so list totals match the scorecard table.
    private func reconcileStoredRoundTotals(rounds: [Round]) async -> [Round] {
        var updated = rounds
        for i in updated.indices {
            let round = updated[i]
            guard let holes = try? await SupabaseService.shared.fetchHoles(roundId: round.id),
                  !holes.isEmpty
            else { continue }

            let agg = holes.aggregatedRoundTotals
            let matches = round.totalScore == agg.score
                && round.totalPutts == agg.putts
                && round.totalGir == agg.gir
                && round.totalFir == agg.fir
            if matches { continue }

            do {
                try await SupabaseService.shared.updateRoundTotals(
                    roundId: round.id,
                    totalScore: agg.score,
                    totalPutts: agg.putts,
                    totalGir: agg.gir,
                    totalFir: agg.fir
                )
                updated[i].totalScore = agg.score
                updated[i].totalPutts = agg.putts
                updated[i].totalGir = agg.gir
                updated[i].totalFir = agg.fir
            } catch {
                print("Reconcile totals for round \(round.id): \(error)")
            }
        }
        return updated
    }
}

// MARK: - Supporting types

struct RoundSetup {
    var courseName: String
    var tee: String?
    var totalHoles: Int
    var datePlayed: Date
    var holeSetups: [HoleSetup]
}

struct HoleSetup {
    let holeNumber: Int
    var par: Int
    var yardage: Int?
    var strokeIndex: Int?
}

struct ActiveRound {
    let setup: RoundSetup
    let userId: UUID
    var holes: [ActiveHole]
    var currentHoleIndex: Int = 0

    var currentHole: ActiveHole? {
        guard currentHoleIndex < holes.count else { return nil }
        return holes[currentHoleIndex]
    }

    var computedTotals: RoundTotals {
        let savedHoles = holes.filter { $0.isSaved }
        let firHoles = savedHoles.filter { $0.par > 3 }
        return RoundTotals(
            score:     savedHoles.reduce(0) { $0 + $1.score },
            putts:     savedHoles.reduce(0) { $0 + $1.putts },
            gir:       savedHoles.filter { $0.gir }.count,
            fir:       firHoles.filter { $0.fir == true }.count
        )
    }

    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
}

struct ActiveHole {
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    let strokeIndex: Int?
    var score: Int
    var putts: Int
    var gir: Bool
    var fir: Bool?
    var penalty: Bool
    var isSaved: Bool

    init(holeNumber: Int, par: Int, yardage: Int? = nil, strokeIndex: Int? = nil) {
        self.holeNumber  = holeNumber
        self.par         = par
        self.yardage     = yardage
        self.strokeIndex = strokeIndex
        self.score       = par
        self.putts       = 2
        self.gir         = false
        self.fir         = par > 3 ? false : nil
        self.penalty     = false
        self.isSaved     = false
    }
}

struct RoundTotals {
    let score: Int
    let putts: Int
    let gir: Int
    let fir: Int
}

enum RoundError: LocalizedError {
    case noActiveRound

    var errorDescription: String? {
        switch self {
        case .noActiveRound: return "No active round in progress."
        }
    }
}
