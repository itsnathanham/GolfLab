import SwiftUI
import WatchKit

/// Watch celebration when weekly goals complete from a save made on this watch: two small golf-themed bursts behind a card.
struct WatchWeeklyGoalCelebrationView: View {
    let completedWeeksStreak: Int
    let onDismiss: () -> Void

    @State private var showContent = false

    private static let burstDelays: [TimeInterval] = [0.15, 0.75]
    private static let dismissAfter: TimeInterval = 3.2

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            WatchFireworkBurst(kind: .balls, origin: UnitPoint(x: 0.3, y: 0.72), delay: Self.burstDelays[0])
            WatchFireworkBurst(kind: .flags, origin: UnitPoint(x: 0.72, y: 0.3), delay: Self.burstDelays[1])

            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(WatchPalette.streakSuccess)

                Text("Goals complete!")
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
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            playCelebrationHaptics()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissAfter) {
                onDismiss()
            }
        }
    }

    private var streakText: String {
        completedWeeksStreak == 1 ? "1 week" : "\(completedWeeksStreak) weeks"
    }

    private func playCelebrationHaptics() {
        WKInterfaceDevice.current().play(.success)

        for delay in Self.burstDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                WKInterfaceDevice.current().play(.click)
            }
        }
    }
}

/// One burst: particles start at `origin`, fly outward, then drop and fade.
private struct WatchFireworkBurst: View {
    enum Kind {
        case balls
        case flags
    }

    let kind: Kind
    let origin: UnitPoint
    let delay: TimeInterval

    @State private var particles: [Particle] = []
    @State private var exploded = false
    @State private var faded = false

    private static let particleCount = 14

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width * origin.x, y: geo.size.height * origin.y)
            ZStack {
                ForEach(particles) { particle in
                    particleView(particle)
                        .position(
                            x: center.x + (exploded ? particle.offset.width : 0),
                            y: center.y + (exploded ? particle.offset.height : 0) + (faded ? 14 : 0)
                        )
                        .scaleEffect(exploded ? 1 : 0.3)
                        .opacity(faded ? 0 : 1)
                }
            }
            .onAppear {
                particles = Particle.make(count: Self.particleCount)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.55)) {
                        exploded = true
                    }
                    withAnimation(.easeIn(duration: 0.5).delay(0.45)) {
                        faded = true
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func particleView(_ particle: Particle) -> some View {
        switch kind {
        case .balls:
            Circle()
                .fill(particle.colorIndex == 0 ? WatchPalette.streakSuccessDeep : Color.white)
                .frame(width: particle.size, height: particle.size)
        case .flags:
            Image(systemName: "flag.fill")
                .font(.system(size: particle.size + 3, weight: .bold))
                .foregroundStyle(particle.colorIndex == 0 ? Color.white : WatchPalette.accent)
        }
    }

    private struct Particle: Identifiable {
        let id = UUID()
        /// Where the particle lands relative to the burst origin.
        let offset: CGSize
        let size: CGFloat
        let colorIndex: Int

        static func make(count: Int) -> [Particle] {
            (0..<count).map { index in
                let angle = Double(index) / Double(count) * 2 * Double.pi + Double.random(in: -0.18...0.18)
                let distance = Double.random(in: 34...62)
                return Particle(
                    offset: CGSize(width: cos(angle) * distance, height: sin(angle) * distance),
                    size: CGFloat.random(in: 4...7),
                    colorIndex: Int.random(in: 0..<3)
                )
            }
        }
    }
}
