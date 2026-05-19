import SwiftUI

/// Home + History: weekly round/practice targets, progress, streak (driven by `RoundStore` + profile-backed targets).
struct WeeklyGoalsStreakSection: View {
    @EnvironmentObject private var roundStore: RoundStore

    var body: some View {
        let snap = GLWeeklyGoalsStreak.snapshot(
            roundTarget: roundStore.weeklyRoundTarget,
            practiceTarget: roundStore.weeklyPracticeTarget,
            goalRevisions: roundStore.weeklyGoalTargetRevisions,
            rounds: roundStore.allRounds,
            holeRowCountByRoundId: roundStore.holeRowCountByRoundId,
            practiceSessions: roundStore.allPracticeSessions
        )

        VStack(alignment: .leading, spacing: 0) {
            GLTrendCardHeader(title: "Weekly goals")

            VStack(alignment: .leading, spacing: 14) {
                if snap.hasActiveTargets {
                    statusRow(snap: snap)
                    progressRow(
                        label: "Rounds",
                        current: snap.roundsThisWeek,
                        target: snap.roundTarget,
                        active: snap.roundTarget > 0
                    )
                    progressRow(
                        label: "Practice",
                        current: snap.practiceSessionsThisWeek,
                        target: snap.practiceTarget,
                        active: snap.practiceTarget > 0
                    )
                    streakFooter(snap: snap)
                } else {
                    Text("Set how many completed rounds and practice logs you want each week in Profile — we’ll track your streak here.")
                        .font(.glFootnote)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .padding(.top, 12)
            .padding(.bottom, GLCardMetrics.padding)
        }
        .glCardChromeFrame(outlined: true)
    }

    @ViewBuilder
    private func statusRow(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("This week")
                .font(.glSubhead)
                .foregroundColor(.textPrimary)
            Spacer()
            if snap.currentWeekComplete {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accent)
                    Text("Complete")
                        .font(GLFonts.mono(size: 13, weight: .semibold))
                        .foregroundColor(.accent)
                }
            } else {
                Text("In progress")
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func progressRow(label: String, current: Int, target: Int, active: Bool) -> some View {
        if active {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.glFootnote)
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text("\(current) / \(target)")
                        .font(GLFonts.mono(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                GeometryReader { geo in
                    let t = max(target, 1)
                    let frac = min(1, CGFloat(current) / CGFloat(t))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.bgElevated)
                            .frame(height: 5)
                        Capsule()
                            .fill(Color.accent.opacity(0.45))
                            .frame(width: max(4, geo.size.width * frac), height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func streakFooter(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(snap.completedWeeksStreak > 0 ? .accent : .textTertiary)
            Text(streakCaption(snap))
                .font(.glFootnote)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 2)
    }

    private func streakCaption(_ snap: GLWeeklyGoalsStreak.Snapshot) -> String {
        let n = snap.completedWeeksStreak
        if n == 0 {
            return "Hit both goals this week to grow your streak."
        }
        if n == 1 {
            return "1 week streak — keep it going."
        }
        return "\(n) week streak — keep it going."
    }
}
