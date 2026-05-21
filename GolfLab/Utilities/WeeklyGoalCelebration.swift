import Foundation

/// Weekly goals completed for the current calendar week — presentation payload + persistence guard.
struct WeeklyGoalCelebrationPresentation: Equatable, Identifiable, Sendable {
    let id: UUID
    let weekStartYMD: String
    let completedWeeksStreak: Int
}

enum WeeklyGoalCelebration {
    private static let lastCelebratedWeekKey = "lastCelebratedWeeklyGoalWeekStartYMD"

    /// Current week transitioned from incomplete → complete (v1: current week only via `currentWeekComplete`).
    static func presentationIfNewlyCompleted(
        before: GLWeeklyGoalsStreak.Snapshot,
        after: GLWeeklyGoalsStreak.Snapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyGoalCelebrationPresentation? {
        guard after.hasActiveTargets else { return nil }
        guard !before.currentWeekComplete, after.currentWeekComplete else { return nil }
        guard let weekStart = WeeklyGoalTargetRevision.weekStartYMD(containing: now, calendar: calendar) else {
            return nil
        }
        guard UserDefaults.standard.string(forKey: lastCelebratedWeekKey) != weekStart else { return nil }
        return WeeklyGoalCelebrationPresentation(
            id: UUID(),
            weekStartYMD: weekStart,
            completedWeeksStreak: after.completedWeeksStreak
        )
    }

    static func markCelebrated(weekStartYMD: String) {
        UserDefaults.standard.set(weekStartYMD, forKey: lastCelebratedWeekKey)
    }
}
