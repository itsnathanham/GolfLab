import SwiftUI
import WatchKit

/// Simplified celebration for Watch when weekly goals complete.
struct WatchWeeklyGoalCelebrationView: View {
    let completedWeeksStreak: Int
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var particlesVisible = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            if particlesVisible {
                WatchFireworkParticles()
            }
            
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
        .onTapGesture { onDismiss() }
        .onAppear {
            playCelebrationHaptics()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                particlesVisible = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onDismiss()
            }
        }
    }
    
    private var streakText: String {
        completedWeeksStreak == 1 ? "1 week" : "\(completedWeeksStreak) weeks"
    }
    
    private func playCelebrationHaptics() {
        WKInterfaceDevice.current().play(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WKInterfaceDevice.current().play(.start)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            WKInterfaceDevice.current().play(.stop)
        }
    }
}

/// Simple particle burst for Watch celebration.
private struct WatchFireworkParticles: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let colors: [Color] = [
            WatchPalette.streakSuccess,
            WatchPalette.accent,
            WatchPalette.streakSuccessDeep
        ]
        
        for i in 0..<20 {
            let angle = Double(i) * (2 * .pi / 20)
            let distance = CGFloat.random(in: 40...80)
            let endX = centerX + cos(angle) * distance
            let endY = centerY + sin(angle) * distance
            
            let particle = Particle(
                position: CGPoint(x: centerX, y: centerY),
                color: colors.randomElement() ?? WatchPalette.accent,
                size: CGFloat.random(in: 3...6),
                opacity: 1.0
            )
            particles.append(particle)
            
            withAnimation(.easeOut(duration: 0.8)) {
                particles[i].position = CGPoint(x: endX, y: endY)
            }
            
            withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                particles[i].opacity = 0
            }
        }
    }
    
    private struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        let color: Color
        let size: CGFloat
        var opacity: Double
    }
}
