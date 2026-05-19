import Foundation

/// One row of weekly goal targets; `effective_from` is the **calendar week start** (`yyyy-MM-dd`) when those targets apply through subsequent weeks until superseded.
struct WeeklyGoalTargetRevision: Codable, Equatable, Sendable, Identifiable {
    var id: String { effectiveFromYMD }

    let effectiveFromYMD: String
    let roundTarget: Int
    let practiceTarget: Int

    enum CodingKeys: String, CodingKey {
        case effectiveFromYMD = "effective_from"
        case roundTarget = "round_target"
        case practiceTarget = "practice_target"
    }

    static func sorted(_ rows: [WeeklyGoalTargetRevision]) -> [WeeklyGoalTargetRevision] {
        rows.sorted { $0.effectiveFromYMD < $1.effectiveFromYMD }
    }

    /// When `weekly_round_target` / `weekly_practice_target` disagree with revision-based targets for **this** week, treat the flat columns as canonical and upsert a revision for this week’s start so Home/History match Profile.
    static func revisionsAlignedWithFlatColumns(
        revisions: [WeeklyGoalTargetRevision]?,
        flatRound: Int,
        flatPractice: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeeklyGoalTargetRevision] {
        let sorted = sorted(revisions ?? [])
        guard let weekStart = weekStartYMD(containing: now, calendar: calendar) else {
            return sorted
        }
        let (revR, revP) = targets(
            forWeekStartYMD: weekStart,
            revisions: sorted,
            fallbackRound: flatRound,
            fallbackPractice: flatPractice
        )
        if revR == flatRound && revP == flatPractice { return sorted }
        var next = sorted
        next.removeAll { $0.effectiveFromYMD == weekStart }
        next.append(
            WeeklyGoalTargetRevision(
                effectiveFromYMD: weekStart,
                roundTarget: flatRound,
                practiceTarget: flatPractice
            )
        )
        return Self.sorted(next)
    }

    /// `yyyy-MM-dd` start of the calendar week containing `date` (same rules as streak evaluation).
    static func weekStartYMD(containing date: Date, calendar: Calendar = .current) -> String? {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        return GLCalendarISO.ymd(for: interval.start)
    }

    /// Targets that apply to a week whose **week start** is `weekStartYMD`. Uses the latest revision with `effective_from <= weekStartYMD`.
    /// If `weekStartYMD` is **before** the earliest revision (legacy rows with no baseline), uses that earliest revision so older weeks are not judged by *newer* flat profile values.
    static func targets(
        forWeekStartYMD weekStartYMD: String,
        revisions: [WeeklyGoalTargetRevision],
        fallbackRound: Int,
        fallbackPractice: Int
    ) -> (round: Int, practice: Int) {
        let sorted = Self.sorted(revisions)
        guard let first = sorted.first else {
            return (fallbackRound, fallbackPractice)
        }
        let best = sorted.last { $0.effectiveFromYMD <= weekStartYMD } ?? first
        return (best.roundTarget, best.practiceTarget)
    }

    /// When the user changes weekly targets, append a revision for **this calendar week** and keep prior weeks evaluated under older revisions.
    static func mergedAfterGoalChange(
        existing: [WeeklyGoalTargetRevision]?,
        savedRoundTarget: Int?,
        savedPracticeTarget: Int?,
        newRound: Int,
        newPractice: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeeklyGoalTargetRevision] {
        let oldR = savedRoundTarget ?? 1
        let oldP = savedPracticeTarget ?? 2
        if newRound == oldR, newPractice == oldP {
            return Self.sorted(existing ?? [])
        }

        var revs = Self.sorted(existing ?? [])
        if revs.isEmpty {
            revs.append(
                WeeklyGoalTargetRevision(
                    effectiveFromYMD: "1970-01-01",
                    roundTarget: oldR,
                    practiceTarget: oldP
                )
            )
        }
        guard let weekStart = weekStartYMD(containing: now, calendar: calendar) else {
            return revs
        }
        revs.removeAll { $0.effectiveFromYMD == weekStart }
        revs.append(
            WeeklyGoalTargetRevision(
                effectiveFromYMD: weekStart,
                roundTarget: newRound,
                practiceTarget: newPractice
            )
        )
        return Self.sorted(revs)
    }
}
