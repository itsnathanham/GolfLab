import SwiftUI

private struct GLTabSpec: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

struct MainTabView: View {
    @StateObject private var roundStore = RoundStore()
    @EnvironmentObject private var watchConnectivity: WatchConnectivityService
    @State private var selectedTab = 0

    private let tabs: [GLTabSpec] = [
        GLTabSpec(id: 0, title: "Home", icon: "house"),
        GLTabSpec(id: 1, title: "Round", icon: "flag"),
        GLTabSpec(id: 2, title: "Stats", icon: "chart.line.uptrend.xyaxis"),
        GLTabSpec(id: 3, title: "History", icon: "clock")
    ]

    var body: some View {
        Group {
            switch selectedTab {
            case 0: HomeView(selectedTab: $selectedTab)
            case 1: RoundTabView(selectedTab: $selectedTab)
            case 2: StatsView()
            case 3: HistoryView()
            default: HomeView(selectedTab: $selectedTab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                roundStore.pushActiveRoundStateToCompanion()
            }
        }
        .onAppear {
            if roundStore.isRoundActive {
                roundStore.pushActiveRoundStateToCompanion()
            }
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(tab: tab)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
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
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                Text(tab.title.uppercased())
                    .font(.glEyebrow)
                    .tracking(0.06 * 11)
                Circle()
                    .fill(Color.accent)
                    .frame(width: 3, height: 3)
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
