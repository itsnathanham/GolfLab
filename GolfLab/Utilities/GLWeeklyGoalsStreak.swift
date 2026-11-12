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
        /// Latest mark while a freeze is on. The pin comes back when the freeze ends.
        var showsFreezeMark: Bool = false
    }

    /// One off-season pause. The locked week stays in the row. Calendar weeks after it,
    /// up to but not including the week the freeze is turned off, are not streak weeks.
    struct FreezeSpan: Codable, Equatable, Identifiable, Sendable {
        var id: UUID
        var lockedWeekStartYMD: String
        /// Goals were already met when the freeze was turned on.
        var lockedComplete: Bool
        /// Nil while the freeze is still on. The calendar week it was turned off.
        var resumedWeekStartYMD: String?

        var isActive: Bool { resumedWeekStartYMD == nil }
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
        /// Consecutive met weeks. An open current week does not add and does not break the run.
        /// A freeze-locked miss does not break it either. A finished week that was actually missed does.
        let completedWeeksStreak: Int
        /// Oldest → newest weeks since tracking anchor (W1 = first entry). Frozen gaps are omitted.
        let weekHistory: [WeekRecord]
        /// A freeze is on. The latest history mark is the snowflake.
        let isFrozen: Bool
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
        practiceSessions: [PracticeSession],
        freezes: [FreezeSpan] = []
    ) -> Snapshot {
        let hasActiveTargets = roundTarget > 0 || practiceTarget > 0
        guard hasActiveTargets else {
            return emptySnapshot(roundTarget: roundTarget, practiceTarget: practiceTarget)
        }

        let freezes = normalizedFreezes(freezes)
        let activeFreeze = freezes.first { $0.isActive }

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
                weekHistory: [],
                isFrozen: activeFreeze != nil
            )
        }

        let rThis = ctx.countRounds(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let pThis = ctx.countPractice(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let rangeBallsThis = ctx.countRangeBallsHit(startYMD: thisBounds.start, endYMD: thisBounds.end)
        let (curR, curP) = ctx.targets(forWeekStartYMD: thisBounds.start)
        let currentMet = ctx.weekSatisfied(startYMD: thisBounds.start, endYMD: thisBounds.end, roundT: curR, practiceT: curP)

        let anchorStart = trackingAnchorWeekStartYMD(context: ctx, currentWeekStartYMD: thisBounds.start)
        let weekStarts = weekStartsFromAnchor(anchorStartYMD: anchorStart, throughCurrentWeekStartYMD: thisBounds.start, calendar: calendar)
        let visibleStarts = weekStarts.filter { !isFrozenGap($0, spans: freezes) }
        let history: [WeekRecord] = visibleStarts.enumerated().map { index, startYMD in
            let bounds = ctx.boundsYMD(forWeekStartYMD: startYMD) ?? (startYMD, startYMD)
            let (rT, pT) = ctx.targets(forWeekStartYMD: startYMD)
            let met = ctx.weekSatisfied(startYMD: bounds.start, endYMD: bounds.end, roundT: rT, practiceT: pT)
            let locked = freezes.first { $0.lockedWeekStartYMD == startYMD }
            let outcome: WeekOutcome
            if let locked {
                outcome = locked.lockedComplete ? .complete : .missed
            } else if startYMD == thisBounds.start {
                outcome = met ? .complete : .inProgress
            } else {
                outcome = met ? .complete : .missed
            }
            return WeekRecord(
                weekNumber: index + 1,
                weekStartYMD: startYMD,
                outcome: outcome,
                showsFreezeMark: activeFreeze?.lockedWeekStartYMD == startYMD
            )
        }

        let streak = completedStreak(
            history: history,
            currentWeekStartYMD: thisBounds.start,
            freezes: freezes
        )

        return Snapshot(
            hasActiveTargets: true,
            roundTarget: curR,
            practiceTarget: curP,
            roundsThisWeek: rThis,
            practiceSessionsThisWeek: pThis,
            rangeBallsHitThisWeek: rangeBallsThis,
            currentWeekComplete: activeFreeze == nil && currentMet,
            completedWeeksStreak: streak,
            weekHistory: history,
            isFrozen: activeFreeze != nil
        )
    }

    /// Turns a freeze on or off. Turning it off in the same week removes the span.
    static func freezesBySetting(
        frozen: Bool,
        existing: [FreezeSpan],
        currentWeekStartYMD: String,
        currentWeekComplete: Bool
    ) -> [FreezeSpan] {
        var spans = normalizedFreezes(existing)
        if frozen {
            guard !spans.contains(where: \.isActive) else { return spans }
            spans.append(
                FreezeSpan(
                    id: UUID(),
                    lockedWeekStartYMD: currentWeekStartYMD,
                    lockedComplete: currentWeekComplete,
                    resumedWeekStartYMD: nil
                )
            )
            return spans
        }
        guard let index = spans.lastIndex(where: \.isActive) else { return spans }
        if spans[index].lockedWeekStartYMD == currentWeekStartYMD {
            spans.remove(at: index)
            return spans
        }
        spans[index].resumedWeekStartYMD = currentWeekStartYMD
        return spans
    }

    private static func normalizedFreezes(_ freezes: [FreezeSpan]) -> [FreezeSpan] {
        freezes.sorted { $0.lockedWeekStartYMD < $1.lockedWeekStartYMD }
    }

    /// Calendar weeks strictly after a locked week and before that freeze resumes are not streak weeks.
    private static func isFrozenGap(_ weekStartYMD: String, spans: [FreezeSpan]) -> Bool {
        for span in spans {
            guard weekStartYMD > span.lockedWeekStartYMD else { continue }
            if let resumed = span.resumedWeekStartYMD {
                if weekStartYMD < resumed { return true }
            } else {
                return true
            }
        }
        return false
    }

    private static func completedStreak(
        history: [WeekRecord],
        currentWeekStartYMD: String,
        freezes: [FreezeSpan]
    ) -> Int {
        let lockedMisses = Set(freezes.filter { !$0.lockedComplete }.map(\.lockedWeekStartYMD))
        var weeks = Array(history.reversed())
        if let newest = weeks.first,
           newest.weekStartYMD == currentWeekStartYMD,
           newest.outcome == .inProgress {
            weeks.removeFirst()
        }
        var streak = 0
        for week in weeks {
            switch week.outcome {
            case .complete:
                streak += 1
            case .missed, .inProgress:
                if lockedMisses.contains(week.weekStartYMD) {
                    continue
                }
                return streak
            }
        }
        return streak
    }

    // MARK: - Tracking anchor (W1)

    /// Earliest week the flagstick row should show.
    /// A goal edit stores the new targets on this week and the previous targets on a 1970 sentinel.
    /// That dated row is not when tracking started, so older rounds and practice still open the row.
    private static func trackingAnchorWeekStartYMD(
        context: EvaluationContext,
        currentWeekStartYMD: String
    ) -> String {
        let sorted = WeeklyGoalTargetRevision.sorted(context.goalRevisions)
        let dated = sorted.filter { $0.effectiveFromYMD != legacyRevisionSentinelYMD }

        var candidates: [String] = []
        if let earliestRevision = dated.first?.effectiveFromYMD {
            candidates.append(earliestRevision)
        }
        for round in context.rounds where context.isCompletedRound(round) {
            if let week = context.weekStartYMD(forYMD: round.datePlayedYMD) {
                candidates.append(week)
            }
        }
        for session in context.practiceSessions {
            if let week = context.weekStartYMD(forYMD: session.sessionDate) {
                candidates.append(week)
            }
        }
        return candidates.min() ?? currentWeekStartYMD
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
            weekHistory: [],
            isFrozen: false
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

    // MARK: - Week detail (summary sheet)

    struct WeekDetail: Sendable {
        let weekNumber: Int
        let weekStartYMD: String
        let weekEndYMD: String
        let outcome: WeekOutcome
        let roundTarget: Int
        let practiceTarget: Int
        /// All rounds in the week (including incomplete) for history navigation.
        let rounds: [Round]
        let practices: [PracticeSession]
        let rangeBallsHit: Int
        /// Oldest → newest, typically a short window ending at (or including) this week.
        let rangeBallsByWeek: [WeekBalls]
        /// Completed rounds only — drives the goals meter.
        let completedRoundCount: Int
    }

    struct WeekBalls: Sendable, Equatable, Identifiable {
        var id: String { weekStartYMD }
        let weekNumber: Int
        let weekStartYMD: String
        let balls: Int
    }

    static func weekDetail(
        week: WeekRecord,
        history: [WeekRecord],
        calendar: Calendar = .current,
        roundTarget: Int,
        practiceTarget: Int,
        goalRevisions: [WeeklyGoalTargetRevision],
        rounds: [Round],
        holeRowCountByRoundId: [UUID: Int],
        practiceSessions: [PracticeSession],
        chartWindow: Int = 6
    ) -> WeekDetail? {
        let ctx = EvaluationContext(
            now: Date(),
            calendar: calendar,
            roundTarget: roundTarget,
            practiceTarget: practiceTarget,
            goalRevisions: goalRevisions,
            rounds: rounds,
            holeRowCountByRoundId: holeRowCountByRoundId,
            practiceSessions: practiceSessions
        )
        guard let bounds = ctx.boundsYMD(forWeekStartYMD: week.weekStartYMD) else { return nil }
        let (rT, pT) = ctx.targets(forWeekStartYMD: week.weekStartYMD)
        let weekRounds = rounds
            .filter { $0.datePlayedYMD >= bounds.start && $0.datePlayedYMD <= bounds.end }
            .sortedByDatePlayedDescending()
        let completedRoundCount = weekRounds.filter { ctx.isCompletedRound($0) }.count
        let weekPractices = PracticeSession.sortedForDisplay(
            practiceSessions.filter { $0.sessionDate >= bounds.start && $0.sessionDate <= bounds.end }
        )
        let balls = ctx.countRangeBallsHit(startYMD: bounds.start, endYMD: bounds.end)

        let span = max(chartWindow, 1)
        let window: [WeekRecord]
        if let idx = history.firstIndex(where: { $0.weekStartYMD == week.weekStartYMD }) {
            let startIdx = max(0, idx - (span - 1))
            window = Array(history[startIdx...idx])
        } else {
            window = [week]
        }
        let chart: [WeekBalls] = window.map { record in
            let b = ctx.boundsYMD(forWeekStartYMD: record.weekStartYMD) ?? (record.weekStartYMD, record.weekStartYMD)
            return WeekBalls(
                weekNumber: record.weekNumber,
                weekStartYMD: record.weekStartYMD,
                balls: ctx.countRangeBallsHit(startYMD: b.start, endYMD: b.end)
            )
        }

        return WeekDetail(
            weekNumber: week.weekNumber,
            weekStartYMD: bounds.start,
            weekEndYMD: bounds.end,
            outcome: week.outcome,
            roundTarget: rT,
            practiceTarget: pT,
            rounds: weekRounds,
            practices: weekPractices,
            rangeBallsHit: balls,
            rangeBallsByWeek: chart,
            completedRoundCount: completedRoundCount
        )
    }

    /// Streak week label (`W12`) for a calendar day, when that week is in `history`.
    static func weekNumber(containingYMD ymd: String, history: [WeekRecord], calendar: Calendar = .current) -> Int? {
        guard let date = dateFromYMD(ymd, calendar: calendar),
              let bounds = weekBoundsYMD(forWeekContaining: date, calendar: calendar)
        else { return nil }
        return history.first { $0.weekStartYMD == bounds.start }?.weekNumber
    }

    static func dateRangeDisplay(startYMD: String, endYMD: String, calendar: Calendar = .current) -> String {
        guard let start = dateFromYMD(startYMD, calendar: calendar),
              let end = dateFromYMD(endYMD, calendar: calendar)
        else {
            return "\(GLCalendarISO.mmddyyyyDisplay(from: startYMD)) – \(GLCalendarISO.mmddyyyyDisplay(from: endYMD))"
        }
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return "\(df.string(from: start)) – \(df.string(from: end))"
    }
}
