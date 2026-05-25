import Foundation
import os
import SwiftUI

private let roundStoreLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "GolfLab",
    category: "RoundStore"
)

/// Outcome of saving the **current** scorecard hole in one store write (commit + optional index advance).
enum ScorecardHoleCommitOutcome: Equatable {
    /// Saved and moved `currentHoleIndex` to the next hole.
    case advancedToNextHole
    /// Saved the final hole; index unchanged — present End round UI.
    case completedRoundSaveLastHole
}

// Central state object for an active round, shared across iPhone tabs and Watch sync
@MainActor
class RoundStore: ObservableObject {

    // MARK: - Active round state

    @Published var activeRound: ActiveRound?
    @Published var isRoundActive = false

    // MARK: - Historical data (loaded on app launch / tab focus)

    @Published var allRounds: [Round] = []
    /// Logged practice sessions for the signed-in user (loaded with `loadRounds`, same network pass as rounds).
    @Published var allPracticeSessions: [PracticeSession] = []
    /// Increments when `loadRounds` replaces `allRounds` — use for `onChange` instead of mapping all ids.
    @Published private(set) var roundsListEpoch: UInt64 = 0
    /// Persisted hole row counts per round (from a single `holes` query). Empty until `loadRounds` succeeds.
    @Published var holeRowCountByRoundId: [UUID: Int] = [:]
    /// Sum of `par` from stored hole rows per round (same source as Home vs-par). Omitted when a round has no holes.
    @Published var totalParSumByRoundId: [UUID: Int] = [:]
    /// Persisted `(roundId, par, score)` rows from `fetchHoleAggregatesByUser` (same query as round/par sums).
    @Published private(set) var holeParScoreSamples: [HoleParScoreSample] = []
    @Published var isLoadingRounds = false
    /// From `users` profile (`weekly_round_target` / `weekly_practice_target`); defaults used until loaded.
    @Published var weeklyRoundTarget: Int = 1
    @Published var weeklyPracticeTarget: Int = 2
    /// Goal history for streak math (past weeks use targets that were active then).
    @Published var weeklyGoalTargetRevisions: [WeeklyGoalTargetRevision] = []

    /// Active weekly-goals celebration overlay (set on `MainTabView`).
    @Published var weeklyGoalCelebration: WeeklyGoalCelebrationPresentation?
    /// Queued until practice sheet dismisses or app returns to foreground.
    private var weeklyGoalCelebrationPending: WeeklyGoalCelebrationPresentation?

    /// Minimum holes of this par in the **resolved default season** (persisted + in-season active saved) before showing a numeric average in Hole Entry.
    private let minimumParAverageSample = 3

    /// When true, the Round tab shows **New Round** setup even if a last-round summary would normally appear (e.g. **Start round** from Home).
    @Published var preferNewRoundSetup = false

    /// Set after restoring an in-progress scorecard from local storage (process kill / relaunch).
    @Published private(set) var didRestoreActiveRoundFromDraft = false

    /// Coalesces overlapping `loadRounds()` calls (Home + History `.task`, pull-to-refresh) so `syncWeeklyTargetsFromProfile` does not race.
    private var loadRoundsInflight: Task<Void, Never>?

    private var companionSessionId = UUID()
    private var companionRevision: UInt64 = 0

    init() {
        restoreActiveRoundFromDraftIfNeeded()
    }

    func requestRoundSetupFromHome() {
        preferNewRoundSetup = true
    }

    func clearPreferNewRoundSetup() {
        preferNewRoundSetup = false
    }

    func dismissRestoredRoundBanner() {
        didRestoreActiveRoundFromDraft = false
    }

    /// Abandons the in-progress scorecard without saving to Supabase.
    func discardActiveRound() {
        activeRound = nil
        isRoundActive = false
        didRestoreActiveRoundFromDraft = false
        preferNewRoundSetup = false
        ActiveRoundDraftStore.clear()
        WatchConnectivityService.shared.clearEntries()
        WatchConnectivityService.shared.notifyCompanionEnded()
    }

    // MARK: - Start a new round

    func startRound(setup: RoundSetup, userId: UUID) {
        preferNewRoundSetup = false
        didRestoreActiveRoundFromDraft = false
        WatchConnectivityService.shared.clearEntries()
        companionSessionId = UUID()
        companionRevision = 0

        let holes: [ActiveHole] = setup.holeSetups.map { h in
            ActiveHole(holeNumber: h.holeNumber, par: h.par, yardage: h.yardage, strokeIndex: h.strokeIndex)
        }
        activeRound = ActiveRound(setup: setup, userId: userId, holes: holes)
        isRoundActive = true
        pushCompanionSnapshotToWatch()
    }

    /// Pushes setup + `currentHoleIndex` + saved holes to Watch (and persists a local draft).
    func pushCompanionSnapshotToWatch() {
        guard let round = activeRound, isRoundActive else { return }
        let snapshot = makeCompanionSnapshot(for: round)
        companionRevision = snapshot.revision
        WatchConnectivityService.shared.pushCompanionSnapshot(snapshot)
        persistActiveRoundDraft()
    }

