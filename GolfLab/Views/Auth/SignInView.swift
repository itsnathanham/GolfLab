import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(.accent)

                    Text("Golf Lab")
                        .font(.glDisplay)
                        .foregroundColor(.textPrimary)

                    Text("Track your game. See the long arc.")
                        .font(.glBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.glSubhead)
                            .foregroundColor(.chartNegativeStrong)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    GLPrimaryCTACustomButton(
                        isEnabled: !isSigningIn,
                        isBusy: isSigningIn,
                        action: {
                            Task {
                                isSigningIn = true
                                await authService.signInWithApple()
                                isSigningIn = false
                            }
                        },
                        label: {
                            HStack(spacing: 8) {
                                if isSigningIn {
                                    ProgressView()
                                        .tint(.ctaOnAccent)
                                } else {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                Text(isSigningIn ? "Signing in…" : "Sign in with Apple")
                                    .font(.glButtonPrimary)
                                    .tracking(0.08 * 14)
                                    .textCase(.uppercase)
                            }
                        }
                    )
                    .padding(.horizontal, GLLayout.horizontalInset)

                    Text("Your data is private and stored securely.")
                        .font(.glCaption)
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)
            }
        }
    }
}
