import Foundation

/// Weekly round + practice targets, current-week progress, consecutive completed weeks, and per-week history (local calendar).
enum GLWeeklyGoalsStreak {
    enum WeekOutcome: Sendable, Equatable {
        case complete
        case missed
        case inProgress
    }

    struct WeekRecord: Sendable, Equatable, Identifiable {
        var id: String { weekStartYMD }
        /// 1-based label shown as W1, W2, …
        let weekNumber: Int
        let weekStartYMD: String
        let outcome: WeekOutcome
    }

    struct Snapshot: Sendable, Equatable {
        /// `true` when at least one target is greater than zero.
        let hasActiveTargets: Bool
        let roundTarget: Int
        let practiceTarget: Int
        let roundsThisWeek: Int
        let practiceSessionsThisWeek: Int
        let rangeBallsHitThisWeek: Int
        /// Both active requirements satisfied for the calendar week containing `now`.
        let currentWeekComplete: Bool
        /// Consecutive calendar weeks (including the current week when complete) meeting all active requirements.
        let completedWeeksStreak: Int
        /// Oldest → newest weeks since tracking anchor (W1 = first entry).
        let weekHistory: [WeekRecord]
    }

    private static let legacyRevisionSentinelYMD = "1970-01-01"
    private static let maxWeeks = 520

