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

    // MARK: - Historical data (hydrated at launch; tabs observe this store)

    @Published var allRounds: [Round] = []
    /// Logged practice sessions for the signed-in user (loaded with `loadRounds`).
    @Published var allPracticeSessions: [PracticeSession] = []
    /// Increments when `loadRounds` replaces `allRounds` — use for `onChange` instead of mapping all ids.
    @Published private(set) var roundsListEpoch: UInt64 = 0
    /// Persisted hole row counts per round (from a single `holes` query). Empty until `loadRounds` succeeds.
    @Published var holeRowCountByRoundId: [UUID: Int] = [:]
    /// Sum of `par` from stored hole rows per round (same source as Home vs-par). Omitted when a round has no holes.
    @Published var totalParSumByRoundId: [UUID: Int] = [:]
    /// Persisted `(roundId, par, score)` rows from `fetchHoleAggregatesByUser` (same query as round/par sums).
    @Published private(set) var holeParScoreSamples: [HoleParScoreSample] = []
    /// Full hole rows by round — warmed at launch so tabs do not flash local fetches on first open.
    @Published private(set) var holesByRoundId: [UUID: [Hole]] = [:]
    /// Display name from profile (Home avatar); set during hydrate / profile save.
    @Published private(set) var profileDisplayName: String?
    /// From `users` profile (`weekly_round_target` / `weekly_practice_target`); defaults used until loaded.
    @Published var weeklyRoundTarget: Int = 1
    @Published var weeklyPracticeTarget: Int = 2
    /// Goal history for streak math (past weeks use targets that were active then).
    @Published var weeklyGoalTargetRevisions: [WeeklyGoalTargetRevision] = []

    var avatarInitials: String {
        Self.initials(from: profileDisplayName)
    }

    /// Active weekly-goals celebration overlay (set on `MainTabView`).
    @Published var weeklyGoalCelebration: WeeklyGoalCelebrationPresentation?
    /// Queued until practice sheet dismisses or app returns to foreground.
    private var weeklyGoalCelebrationPending: WeeklyGoalCelebrationPresentation?

    /// Minimum holes of this par in the **resolved default season** (persisted + in-season active saved) before showing a numeric average in Hole Entry.
    private let minimumParAverageSample = 3

    /// When true, the Round tab shows **New Round** setup even if a last-round summary would normally appear (e.g. **Start round** from Home).
    @Published var preferNewRoundSetup = false

    /// Set after restoring an in-progress scorecard from local storage or the watch.
    @Published private(set) var didRestoreActiveRoundFromDraft = false
    /// Restored from the watch because the phone had no local round.
    @Published private(set) var restoredFromWatch = false

    /// Coalesces overlapping hydrate / refresh / pull-to-refresh so profile sync does not race.
    private var loadRoundsInflight: Task<Void, Never>?

    private var companionSessionId = UUID()
    private var companionRevision: UInt64 = 0
    /// Highest per-hole revision this phone has seen or written for the live session.
    private var holeClock: UInt64 = 0
    /// The next outbound snapshot intentionally replaces a different watch session.
    private var outboundReplacesSession = false

    init() {
        restoreActiveRoundFromDraftIfNeeded()
        WatchConnectivityService.shared.attach(self)
    }

    /// Called once Watch Connectivity is active, after any scorecard the watch already published has been merged.
    func connectivityDidActivate() {
        if isRoundActive {
            pushCompanionSnapshotToWatch()
        } else {
            republishLatestTombstone()
        }
    }

    func requestRoundSetupFromHome() {
        preferNewRoundSetup = true
    }

    func clearPreferNewRoundSetup() {
        preferNewRoundSetup = false
    }

    func dismissRestoredRoundBanner() {
        didRestoreActiveRoundFromDraft = false
        restoredFromWatch = false
    }

    /// Abandons the in-progress scorecard without saving.
    func discardActiveRound() {
        let endedSession = companionSessionId
        let hadRound = isRoundActive
        activeRound = nil
        isRoundActive = false
        didRestoreActiveRoundFromDraft = false
        restoredFromWatch = false
        preferNewRoundSetup = false
        if hadRound {
            ActiveRoundDraftStore.tombstone(sessionId: endedSession, holeClock: holeClock)
            WatchConnectivityService.shared.pushCompanionSnapshot(.tombstone(sessionId: endedSession))
        }
        WatchConnectivityService.shared.clearEntries()
    }

    // MARK: - Start a new round

    func startRound(setup: RoundSetup, userId: UUID) {
        preferNewRoundSetup = false
        didRestoreActiveRoundFromDraft = false
        restoredFromWatch = false
        WatchConnectivityService.shared.clearEntries()
        companionSessionId = UUID()
        companionRevision = 0
        holeClock = 0
        outboundReplacesSession = true

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
                sessionId: companionSessionId,
                holeNumber: h.holeNumber,
                par: h.par,
                score: h.score,
                putts: h.putts,
                gir: h.gir,
                fir: h.fir,
                penalty: h.penalty,
                revision: h.revision,
                editedAt: h.editedAt
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
        let replacesSession = outboundReplacesSession
        outboundReplacesSession = false
        return WatchCompanionSnapshot(
            sessionId: companionSessionId,
            revision: nextRevision,
            setup: setup,
            state: WatchRoundState(currentHoleIndex: idx, savedEntries: saved),
            tombstone: false,
            replacesSession: replacesSession,
            datePlayed: round.setup.datePlayed,
            userId: round.userId
        )
    }

    private func restoreActiveRoundFromDraftIfNeeded() {
        guard let envelope = ActiveRoundDraftStore.load(), let round = envelope.round else { return }
        activeRound = round
        isRoundActive = true
        companionSessionId = envelope.companionSessionId ?? UUID()
        companionRevision = envelope.companionRevision
        holeClock = max(envelope.holeClock, round.holes.map(\.revision).max() ?? 0)
        didRestoreActiveRoundFromDraft = true
        restoredFromWatch = false
    }

    private func persistActiveRoundDraft() {
        guard isRoundActive, let round = activeRound else { return }
        ActiveRoundDraftStore.save(
            round: round,
            companionSessionId: companionSessionId,
            companionRevision: companionRevision,
            holeClock: holeClock
        )
    }

    private func stampSaved(_ hole: inout ActiveHole) {
        holeClock += 1
        hole.revision = holeClock
        hole.editedAt = Date()
        hole.isSaved = true
    }

    private func noteRemoteRevision(_ revision: UInt64) {
        if revision > holeClock {
            holeClock = revision
        }
    }

    private func republishLatestTombstone() {
        guard let sessionId = ActiveRoundDraftStore.load()?.tombstones.last else { return }
        WatchConnectivityService.shared.pushCompanionSnapshot(.tombstone(sessionId: sessionId))
    }

    // MARK: - Save a hole (from iPhone entry)

    func saveHole(_ entry: ActiveHole) {
        guard var round = activeRound else { return }
        guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { return }
        var saved = entry
        stampSaved(&saved)
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
        stampSaved(&saved)
        round.holes[index] = saved

        if index < round.holes.count - 1 {
            round.currentHoleIndex = ScorecardSync.nextIndexAfterFurthestSave(
                saved: round.holes.map(\.version),
                holeNumbers: round.holes.map(\.holeNumber)
            ) ?? index + 1
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
        stampSaved(&round.holes[idx])
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
        persistActiveRoundDraft()
    }

    // MARK: - Merge Watch hole data

    func mergeWatchEntries(_ entries: [WatchHoleEntry]) {
        let versions = entries.map(\.version)
        guard applyWatchHoleVersions(entries) else {
            replyIfWatchIsBehind(remote: versions)
            return
        }
        replyIfWatchIsBehind(remote: versions)
    }

    /// Merges a watch scorecard. The cursor only moves when a watch hole version wins the merge (see `applyWatchHoleVersions`).
    /// When the phone has no round and this session was not discarded, adopts the watch card.
    func applyWatchScorecard(_ snapshot: WatchCompanionSnapshot) {
        if snapshot.tombstone {
            if companionSessionId == snapshot.sessionId, isRoundActive {
                activeRound = nil
                isRoundActive = false
                didRestoreActiveRoundFromDraft = false
                restoredFromWatch = false
                ActiveRoundDraftStore.tombstone(sessionId: snapshot.sessionId, holeClock: holeClock)
            }
            return
        }
        if ActiveRoundDraftStore.isTombstoned(snapshot.sessionId), !snapshot.replacesSession {
            return
        }
        guard isRoundActive, companionSessionId == snapshot.sessionId else {
            guard !isRoundActive else { return }
            adoptWatchScorecard(snapshot)
            return
        }
        let versions = snapshot.state.savedEntries.map(\.version)
        _ = applyWatchHoleVersions(snapshot.state.savedEntries)
        replyIfWatchIsBehind(remote: versions)
    }

    private func applyWatchHoleVersions(_ entries: [WatchHoleEntry]) -> Bool {
        guard var round = activeRound else { return false }
        var changed = false
        for entry in entries {
            if let sessionId = entry.sessionId, sessionId != companionSessionId { continue }
            if let sessionId = entry.sessionId, ActiveRoundDraftStore.isTombstoned(sessionId) { continue }
            guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { continue }
            let remote = entry.version
            guard ScorecardSync.prefersRemote(local: round.holes[index].version, remote: remote) else { continue }
            round.holes[index].score = entry.score
            round.holes[index].putts = entry.putts
            round.holes[index].gir = entry.gir
            round.holes[index].fir = entry.fir
            round.holes[index].penalty = entry.penalty ?? false
            round.holes[index].isSaved = true
            round.holes[index].revision = entry.revision
            round.holes[index].editedAt = entry.editedAt
            noteRemoteRevision(entry.revision)
            changed = true
        }
        if changed {
            // The cursor follows saves, and only when a hole version actually won the merge.
            // A stale or replayed snapshot changes no hole, so it cannot move the cursor.
            if let next = ScorecardSync.nextIndexAfterFurthestSave(
                saved: round.holes.map(\.version),
                holeNumbers: round.holes.map(\.holeNumber)
            ) {
                round.currentHoleIndex = next
            }
            activeRound = round
            persistActiveRoundDraft()
        }
        return changed
    }

    private func replyIfWatchIsBehind(remote: [HoleVersion]) {
        guard let round = activeRound, isRoundActive else { return }
        let local = round.holes.map(\.version)
        guard ScorecardSync.localHasProgressRemoteLacks(local: local, remote: remote) else { return }
        pushCompanionSnapshotToWatch()
    }

    private func adoptWatchScorecard(_ snapshot: WatchCompanionSnapshot) {
        let userId = snapshot.userId ?? GolfLabUserID.load() ?? UUID()
        let setups = snapshot.setup.holeSetups.map {
            HoleSetup(holeNumber: $0.holeNumber, par: $0.par, yardage: $0.yardage, strokeIndex: $0.strokeIndex)
        }
        guard !setups.isEmpty else { return }
        let setup = RoundSetup(
            courseName: snapshot.setup.courseName,
            tee: snapshot.setup.tee,
            totalHoles: snapshot.setup.totalHoles,
            datePlayed: snapshot.datePlayed ?? Date(),
            holeSetups: setups
        )
        var holes: [ActiveHole] = setups.map {
            ActiveHole(holeNumber: $0.holeNumber, par: $0.par, yardage: $0.yardage, strokeIndex: $0.strokeIndex)
        }
        for entry in snapshot.state.savedEntries {
            guard let index = holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { continue }
            holes[index].score = entry.score
            holes[index].putts = entry.putts
            holes[index].gir = entry.gir
            holes[index].fir = entry.fir
            holes[index].penalty = entry.penalty ?? false
            holes[index].isSaved = true
            holes[index].revision = entry.revision
            holes[index].editedAt = entry.editedAt
            noteRemoteRevision(entry.revision)
        }
        var round = ActiveRound(setup: setup, userId: userId, holes: holes)
        let lastIdx = max(0, holes.count - 1)
        round.currentHoleIndex = min(max(0, snapshot.state.currentHoleIndex), lastIdx)
        companionSessionId = snapshot.sessionId
        companionRevision = snapshot.revision
        activeRound = round
        isRoundActive = true
        didRestoreActiveRoundFromDraft = true
        restoredFromWatch = true
        preferNewRoundSetup = false
        persistActiveRoundDraft()
    }

    /// Applies any hole data received from Apple Watch so totals and inserts include every logged hole,
    /// even if the Round tab was not open while the Watch sent entries.
    func mergePendingWatchHoleEntries() {
        mergeWatchEntries(WatchConnectivityService.shared.receivedHoleEntries)
    }

    /// Watch **End & Save** — same persistence path as iPhone End round (merges queued hole payloads first).
    func saveActiveRoundFromWatchEndRequest() async {
        if !isRoundActive, let snapshot = WatchConnectivityService.shared.latestWatchScorecard {
            applyWatchScorecard(snapshot)
        }
        guard isRoundActive, activeRound != nil else { return }
        do {
            _ = try await saveActiveRound()
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
        stampSaved(&round.holes[idx])
        activeRound = round
        pushCompanionSnapshotToWatch()
    }

    // MARK: - Save round

    func saveActiveRound() async throws -> UUID {
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

        let savedRound = try await GolfLabData.store.insertRound(roundInsert)

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

        _ = try await GolfLabData.store.insertHoles(holeInserts)

        let endedSession = companionSessionId
        WatchConnectivityService.shared.clearEntries()
        ActiveRoundDraftStore.tombstone(sessionId: endedSession, holeClock: holeClock)
        WatchConnectivityService.shared.pushCompanionSnapshot(.tombstone(sessionId: endedSession))

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

    /// Full launch hydrate: rounds, practice, aggregates, profile goals, and hole rows.
    func hydrateForLaunch() async {
        await loadRounds()
    }

    /// Quiet refresh used by pull-to-refresh, CloudKit merges, and post-save reloads.
    func loadRounds() async {
        await loadHistoricalData()
    }

    private func loadHistoricalData() async {
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
        guard let userId = AccountService.shared.currentUserId else { return }

        async let fetchedPractice = GolfLabData.store.fetchAllPracticeSessions(userId: userId)
        async let fetchedHolesByRound = GolfLabData.store.fetchAllHolesByUser(userId: userId)

        do {
            var rounds = try await GolfLabData.store.fetchRounds(userId: userId)
            let holesByRound = (try? await fetchedHolesByRound) ?? [:]
            rounds = await reconcileStoredRoundTotals(rounds: rounds, holesByRoundId: holesByRound)
            allRounds = rounds
            roundsListEpoch += 1

            async let fetchedAggregates = GolfLabData.store.fetchHoleAggregatesByUser(userId: userId)

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
            replaceHolesCache(holesByRound)
        } catch {
            roundStoreLogger.error("Error loading rounds: \(error.localizedDescription)")
            allPracticeSessions = []
            _ = try? await fetchedPractice
            _ = try? await fetchedHolesByRound
        }

        await syncWeeklyTargetsFromProfile()
    }

    /// Replaces the shared hole cache (launch hydrate / full refresh).
    func replaceHolesCache(_ map: [UUID: [Hole]]) {
        holesByRoundId = map.mapValues { holes in
            holes.sorted { $0.holeNumber < $1.holeNumber }
        }
    }

    /// Patches one round’s holes after edit / detail fetch.
    func cacheHoles(_ holes: [Hole], for roundId: UUID) {
        holesByRoundId[roundId] = holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    func holes(for roundId: UUID) -> [Hole] {
        holesByRoundId[roundId] ?? []
    }

    /// Ensures hole rows for `roundId` are in the shared cache; fetches only on miss/mismatch.
    @discardableResult
    func ensureHolesCached(roundId: UUID) async -> [Hole] {
        let expected = holeRowCountByRoundId[roundId] ?? 0
        if let cached = holesByRoundId[roundId], expected == 0 || cached.count == expected {
            return cached
        }
        let fetched = (try? await GolfLabData.store.fetchHoles(roundId: roundId)) ?? []
        cacheHoles(fetched, for: roundId)
        return fetched
    }

    private static func initials(from displayName: String?) -> String {
        guard let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return ""
        }
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Refreshes weekly goal state from the profile (e.g. after `loadRounds`).
    func syncWeeklyTargetsFromProfile() async {
        guard let userId = AccountService.shared.currentUserId else { return }
        guard let profile = try? await GolfLabData.store.fetchProfile(userId: userId) else { return }
        applyWeeklyGoalState(from: profile)
        profileDisplayName = profile.displayName
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
        profileDisplayName = profile.displayName
    }
    /// Merges a row returned from `insertPracticeSession` so History calendar updates without a full reload.
    func upsertPracticeSession(_ session: PracticeSession) {
        let goalsBefore = weeklyGoalsSnapshot()
        var next = allPracticeSessions.filter { $0.id != session.id }
        next.append(session)
        allPracticeSessions = PracticeSession.sortedForDisplay(next)
        queueWeeklyGoalCelebrationIfNeeded(before: goalsBefore)
    }

    /// Persists practice sessions relayed from Apple Watch (same path as iPhone Log practice).
    func savePracticeSessionsFromWatch(_ entries: [WatchPracticeEntry]) async {
        guard !entries.isEmpty else { return }
        guard let userId = AccountService.shared.currentUserId else { return }

        for entry in entries {
            let insert = PracticeSessionInsert(
                userId: userId,
                sessionDate: entry.sessionDate,
                practicedRange: entry.practicedRange,
                practicedChipping: entry.practicedChipping,
                practicedPutting: entry.practicedPutting,
                rangeBallsHit: entry.rangeBallsHit
            )
            do {
                let inserted = try await GolfLabData.store.insertPracticeSession(insert)
                upsertPracticeSession(inserted)
            } catch {
                continue
            }
        }
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

    /// When the `rounds` summary columns disagree with summed `holes`, update the store and the in-memory model.
    /// Uses whatever hole rows exist (even when count is below `round.holes`) so list totals match the scorecard table.
    private func reconcileStoredRoundTotals(
        rounds: [Round],
        holesByRoundId: [UUID: [Hole]]
    ) async -> [Round] {
        var updated = rounds
        for i in updated.indices {
            let round = updated[i]
            guard let holes = holesByRoundId[round.id], !holes.isEmpty else { continue }

            let agg = holes.aggregatedRoundTotals
            let matches = round.totalScore == agg.score
                && round.totalPutts == agg.putts
                && round.totalGir == agg.gir
                && round.totalFir == agg.fir
            if matches { continue }

            do {
                try await GolfLabData.store.updateRoundTotals(
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
    /// Per-hole Lamport revision. Independent of the phone snapshot counter.
    var revision: UInt64
    var editedAt: Date

    enum CodingKeys: String, CodingKey {
        case holeNumber, par, yardage, strokeIndex, score, putts, gir, fir, penalty, isSaved, revision, editedAt
    }

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
        self.revision    = 0
        self.editedAt    = .distantPast
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        holeNumber = try container.decode(Int.self, forKey: .holeNumber)
        par = try container.decode(Int.self, forKey: .par)
        yardage = try container.decodeIfPresent(Int.self, forKey: .yardage)
        strokeIndex = try container.decodeIfPresent(Int.self, forKey: .strokeIndex)
        score = try container.decode(Int.self, forKey: .score)
        putts = try container.decode(Int.self, forKey: .putts)
        gir = try container.decode(Bool.self, forKey: .gir)
        fir = try container.decodeIfPresent(Bool.self, forKey: .fir)
        penalty = try container.decode(Bool.self, forKey: .penalty)
        isSaved = try container.decode(Bool.self, forKey: .isSaved)
        revision = try container.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt) ?? .distantPast
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(holeNumber, forKey: .holeNumber)
        try container.encode(par, forKey: .par)
        try container.encodeIfPresent(yardage, forKey: .yardage)
        try container.encodeIfPresent(strokeIndex, forKey: .strokeIndex)
        try container.encode(score, forKey: .score)
        try container.encode(putts, forKey: .putts)
        try container.encode(gir, forKey: .gir)
        try container.encodeIfPresent(fir, forKey: .fir)
        try container.encode(penalty, forKey: .penalty)
        try container.encode(isSaved, forKey: .isSaved)
        try container.encode(revision, forKey: .revision)
        try container.encode(editedAt, forKey: .editedAt)
    }

    var version: HoleVersion {
        HoleVersion(holeNumber: holeNumber, isSaved: isSaved, revision: revision, editedAt: editedAt)
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
