import Foundation

/// Weekly goals completed for the current calendar week — presentation payload + persistence guard.
struct WeeklyGoalCelebrationPresentation: Equatable, Identifiable, Sendable {
    let id: UUID
    let weekStartYMD: String
    let completedWeeksStreak: Int
}

enum WeeklyGoalCelebration {
    private static let lastCelebratedWeekKey = "lastCelebratedWeeklyGoalWeekStartYMD"

    /// Current week transitioned from incomplete → complete.
    /// A harder goal that reopens this week clears the saved mark, so the next completion can celebrate again.
    static func presentationIfNewlyCompleted(
        before: GLWeeklyGoalsStreak.Snapshot,
        after: GLWeeklyGoalsStreak.Snapshot,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> WeeklyGoalCelebrationPresentation? {
        guard after.hasActiveTargets else { return nil }
        guard !before.currentWeekComplete, after.currentWeekComplete else { return nil }
        guard let weekStart = WeeklyGoalTargetRevision.weekStartYMD(containing: now, calendar: calendar) else {
            return nil
        }
        guard defaults.string(forKey: lastCelebratedWeekKey) != weekStart else { return nil }
        return WeeklyGoalCelebrationPresentation(
            id: UUID(),
            weekStartYMD: weekStart,
            completedWeeksStreak: after.completedWeeksStreak
        )
    }

    static func markCelebrated(weekStartYMD: String, defaults: UserDefaults = .standard) {
        defaults.set(weekStartYMD, forKey: lastCelebratedWeekKey)
    }

    /// True when a strictly harder target turns a finished week unfinished.
    /// Either count may stay the same. An easier target, the same numbers, or a mixed edit (one up, one down) does not qualify.
    static func shouldForgetCelebratedWeek(
        beforeComplete: Bool,
        afterComplete: Bool,
        beforeRoundTarget: Int,
        beforePracticeTarget: Int,
        afterRoundTarget: Int,
        afterPracticeTarget: Int
    ) -> Bool {
        guard beforeComplete, !afterComplete else { return false }
        let roundsNotLower = afterRoundTarget >= beforeRoundTarget
        let practiceNotLower = afterPracticeTarget >= beforePracticeTarget
        let stricter = afterRoundTarget > beforeRoundTarget || afterPracticeTarget > beforePracticeTarget
        return roundsNotLower && practiceNotLower && stricter
    }

    /// Drops this week's saved mark so the next incomplete → complete transition can celebrate.
    /// A mark for a different week is left alone.
    static func forgetCelebratedWeekIfCurrent(
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        guard let weekStart = WeeklyGoalTargetRevision.weekStartYMD(containing: now, calendar: calendar) else {
            return
        }
        guard defaults.string(forKey: lastCelebratedWeekKey) == weekStart else { return }
        defaults.removeObject(forKey: lastCelebratedWeekKey)
    }
}