    private func makeCompanionSnapshot(for round: ActiveRound) -> WatchCompanionSnapshot {
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
        let setup = WatchRoundSetup(
            courseName: round.setup.courseName,
            tee: round.setup.tee,
            totalHoles: round.setup.totalHoles,
            holeSetups: round.holes.map {
                WatchHoleSetup(
                    holeNumber: $0.holeNumber,
                    par: $0.par,
                    yardage: $0.yardage,
                    strokeIndex: $0.strokeIndex
                )
            }
        )
        let nextRevision = companionRevision + 1
        return WatchCompanionSnapshot(
            sessionId: companionSessionId,
            revision: nextRevision,
            setup: setup,
            state: WatchRoundState(currentHoleIndex: idx, savedEntries: saved)
        )
    }

    private func restoreActiveRoundFromDraftIfNeeded() {
        guard let envelope = ActiveRoundDraftStore.load() else { return }
        activeRound = envelope.round
        isRoundActive = true
        companionSessionId = envelope.companionSessionId
        companionRevision = envelope.companionRevision
        didRestoreActiveRoundFromDraft = true
    }

    private func persistActiveRoundDraft() {
        guard isRoundActive, let round = activeRound else {
            ActiveRoundDraftStore.clear()
            return
        }
        ActiveRoundDraftStore.save(
            round: round,
            companionSessionId: companionSessionId,
            companionRevision: companionRevision
        )
    }

    // MARK: - Save a hole (from iPhone entry)

    func saveHole(_ entry: ActiveHole) {
        guard var round = activeRound else { return }
        guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { return }
        var saved = entry
        saved.isSaved = true
        round.holes[index] = saved
        activeRound = round
        pushCompanionSnapshotToWatch()
    }

