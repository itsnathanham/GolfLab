import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if session.isRoundActive {
                    WatchHoleEntryView()
                } else {
                    WatchIdleView()
                }
            }
        }
        .onAppear {
            session.requestCompanionSyncFromPhone()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                session.requestCompanionSyncFromPhone()
            }
        }
        .overlay {
            if let celebration = session.weeklyGoalCelebration {
                WatchWeeklyGoalCelebrationView(
                    completedWeeksStreak: celebration.completedWeeksStreak,
                    onDismiss: {
                        if session.weeklyGoalCelebration?.id == celebration.id {
                            session.weeklyGoalCelebration = nil
                        }
                    }
                )
                .id(celebration.id)
            }
        }
    }
}

struct WatchIdleView: View {
    @EnvironmentObject private var session: WatchSessionService

    private var week: WatchWeekSnapshot? { session.weekSnapshot }

    private var weekIsCurrent: Bool {
        guard let week else { return false }
        return week.weekStartYMD == GLCalendarISO.weekStartYMD()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Golf Lab")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(0.14 * 12)
                    .textCase(.uppercase)
                    .foregroundColor(WatchPalette.accent)

                Text("This week")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.08 * 10)
                    .textCase(.uppercase)
                    .foregroundColor(WatchPalette.textTertiary)

                if let week, week.hasActiveTargets {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        if week.roundTarget > 0 {
                            weekStat(
                                value: countText(current: week.roundsThisWeek, target: week.roundTarget),
                                label: "Rounds"
                            )
                        }
                        if week.practiceTarget > 0 {
                            weekStat(
                                value: countText(current: week.practiceSessionsThisWeek, target: week.practiceTarget),
                                label: "Practice"
                            )
                        }
                    }
                    if weekIsCurrent, week.completedWeeksStreak > 0 {
                        Text(streakLine(week.completedWeeksStreak))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WatchPalette.streakMark)
                    }
                }

                Text(hint)
                    .font(.system(size: 12))
                    .foregroundColor(WatchPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(WatchPalette.bg)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            NavigationLink {
                WatchPracticeLogView()
            } label: {
                Text("Log practice")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WatchPalette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
    }

    private var hint: String {
        if session.isWaitingForPhoneToSave {
            return "Round is on this watch.\nOpen Golf Lab on your iPhone to keep it."
        }
        return "iPhone → Start round"
    }

    private func countText(current: Int, target: Int) -> String {
        guard weekIsCurrent else { return "—" }
        return "\(current)/\(target)"
    }

    private func streakLine(_ weeks: Int) -> String {
        weeks == 1 ? "1 week streak" : "\(weeks) week streak"
    }

    private func weekStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(WatchPalette.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(WatchPalette.textTertiary)
        }
    }
}
