import CoreData
import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @EnvironmentObject private var watchConnectivity: WatchConnectivityService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var keyboardVisible = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .modifier(GLCompactTabBarInset(selectedTab: $selectedTab, keyboardVisible: keyboardVisible))
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            RoundTabView()
                .modifier(GLCompactTabBarInset(selectedTab: $selectedTab, keyboardVisible: keyboardVisible))
                .tabItem { Label("Round", systemImage: "flag") }
                .tag(1)
            StatsView()
                .modifier(GLCompactTabBarInset(selectedTab: $selectedTab, keyboardVisible: keyboardVisible))
                .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            HistoryView()
                .modifier(GLCompactTabBarInset(selectedTab: $selectedTab, keyboardVisible: keyboardVisible))
                .tabItem { Label("History", systemImage: "clock") }
                .tag(3)
        }
        .tint(Color.accent)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .tabBar)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
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

private struct GLCompactTabBarInset: ViewModifier {
    @Binding var selectedTab: Int
    var keyboardVisible: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !keyboardVisible {
                    GLCompactTabBar(selectedTab: $selectedTab)
                }
            }
            .toolbar(.hidden, for: .tabBar)
    }
}

private struct GLCompactTabBar: View {
    @Binding var selectedTab: Int

    private let items: [Item] = [
        Item(id: 0, title: "Home", symbol: "house"),
        Item(id: 1, title: "Round", symbol: "flag"),
        Item(id: 2, title: "Stats", symbol: "chart.line.uptrend.xyaxis"),
        Item(id: 3, title: "History", symbol: "clock")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .background(Color.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ item: Item) -> some View {
        let selected = selectedTab == item.id
        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 1) {
                Image(systemName: item.symbol)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .frame(height: 13)
                Text(item.title)
                    .font(GLFonts.sans(size: 9, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(selected ? Color.accent : Color.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
        .accessibilityRemoveTraits(selected ? AccessibilityTraits() : .isSelected)
    }

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let symbol: String
    }
}