    static func snapshot(
        now: Date = Date(),
        calendar: Calendar = .current,
        roundTarget: Int,
        practiceTarget: Int,
        goalRevisions: [WeeklyGoalTargetRevision],
        rounds: [Round],
        holeRowCountByRoundId: [UUID: Int],
        practiceSessions: [PracticeSession]
    ) -> Snapshot {
        let hasActiveTargets = roundTarget > 0 || practiceTarget > 0
        guard hasActiveTargets else {
            return emptySnapshot(roundTarget: roundTarget, practiceTarget: practiceTarget)
        }

        let ctx = EvaluationContext(
            now: now,
            calendar: calendar,
            roundTarget: roundTarget,
            practiceTarget: practiceTarget,
            goalRevisions: goalRevisions,
            rounds: rounds,
            holeRowCountByRoundId: holeRowCountByRoundId,
            practiceSessions: practiceSessions
        )

        guard let thisBounds = ctx.boundsYMD(forWeekContaining: now) else {
            return Snapshot(
                hasActiveTargets: true,
                roundTarget: roundTarget,
                practiceTarget: practiceTarget,
                roundsThisWeek: 0,
                practiceSessionsThisWeek: 0,
                rangeBallsHitThisWeek: 0,
                currentWeekComplete: false,
                completedWeeksStreak: 0,
                weekHistory: []
            )
        }

        let rThis = ctx.countRounds(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let pThis = ctx.countPractice(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let rangeBallsThis = ctx.countRangeBallsHit(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let (curR, curP) = ctx.targets(forWeekStartYMD: thisBounds.start)
        let currentMet = ctx.weekSatisfied(startYMD: thisBounds.start, endYMD: thisBounds.end, roundT: curR, practiceT: curP)

        let anchorStart = trackingAnchorWeekStartYMD(context: ctx, currentWeekStartYMD: thisBounds.start)
        let weekStarts = weekStartsFromAnchor(anchorStartYMD: anchorStart, throughCurrentWeekStartYMD: thisBounds.start, calendar: calendar)
        let history: [WeekRecord] = weekStarts.enumerated().map { index, startYMD in
            let bounds = ctx.boundsYMD(forWeekStartYMD: startYMD) ?? (startYMD, startYMD)
            let (rT, pT) = ctx.targets(forWeekStartYMD: startYMD)
            let met = ctx.weekSatisfied(startYMD: bounds.start, endYMD: bounds.end, roundT: rT, practiceT: pT)
            let isCurrent = startYMD == thisBounds.start
            let outcome: WeekOutcome = if isCurrent {
                met ? .complete : .inProgress
            } else {
                met ? .complete : .missed
            }
            return WeekRecord(
                weekNumber: index + 1,
                weekStartYMD: startYMD,
                outcome: outcome
            )
        }

        var streak = 0
        for weekOffset in 0..<maxWeeks {
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let b = ctx.boundsYMD(forWeekContaining: anchor)
            else { break }
            let (rT, pT) = ctx.targets(forWeekStartYMD: b.start)
            if ctx.weekSatisfied(startYMD: b.start, endYMD: b.end, roundT: rT, practiceT: pT) {
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
            rangeBallsHitThisWeek: rangeBallsThis,
            currentWeekComplete: currentMet,
            completedWeeksStreak: streak,
            weekHistory: history
        )
    }

    // MARK: - Tracking anchor (W1)

    private static func trackingAnchorWeekStartYMD(
        context: EvaluationContext,
        currentWeekStartYMD: String
    ) -> String {
        let sorted = WeeklyGoalTargetRevision.sorted(context.goalRevisions)
        let dated = sorted.filter { $0.effectiveFromYMD != legacyRevisionSentinelYMD }
        if let earliest = dated.first?.effectiveFromYMD {
            return earliest
        }

        var activityWeekStarts: [String] = []
        for r in context.rounds where context.isCompletedRound(r) {
            if let w = context.weekStartYMD(forYMD: r.datePlayedYMD) {
                activityWeekStarts.append(w)
            }
        }
        for p in context.practiceSessions {
            if let w = context.weekStartYMD(forYMD: p.sessionDate) {
                activityWeekStarts.append(w)
            }
        }
        if let earliestActivity = activityWeekStarts.min() {
            return earliestActivity
        }

        return currentWeekStartYMD
    }

    private static func weekStartsFromAnchor(
        anchorStartYMD: String,
        throughCurrentWeekStartYMD currentStartYMD: String,
        calendar: Calendar
    ) -> [String] {
        guard let anchorDate = dateFromYMD(anchorStartYMD, calendar: calendar) else {
            return [currentStartYMD]
        }
        var starts: [String] = []
        for offset in 0..<maxWeeks {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: offset, to: anchorDate),
                  let bounds = weekBoundsYMD(forWeekContaining: weekDate, calendar: calendar)
            else { break }
            starts.append(bounds.start)
            if bounds.start >= currentStartYMD { break }
        }
        if starts.isEmpty { return [currentStartYMD] }
        return starts
    }

    // MARK: - Calendar helpers

    private static func dateFromYMD(_ ymd: String, calendar: Calendar) -> Date? {
        let head = String(ymd.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return calendar.date(from: dc)
    }

    private static func weekBoundsYMD(
        forWeekContaining date: Date,
        calendar: Calendar
    ) -> (start: String, end: String)? {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        let start = GLCalendarISO.ymd(for: interval.start)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let end = GLCalendarISO.ymd(for: lastDay)
        return (start, end)
    }

    private static func emptySnapshot(roundTarget: Int, practiceTarget: Int) -> Snapshot {
        Snapshot(
            hasActiveTargets: false,
            roundTarget: roundTarget,
            practiceTarget: practiceTarget,
            roundsThisWeek: 0,
            practiceSessionsThisWeek: 0,
            rangeBallsHitThisWeek: 0,
            currentWeekComplete: false,
            completedWeeksStreak: 0,
            weekHistory: []
        )
    }

    // MARK: - Evaluation

    private struct EvaluationContext {
        let now: Date
        let calendar: Calendar
        let roundTarget: Int
        let practiceTarget: Int
        let goalRevisions: [WeeklyGoalTargetRevision]
        let rounds: [Round]
        let holeRowCountByRoundId: [UUID: Int]
        let practiceSessions: [PracticeSession]

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

        func countRangeBallsHit(startYMD: String, endYMD: String) -> Int {
            practiceSessions
                .filter { $0.sessionDate >= startYMD && $0.sessionDate <= endYMD }
                .compactMap(\.loggedRangeBallsHit)
                .reduce(0, +)
        }

        func weekSatisfied(startYMD: String, endYMD: String, roundT: Int, practiceT: Int) -> Bool {
            let roundsOk = roundT <= 0 || countRounds(startYMD: startYMD, endYMD: endYMD) >= roundT
            let practiceOk = practiceT <= 0 || countPractice(startYMD: startYMD, endYMD: endYMD) >= practiceT
            return roundsOk && practiceOk
        }

        func boundsYMD(forWeekContaining date: Date) -> (start: String, end: String)? {
            GLWeeklyGoalsStreak.weekBoundsYMD(forWeekContaining: date, calendar: calendar)
        }

        func boundsYMD(forWeekStartYMD weekStartYMD: String) -> (start: String, end: String)? {
            guard let date = GLWeeklyGoalsStreak.dateFromYMD(weekStartYMD, calendar: calendar) else { return nil }
            return boundsYMD(forWeekContaining: date)
        }

        func targets(forWeekStartYMD weekStartYMD: String) -> (round: Int, practice: Int) {
            WeeklyGoalTargetRevision.targets(
                forWeekStartYMD: weekStartYMD,
                revisions: goalRevisions,
                fallbackRound: roundTarget,
                fallbackPractice: practiceTarget
            )
        }

        func weekStartYMD(forYMD ymd: String) -> String? {
            guard let date = GLWeeklyGoalsStreak.dateFromYMD(String(ymd.prefix(10)), calendar: calendar) else {
                return nil
            }
            return boundsYMD(forWeekContaining: date)?.start
        }
    }
}
