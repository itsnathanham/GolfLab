import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.accent)
        }
    }
}
