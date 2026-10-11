import SwiftUI

struct GLLoadingIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                statsBars
                    .frame(width: size * 0.5, height: size * 0.5)
                    .offset(x: size * 0.05)
                
                flagIcon
                    .frame(width: size * 0.35, height: size * 0.35)
                    .offset(x: -size * 0.05)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
    
    private var statsBars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accent)
                .frame(width: 6)
                .frame(height: isAnimating ? 20 : 12)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accent)
                .frame(width: 6)
                .frame(height: isAnimating ? 30 : 18)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accent)
                .frame(width: 6)
                .frame(height: isAnimating ? 40 : 24)
        }
    }
    
    private var flagIcon: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accent)
                .frame(width: 3, height: 45)
            
            Path { path in
                path.move(to: CGPoint(x: 3, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 6))
                path.addLine(to: CGPoint(x: 3, y: 12))
                path.closeSubpath()
            }
            .fill(Color.accent)
            .scaleEffect(isAnimating ? 1.0 : 0.85, anchor: .leading)
        }
    }
}
