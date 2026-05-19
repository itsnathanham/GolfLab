import SwiftUI

// Manages which Round sub-screen is visible
struct RoundTabView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            if roundStore.isRoundActive {
                VStack(spacing: 0) {
                    ActiveRoundResumeBanner()
                    HoleEntryView()
                }
            } else if roundStore.preferNewRoundSetup || roundStore.allRounds.isEmpty {
                RoundSetupView()
            } else {
                LastRoundSummaryView(selectedTab: $selectedTab)
            }
        }
    }
}
