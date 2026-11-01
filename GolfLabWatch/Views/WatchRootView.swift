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
                    onDismiss: { session.weeklyGoalCelebration = nil }
                )
            }
        }
    }
}

struct WatchIdleView: View {
    @EnvironmentObject private var session: WatchSessionService

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(WatchPalette.accent)
            Text("Golf Lab")
                .font(.headline)
                .foregroundColor(WatchPalette.textPrimary)
            Text(session.isWaitingForPhoneToSave
                 ? "Round is on this watch.\nOpen Golf Lab on your iPhone to keep it."
                 : "Start a round\non your iPhone")
                .font(.footnote)
                .foregroundColor(WatchPalette.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                WatchPracticeLogView()
            } label: {
                Text("Log practice")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchPalette.practice)
            .padding(.top, 4)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchPalette.bg)
    }
}
