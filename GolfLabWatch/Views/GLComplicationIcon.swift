import SwiftUI

struct GLComplicationIcon: View {
    var body: some View {
        ZStack {
            statsBars
                .frame(width: 10, height: 10)
                .offset(x: 2)
            
            flagIcon
                .frame(width: 8, height: 12)
                .offset(x: -2)
        }
    }
    
    private var statsBars: some View {
        HStack(alignment: .bottom, spacing: 1) {
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white)
                .frame(width: 2, height: 4)
            
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white)
                .frame(width: 2, height: 6)
            
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white)
                .frame(width: 2, height: 8)
        }
    }
    
    private var flagIcon: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white)
                .frame(width: 1.5, height: 12)
            
            Path { path in
                path.move(to: CGPoint(x: 1.5, y: 0))
                path.addLine(to: CGPoint(x: 7, y: 2))
                path.addLine(to: CGPoint(x: 1.5, y: 4))
                path.closeSubpath()
            }
            .fill(Color.white)
        }
    }
}
