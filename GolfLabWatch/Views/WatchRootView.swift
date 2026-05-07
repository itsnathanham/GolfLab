import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var session: WatchSessionService

    var body: some View {
        if session.isRoundActive {
            WatchHoleEntryView()
        } else {
            WatchIdleView()
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
