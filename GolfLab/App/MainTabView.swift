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

    private let tabs: [GLTabSpec] = [
        GLTabSpec(id: 0, title: "Home", icon: "house"),
        GLTabSpec(id: 1, title: "Round", icon: "flag"),
        GLTabSpec(id: 2, title: "Stats", icon: "chart.line.uptrend.xyaxis"),
        GLTabSpec(id: 3, title: "History", icon: "clock"),
        GLTabSpec(id: 4, title: "AI", icon: "brain.head.profile")
    ]

    var body: some View {
        Group {
            switch selectedTab {
            case 0: tabRoot(HomeView(selectedTab: $selectedTab))
            case 1: tabRoot(RoundTabView(selectedTab: $selectedTab))
            case 2: tabRoot(StatsView())
            case 3: tabRoot(HistoryView())
            case 4: tabRoot(CoachView())
            default: tabRoot(HomeView(selectedTab: $selectedTab))
            }
        }
        .environmentObject(roundStore)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .onChange(of: roundStore.isRoundActive) { _, isActive in
            if isActive { selectedTab = 1 }
        }
        .onChange(of: watchConnectivity.receivedHoleEntriesRevision) { _, _ in
            roundStore.mergePendingWatchHoleEntries()
        }
        .onChange(of: watchConnectivity.isWatchReachable) { _, reachable in
            if reachable && roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onChange(of: scenePhase) { _, _ in
            if roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onAppear {
            if roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRequestedEndRound)) { _ in
            Task {
                await roundStore.saveActiveRoundFromWatchEndRequest()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRequestedCompanionSync)) { _ in
            if roundStore.isRoundActive {
                roundStore.pushCompanionSnapshotToWatch()
            }
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentMargins(.bottom, GLLayout.tabRootScrollBottomMargin, for: .scrollContent)
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
