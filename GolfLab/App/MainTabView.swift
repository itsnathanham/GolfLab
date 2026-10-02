import CoreData
import SwiftUI

private struct GLTabSpec: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

struct MainTabView: View {
    @StateObject private var roundStore = RoundStore()
    @EnvironmentObject private var watchConnectivity: WatchConnectivityService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var loadedTabs: Set<Int> = [0]

    private let tabs: [GLTabSpec] = [
        GLTabSpec(id: 0, title: "Home", icon: "house"),
        GLTabSpec(id: 1, title: "Round", icon: "flag"),
        GLTabSpec(id: 2, title: "Stats", icon: "chart.line.uptrend.xyaxis"),
        GLTabSpec(id: 3, title: "History", icon: "clock"),
        GLTabSpec(id: 4, title: "AI", icon: "brain.head.profile")
    ]

    var body: some View {
        ZStack {
            if loadedTabs.contains(0) {
                persistedTab(0, HomeView(selectedTab: $selectedTab))
            }
            if loadedTabs.contains(1) {
                persistedTab(1, RoundTabView(selectedTab: $selectedTab))
            }
            if loadedTabs.contains(2) {
                persistedTab(2, StatsView())
            }
            if loadedTabs.contains(3) {
                persistedTab(3, HistoryView())
            }
            if loadedTabs.contains(4) {
                persistedTab(4, CoachView())
            }
        }
        .transaction { $0.animation = nil }
        .environmentObject(roundStore)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .onChange(of: selectedTab) { _, tab in
            loadedTabs.insert(tab)
        }
        .onChange(of: roundStore.isRoundActive) { _, isActive in
            if isActive {
                loadedTabs.insert(1)
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
                roundStore.pushCompanionSnapshotToWatch()
            }
            flushWatchPracticeEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRequestedEndRound)) { _ in
            Task {
                await roundStore.saveActiveRoundFromWatchEndRequest()
                roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
            }
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

    @ViewBuilder
    private func persistedTab<Content: View>(_ id: Int, _ content: Content) -> some View {
        tabRoot(content)
            .opacity(selectedTab == id ? 1 : 0)
            .allowsHitTesting(selectedTab == id)
            .accessibilityHidden(selectedTab != id)
            .zIndex(selectedTab == id ? 1 : 0)
    }

    @ViewBuilder
    private func tabRoot<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentMargins(.bottom, GLLayout.tabRootScrollBottomMargin, for: .scrollContent)
    }

    private func flushWatchPracticeEntries() {
        Task {
            let entries = watchConnectivity.drainPendingPracticeEntries()
            guard !entries.isEmpty else { return }
            await roundStore.savePracticeSessionsFromWatch(entries)
            roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: GLLayout.TabBar.borderHeight)
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(tab: tab)
                }
            }
            .padding(.top, GLLayout.TabBar.contentTopPadding)
            .padding(.bottom, GLLayout.TabBar.contentBottomPadding)
        }
        .frame(maxWidth: .infinity)
        .background {
            Color.cardBackground
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(tab: GLTabSpec) -> some View {
        let selected = selectedTab == tab.id
        return Button {
            loadedTabs.insert(tab.id)
            selectedTab = tab.id
        } label: {
            VStack(spacing: GLLayout.TabBar.itemSpacing) {
                Image(systemName: tab.icon)
                    .font(.system(size: GLLayout.TabBar.iconPointSize, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                Text(tab.title.uppercased())
                    .font(.glEyebrow)
                    .tracking(0.06 * 11)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Circle()
                    .fill(Color.accent)
                    .frame(width: GLLayout.TabBar.activeDotSize, height: GLLayout.TabBar.activeDotSize)
                    .opacity(selected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selected ? Color.accent : Color.black.opacity(0.3))
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityLabel(tab.title)
        }
        .buttonStyle(.plain)
    }
}
