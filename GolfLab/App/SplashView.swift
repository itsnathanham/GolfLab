import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            GLLoadingIcon()
                .frame(width: 60, height: 60)
        }
    }
}
