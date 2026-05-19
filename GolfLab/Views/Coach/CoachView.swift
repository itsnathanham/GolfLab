import SwiftUI

struct CoachView: View {
    private static let screenTitle = "AI Strategy Coach"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GLHubRootTopBar(screenTitle: Self.screenTitle)
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 14)

                    comingSoonContent
                        .padding(.horizontal, GLLayout.horizontalInset)
                }
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var comingSoonContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.accent)

            VStack(spacing: 8) {
                Text(Self.screenTitle)
                    .font(.glHeadline)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Personalized on-course strategy from your stats—built to help you score, not rebuild your swing.")
                    .font(.glBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            comingSoonBadge
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 8)
    }

    private var comingSoonBadge: some View {
        Text("Coming soon")
            .font(.glCaption)
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
            .tracking(0.08 * 12)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
    }
}
