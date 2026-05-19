import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String?
    var homeCourseName: String?
    var homeCourseTee: String?
    var preferredUnits: String
    /// Completed rounds per calendar week (see `GLWeeklyGoalsStreak`).
    var weeklyRoundTarget: Int?
    /// Logged practice sessions per calendar week.
    var weeklyPracticeTarget: Int?
    /// History of goal changes so streak math uses past targets, not only the latest (`WeeklyGoalTargetRevision`).
    var weeklyGoalTargetRevisions: [WeeklyGoalTargetRevision]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName    = "display_name"
        case homeCourseName = "home_course_name"
        case homeCourseTee  = "home_course_tee"
        case preferredUnits = "preferred_units"
        case weeklyRoundTarget = "weekly_round_target"
        case weeklyPracticeTarget = "weekly_practice_target"
        case weeklyGoalTargetRevisions = "weekly_goal_target_revisions"
    }
}

extension UserProfile {
    /// Targets for the **current** calendar week (revision-aware; same rules as `GLWeeklyGoalsStreak.snapshot`).
    func effectiveWeeklyTargetsThisWeek(now: Date = Date(), calendar: Calendar = .current) -> (round: Int, practice: Int) {
        let revs = WeeklyGoalTargetRevision.sorted(weeklyGoalTargetRevisions ?? [])
        let fbR = weeklyRoundTarget ?? 1
        let fbP = weeklyPracticeTarget ?? 2
        guard let weekStart = WeeklyGoalTargetRevision.weekStartYMD(containing: now, calendar: calendar) else {
            return (fbR, fbP)
        }
        let t = WeeklyGoalTargetRevision.targets(
            forWeekStartYMD: weekStart,
            revisions: revs,
            fallbackRound: fbR,
            fallbackPractice: fbP
        )
        return (t.round, t.practice)
    }

    /// Fills optional weekly fields from the values we attempted to save when PostgREST returns nulls (e.g. column not exposed to `select` for the anon role).
    func coalescingWeeklyPersistAttempt(
        requestedRound: Int?,
        requestedPractice: Int?,
        requestedRevisions: [WeeklyGoalTargetRevision]?
    ) -> UserProfile {
        UserProfile(
            id: id,
            displayName: displayName,
            homeCourseName: homeCourseName,
            homeCourseTee: homeCourseTee,
            preferredUnits: preferredUnits,
            weeklyRoundTarget: weeklyRoundTarget ?? requestedRound,
            weeklyPracticeTarget: weeklyPracticeTarget ?? requestedPractice,
            weeklyGoalTargetRevisions: weeklyGoalTargetRevisions ?? requestedRevisions
        )
    }
}
