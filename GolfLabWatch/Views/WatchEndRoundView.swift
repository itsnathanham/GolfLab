import SwiftUI
import WatchKit

struct WatchEndRoundView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("End Round?")
                .font(.headline)
                .foregroundColor(WatchPalette.textPrimary)

            let vs = session.scoreVsPar
            Text(vs == 0 ? "Even par" : (vs > 0 ? "+\(vs)" : "\(vs)"))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundColor(WatchPalette.accent)

            Text("\(session.holeEntries.count) holes logged")
                .font(.footnote)
                .foregroundColor(WatchPalette.textSecondary)

            Button("End & Save") {
                WKInterfaceDevice.current().play(.success)
                session.endRound()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchPalette.accent)

            Button("Keep Playing") {
                dismiss()
            }
            .foregroundColor(WatchPalette.textSecondary)
        }
        .padding(.horizontal, 8)
        .background(WatchPalette.bg)
    }
}
