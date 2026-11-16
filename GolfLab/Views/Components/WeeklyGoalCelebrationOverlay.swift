import SwiftUI
import UIKit

/// App-root overlay when the current week newly completes all active weekly targets (`docs/design.md` § Weekly goals).
/// Flag bloom: ambient fireworks first, then the card bursts out of the last shell with the flag fan.
struct WeeklyGoalCelebrationOverlay: View {
    let presentation: WeeklyGoalCelebrationPresentation
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardShown = false
    @State private var cardExpanded = false
    /// Window coordinates of the card. The flag shell breaks here, and the card scales from that center.
    @State private var cardCenter: CGPoint?

    /// Lets the last burst fade before the overlay goes away.
    private let autoDismissSeconds: TimeInterval = GolfFireworkEmitterView.showDuration

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            GolfFireworkEmitterView(bloomCenter: cardCenter, onBloom: { revealCard(animated: true) })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                celebrationBanner
                    .background {
                        GeometryReader { geo in
                            let frame = geo.frame(in: .global)
                            let center = frame.width > 40 && frame.height > 20
                                ? CGPoint(x: frame.midX, y: frame.midY)
                                : nil
                            Color.clear.preference(key: CelebrationCardCenterKey.self, value: center)
                        }
                    }
                    .opacity(cardShown ? 1 : 0)
                    .animation(nil, value: cardShown)
                    .scaleEffect(cardExpanded ? 1 : 0.04, anchor: .center)
                    .animation(.easeOut(duration: 0.42), value: cardExpanded)
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .padding(.top, 52)
            .onPreferenceChange(CelebrationCardCenterKey.self) { cardCenter = $0 }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            playCelebrationHaptics()
            if reduceMotion {
                revealCard(animated: false)
            } else {
                // The bloom callback is the real cue. This only covers a shell that never launched.
                DispatchQueue.main.asyncAfter(deadline: .now() + GolfFireworkEmitterView.cardRevealTime + 0.2) {
                    revealCard(animated: true)
                }
            }
            let hold = reduceMotion ? 4.5 : autoDismissSeconds
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                onDismiss()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var celebrationBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.bgElevated)
                    .frame(width: 36, height: 36)
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.streakMark)
            }

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
                .stroke(Color.streakCardBorder, lineWidth: GLCardMetrics.strokeWidth)
        )
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
            parts.append("Firework animations are off.")
        }
        return parts.joined(separator: " ")
    }

    /// Snaps in at the break and eases out with the flags, from the same center the shell hits.
    private func revealCard(animated: Bool) {
        guard !cardExpanded else { return }
        cardShown = true
        if animated {
            cardExpanded = true
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                cardExpanded = true
            }
        }
    }

    /// `.success` on appear, a light tap as each shell launches, and a medium thump on each burst.
    private func playCelebrationHaptics() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard !reduceMotion else { return }

        let launchTap = UIImpactFeedbackGenerator(style: .light)
        let burstThump = UIImpactFeedbackGenerator(style: .medium)
        launchTap.prepare()
        burstThump.prepare()

        for (launch, burst) in zip(GolfFireworkEmitterView.launchDelays, GolfFireworkEmitterView.burstTimes) {
            DispatchQueue.main.asyncAfter(deadline: .now() + launch) {
                launchTap.impactOccurred(intensity: 0.6)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + burst) {
                burstThump.impactOccurred()
                burstThump.prepare()
            }
        }
    }
}

/// Window-space center of the celebration card, measured from its layout frame (scale does not move it).
private struct CelebrationCardCenterKey: PreferenceKey {
    static var defaultValue: CGPoint?
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}
