import SwiftUI
import WatchKit

/// Watch celebration when weekly goals complete from a save made on this watch.
/// Flag bloom (lean): one center fan of orange and white flags reveals the card. No ambient shells.
struct WatchWeeklyGoalCelebrationView: View {
    let completedWeeksStreak: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false

    /// Flags fan, then the card opens out of that bloom.
    private static let bloomDelay: TimeInterval = 0.2
    private static let cardDelay: TimeInterval = 0.38
    private static let dismissAfter: TimeInterval = 3.1

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            if !reduceMotion {
                WatchFlagBloom(
                    origin: UnitPoint(x: 0.5, y: 0.5),
                    delay: Self.bloomDelay
                )
            }

            VStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WatchPalette.streakMark)

                Text("Goals met")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WatchPalette.textPrimary)

                if completedWeeksStreak > 0 {
                    Text(streakText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(WatchPalette.streakActive)
                }
            }
            .padding(12)
            .background(WatchPalette.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WatchPalette.streakMark.opacity(0.40), lineWidth: 1)
            )
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.4)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            playCelebrationHaptics()
            let delay: TimeInterval = reduceMotion ? 0 : Self.cardDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                    showContent = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissAfter) {
                onDismiss()
            }
        }
    }

    private var streakText: String {
        completedWeeksStreak == 1 ? "1 week streak" : "\(completedWeeksStreak) week streak"
    }

    private func playCelebrationHaptics() {
        WKInterfaceDevice.current().play(.success)

        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.bloomDelay) {
            WKInterfaceDevice.current().play(.click)
        }
    }
}

/// Orange and white flags fan from `origin`, hold, then fade as the card opens.
private struct WatchFlagBloom: View {
    let origin: UnitPoint
    let delay: TimeInterval

    @State private var flags: [BloomFlag] = []
    @State private var opened = false
    @State private var faded = false

    private static let flagCount = 8

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width * origin.x, y: geo.size.height * origin.y)
            ZStack {
                ForEach(flags) { flag in
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(flag.orange ? WatchPalette.streakMark : Color.white)
                        .rotationEffect(.radians(flag.angle))
                        .scaleEffect(opened ? 1 : 0.3)
                        .opacity(faded ? 0 : 1)
                        .position(
                            x: center.x + (opened ? flag.offset.width : 0),
                            y: center.y + (opened ? flag.offset.height : 0)
                        )
                }
            }
            .onAppear {
                flags = BloomFlag.make(count: Self.flagCount)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.42)) {
                        opened = true
                    }
                    withAnimation(.easeIn(duration: 0.45).delay(0.32)) {
                        faded = true
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private struct BloomFlag: Identifiable {
        let id = UUID()
        let angle: Double
        let offset: CGSize
        let orange: Bool

        static func make(count: Int) -> [BloomFlag] {
            (0..<count).map { index in
                let angle = Double(index) / Double(count) * 2 * Double.pi
                let distance = 40 + Double(index % 3) * 10
                return BloomFlag(
                    angle: angle,
                    offset: CGSize(width: cos(angle) * distance, height: sin(angle) * distance),
                    orange: index.isMultiple(of: 2)
                )
            }
        }
    }
}
