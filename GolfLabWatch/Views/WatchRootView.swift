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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.requestCompanionSyncFromPhone()
            }
        }
    }
}

struct WatchIdleView: View {
    var body: some View {
        VStack(spacing: 14) {
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
