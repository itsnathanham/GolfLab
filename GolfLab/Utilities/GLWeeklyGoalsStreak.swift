import Foundation

/// Weekly round + practice targets, current-week progress, and consecutive completed weeks (local calendar).
enum GLWeeklyGoalsStreak {
    struct Snapshot: Sendable, Equatable {
        /// `true` when at least one target is greater than zero.
        let hasActiveTargets: Bool
        let roundTarget: Int
        let practiceTarget: Int
        let roundsThisWeek: Int
        let practiceSessionsThisWeek: Int
        /// Both active requirements satisfied for the calendar week containing `now`.
        let currentWeekComplete: Bool
        /// Consecutive calendar weeks (including the current week when complete) meeting all active requirements.
        let completedWeeksStreak: Int
    }

    static func snapshot(
        now: Date = Date(),
        calendar: Calendar = .current,
        /// Latest targets (profile columns / `RoundStore`) — used for “this week” UI and as fallback when no revisions exist.
        roundTarget: Int,
        practiceTarget: Int,
        /// Per-week targets from profile; past weeks use `WeeklyGoalTargetRevision.targets(forWeekStartYMD:…)` so raising goals is not retroactive.
        goalRevisions: [WeeklyGoalTargetRevision],
        rounds: [Round],
        holeRowCountByRoundId: [UUID: Int],
        practiceSessions: [PracticeSession]
    ) -> Snapshot {
        let hasActiveTargets = roundTarget > 0 || practiceTarget > 0
        guard hasActiveTargets else {
            return Snapshot(
                hasActiveTargets: false,
                roundTarget: roundTarget,
                practiceTarget: practiceTarget,
                roundsThisWeek: 0,
                practiceSessionsThisWeek: 0,
                currentWeekComplete: false,
                completedWeeksStreak: 0
            )
        }

        func isCompletedRound(_ r: Round) -> Bool {
            guard r.holes > 0 else { return false }
            return (holeRowCountByRoundId[r.id] ?? 0) >= r.holes
        }

        func countRounds(startYMD: String, endYMD: String) -> Int {
            rounds.filter { isCompletedRound($0) && $0.datePlayedYMD >= startYMD && $0.datePlayedYMD <= endYMD }.count
        }

        func countPractice(startYMD: String, endYMD: String) -> Int {
            practiceSessions.filter { $0.sessionDate >= startYMD && $0.sessionDate <= endYMD }.count
        }

        func weekSatisfied(startYMD: String, endYMD: String, roundT: Int, practiceT: Int) -> Bool {
            let roundsOk = roundT <= 0 || countRounds(startYMD: startYMD, endYMD: endYMD) >= roundT
            let practiceOk = practiceT <= 0 || countPractice(startYMD: startYMD, endYMD: endYMD) >= practiceT
            return roundsOk && practiceOk
        }

        func boundsYMD(forWeekContaining date: Date) -> (start: String, end: String)? {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
            let start = GLCalendarISO.ymd(for: interval.start)
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            let end = GLCalendarISO.ymd(for: lastDay)
            return (start, end)
        }

        guard let thisBounds = boundsYMD(forWeekContaining: now) else {
            return Snapshot(
                hasActiveTargets: true,
                roundTarget: roundTarget,
                practiceTarget: practiceTarget,
                roundsThisWeek: 0,
                practiceSessionsThisWeek: 0,
                currentWeekComplete: false,
                completedWeeksStreak: 0
            )
        }

        let rThis = countRounds(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let pThis = countPractice(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let (curR, curP) = WeeklyGoalTargetRevision.targets(
            forWeekStartYMD: thisBounds.start,
            revisions: goalRevisions,
            fallbackRound: roundTarget,
            fallbackPractice: practiceTarget
        )
        let currentMet = weekSatisfied(startYMD: thisBounds.start, endYMD: thisBounds.end, roundT: curR, practiceT: curP)

        var streak = 0
        for weekOffset in 0..<520 {
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let b = boundsYMD(forWeekContaining: anchor)
            else { break }
            let (rT, pT) = WeeklyGoalTargetRevision.targets(
                forWeekStartYMD: b.start,
                revisions: goalRevisions,
                fallbackRound: roundTarget,
                fallbackPractice: practiceTarget
            )
            if weekSatisfied(startYMD: b.start, endYMD: b.end, roundT: rT, practiceT: pT) {
                streak += 1
            } else {
                break
            }
        }

        return Snapshot(
            hasActiveTargets: true,
            roundTarget: curR,
            practiceTarget: curP,
            roundsThisWeek: rThis,
            practiceSessionsThisWeek: pThis,
            currentWeekComplete: currentMet,
            completedWeeksStreak: streak
        )
    }
}