    /// Saves `entry` on the current hole and bumps `currentHoleIndex` in **one** `activeRound` assignment when not on the last hole.
    /// Avoids a one-frame state where the current hole is saved (forward chevron enabled) before the index advances.
    @discardableResult
    func saveCurrentScorecardHoleMergingAdvance(_ entry: ActiveHole) -> ScorecardHoleCommitOutcome? {
        guard var round = activeRound else { return nil }
        guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }),
              index == round.currentHoleIndex
        else {
            saveHole(entry)
            return nil
        }
        var saved = entry
        saved.isSaved = true
        round.holes[index] = saved

        if index < round.holes.count - 1 {
            round.currentHoleIndex = index + 1
            activeRound = round
            pushCompanionSnapshotToWatch()
            return .advancedToNextHole
        }
        activeRound = round
        pushCompanionSnapshotToWatch()
        return .completedRoundSaveLastHole
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
        pushCompanionSnapshotToWatch()
    }

    /// Optional-chaining writes to nested `struct` fields do not persist; always copy the round, mutate, assign back.
    func updateActiveRoundCurrentHoleIndex(_ index: Int) {
        guard var round = activeRound else { return }
        round.currentHoleIndex = index
        activeRound = round
        pushCompanionSnapshotToWatch()
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
        pushCompanionSnapshotToWatch()
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

    /// Watch **End & Save** — same persistence path as iPhone End round (merges queued hole payloads first).
    func saveActiveRoundFromWatchEndRequest() async {
        guard isRoundActive, activeRound != nil else { return }
        do {
            _ = try await saveRoundToSupabase()
        } catch RoundError.noActiveRound {
            // Already finished (e.g. duplicate end message).
        } catch {
            roundStoreLogger.error("Watch end-round save failed: \(error.localizedDescription)")
        }
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
        pushCompanionSnapshotToWatch()
    }

    // MARK: - Save round to Supabase

    func saveRoundToSupabase() async throws -> UUID {
        let goalsBeforeSave = weeklyGoalsSnapshot()
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
        WatchConnectivityService.shared.notifyCompanionEnded()
        ActiveRoundDraftStore.clear()

        let newId = savedRound.id
        // Clear before reload so par averages from `fetchHoleAggregatesByUser` are not merged twice with the same holes.
        activeRound = nil
        isRoundActive = false
        didRestoreActiveRoundFromDraft = false
        await loadRounds()
        queueWeeklyGoalCelebrationIfNeeded(before: goalsBeforeSave)
        return newId
    }

    // MARK: - Load all rounds

    func loadRounds() async {
        if let existing = loadRoundsInflight {
            await existing.value
            return
        }
        let task = Task { @MainActor in
            await self.performLoadRoundsBody()
        }
        loadRoundsInflight = task
        await task.value
        loadRoundsInflight = nil
    }

    private func performLoadRoundsBody() async {
        guard let userId = await AuthService.shared.currentUserId else { return }
        isLoadingRounds = true
        defer { isLoadingRounds = false }

        async let fetchedPractice = SupabaseService.shared.fetchAllPracticeSessions(userId: userId)

        do {
            var rounds = try await SupabaseService.shared.fetchRounds(userId: userId)
            rounds = await reconcileStoredRoundTotals(rounds: rounds)
            allRounds = rounds
            roundsListEpoch += 1

            async let fetchedAggregates = SupabaseService.shared.fetchHoleAggregatesByUser(userId: userId)

            do {
                let aggregates = try await fetchedAggregates
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
                roundStoreLogger.error("Error loading hole aggregates: \(error.localizedDescription)")
                holeRowCountByRoundId = [:]
                totalParSumByRoundId = [:]
                holeParScoreSamples = []
            }

            allPracticeSessions = (try? await fetchedPractice) ?? []
        } catch {
            roundStoreLogger.error("Error loading rounds: \(error.localizedDescription)")
            allPracticeSessions = []
            _ = try? await fetchedPractice
        }

        await syncWeeklyTargetsFromProfile()
    }

    /// Refreshes weekly goal state from Supabase (e.g. after `loadRounds`).
    func syncWeeklyTargetsFromProfile() async {
        guard let userId = await AuthService.shared.currentUserId else { return }
        guard let profile = try? await SupabaseService.shared.fetchProfile(userId: userId) else { return }
        applyWeeklyGoalState(from: profile)
    }

    /// Applies profile weekly targets + revision history (Home / History streak UI).
    func applyWeeklyGoalState(from profile: UserProfile) {
        let r = profile.weeklyRoundTarget ?? 1
        let p = profile.weeklyPracticeTarget ?? 2
        weeklyRoundTarget = r
        weeklyPracticeTarget = p
        weeklyGoalTargetRevisions = WeeklyGoalTargetRevision.revisionsAlignedWithFlatColumns(
            revisions: profile.weeklyGoalTargetRevisions,
            flatRound: r,
            flatPractice: p
        )
    }

    /// Merges a row returned from `insertPracticeSession` so History calendar updates without a full reload.
    func upsertPracticeSession(_ session: PracticeSession) {
        let goalsBefore = weeklyGoalsSnapshot()
        var next = allPracticeSessions.filter { $0.id != session.id }
        next.append(session)
        allPracticeSessions = PracticeSession.sortedForDisplay(next)
        queueWeeklyGoalCelebrationIfNeeded(before: goalsBefore)
    }

    // MARK: - Weekly goal celebration

    func weeklyGoalsSnapshot(now: Date = Date(), calendar: Calendar = .current) -> GLWeeklyGoalsStreak.Snapshot {
        GLWeeklyGoalsStreak.snapshot(
            now: now,
            calendar: calendar,
            roundTarget: weeklyRoundTarget,
            practiceTarget: weeklyPracticeTarget,
            goalRevisions: weeklyGoalTargetRevisions,
            rounds: allRounds,
            holeRowCountByRoundId: holeRowCountByRoundId,
            practiceSessions: allPracticeSessions
        )
    }

    func dismissWeeklyGoalCelebration() {
        weeklyGoalCelebration = nil
    }

    /// Call after the practice log sheet closes so confetti is not hidden behind the sheet.
    func presentPendingWeeklyGoalCelebrationIfNeeded() {
        guard weeklyGoalCelebration == nil, let pending = weeklyGoalCelebrationPending else { return }
        weeklyGoalCelebrationPending = nil
        WeeklyGoalCelebration.markCelebrated(weekStartYMD: pending.weekStartYMD)
        weeklyGoalCelebration = pending
    }

    private func queueWeeklyGoalCelebrationIfNeeded(before: GLWeeklyGoalsStreak.Snapshot) {
        let after = weeklyGoalsSnapshot()
        guard let presentation = WeeklyGoalCelebration.presentationIfNewlyCompleted(before: before, after: after) else {
            return
        }
        weeklyGoalCelebrationPending = presentation
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
                roundStoreLogger.error("Reconcile totals for round \(round.id.uuidString): \(error.localizedDescription)")
            }
        }
        return updated
    }
}

// MARK: - Supporting types

struct RoundSetup: Codable, Equatable {
    var courseName: String
    var tee: String?
    var totalHoles: Int
    var datePlayed: Date
    var holeSetups: [HoleSetup]
}

struct HoleSetup: Codable, Equatable {
    let holeNumber: Int
    var par: Int
    var yardage: Int?
    var strokeIndex: Int?
}

struct ActiveRound: Codable, Equatable {
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

struct ActiveHole: Codable, Equatable {
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

extension Array where Element == ActiveHole {
    var firHitPercentage: Double? {
        let eligible = filter { $0.par > 3 }
        guard !eligible.isEmpty else { return nil }
        let hits = eligible.filter { $0.fir == true }.count
        return Double(hits) / Double(eligible.count) * 100
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
