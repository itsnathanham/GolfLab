import SwiftUI
import UIKit

/// App-root overlay when the current week newly completes all active weekly targets (`docs/design.md` § Weekly goals).
struct WeeklyGoalCelebrationOverlay: View {
    let presentation: WeeklyGoalCelebrationPresentation
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bannerVisible = false

    private let autoDismissSeconds: TimeInterval = 4.2

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            ConfettiEmitterView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                celebrationBanner
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, 12)
                    .opacity(bannerVisible ? 1 : 0)
                    .offset(y: bannerVisible ? 0 : -10)
                Spacer(minLength: 0)
            }
            .padding(.top, 52)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            playCelebrationHaptics()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                bannerVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissSeconds) {
                onDismiss()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var celebrationBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.streakSuccess)

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly goals complete")
                    .font(GLFonts.sans(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.glFootnote)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if presentation.completedWeeksStreak > 0 {
                    Text(streakLine)
                        .font(GLFonts.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Color.streakTextActive)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.streakSuccess.opacity(0.35), lineWidth: GLCardMetrics.strokeWidth)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
    }

    private var subtitle: String { Self.targetsMetSubtitle }

    private var streakLine: String {
        Self.streakLineLabel(weeks: presentation.completedWeeksStreak)
    }

    private static let targetsMetSubtitle = "You hit your rounds and practice targets this week."

    private static func streakLineLabel(weeks: Int) -> String {
        weeks == 1 ? "1 week streak" : "\(weeks) week streak"
    }

    private var accessibilityLabel: String {
        var parts = ["Weekly goals complete.", subtitle]
        if presentation.completedWeeksStreak > 0 {
            parts.append(streakLine)
        }
        if reduceMotion {
            parts.append("Confetti animations are off.")
        }
        return parts.joined(separator: " ")
    }

    private func playCelebrationHaptics() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
