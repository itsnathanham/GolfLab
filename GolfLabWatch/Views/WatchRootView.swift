import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if session.isRoundActive {
                WatchHoleEntryView()
            } else {
                WatchIdleView()
            }
        }
        .onAppear {
            session.requestCompanionSyncFromPhone()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.requestCompanionSyncFromPhone()
            }
        }
    }
}

struct WatchIdleView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(WatchPalette.accent)
            Text("Golf Lab")
                .font(.headline)
                .foregroundColor(WatchPalette.textPrimary)
            Text("Start a round\non your iPhone")
                .font(.footnote)
                .foregroundColor(WatchPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchPalette.bg)
    }
}
