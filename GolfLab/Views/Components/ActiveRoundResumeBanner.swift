import SwiftUI

struct ActiveRoundResumeBanner: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var showDiscardConfirm = false

    var body: some View {
        if roundStore.didRestoreActiveRoundFromDraft, let round = roundStore.activeRound {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Round resumed")
                            .font(GLFonts.sans(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Your scorecard for \(round.setup.courseName) was restored after the app closed.")
                            .font(.glFootnote)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        roundStore.dismissRestoredRoundBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }

                Button("Discard round") {
                    showDiscardConfirm = true
                }
                .font(.glFootnote)
                .foregroundColor(.chartNegativeStrong)
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.accentDim)
            .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
            .padding(.horizontal, GLLayout.horizontalInset)
            .padding(.bottom, 12)
            .alert("Discard round?", isPresented: $showDiscardConfirm) {
                Button("Discard", role: .destructive) {
                    roundStore.discardActiveRound()
                }
                Button("Keep playing", role: .cancel) {}
            } message: {
                Text("This will delete your in-progress scorecard. Saved rounds in History are not affected.")
            }
        }
    }
}
