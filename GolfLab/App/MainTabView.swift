import CoreData
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @EnvironmentObject private var watchConnectivity: WatchConnectivityService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            RoundTabView()
                .tabItem { Label("Round", systemImage: "flag") }
                .tag(1)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(3)
        }
        .tint(Color.accent)
        .preferredColorScheme(.dark)
        .onChange(of: roundStore.isRoundActive) { _, isActive in
            if isActive {
                selectedTab = 1
            }
        }
        .onChange(of: watchConnectivity.receivedHoleEntriesRevision) { _, _ in
            roundStore.mergePendingWatchHoleEntries()
        }
        .onChange(of: watchConnectivity.receivedPracticeEntriesRevision) { _, _ in
            flushWatchPracticeEntries()
        }
        .onChange(of: watchConnectivity.isWatchReachable) { _, reachable in
            if reachable && roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
            }
            if roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onAppear {
            if roundStore.isRoundActive {
                selectedTab = 1
                roundStore.pushCompanionSnapshotToWatch()
            }
            flushWatchPracticeEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRequestedCompanionSync)) { _ in
            if roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task { await roundStore.loadRounds() }
        }
        .overlay {
            if let celebration = roundStore.weeklyGoalCelebration {
                WeeklyGoalCelebrationOverlay(
                    presentation: celebration,
                    onDismiss: { roundStore.dismissWeeklyGoalCelebration() }
                )
                .zIndex(1000)
            }
        }
    }

    private func flushWatchPracticeEntries() {
        Task {
            let entries = watchConnectivity.drainPendingPracticeEntries()
            guard !entries.isEmpty else { return }
            await roundStore.savePracticeSessionsFromWatch(entries)
            roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
        }
    }

}
