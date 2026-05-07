import SwiftUI

/// Accent-bar hole header used on the round screen and history hole edit (docs/design.md accent panel).
struct HoleMetaHeaderCard<Trailing: View>: View {
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    @ViewBuilder private let trailing: () -> Trailing

    init(
        holeNumber: Int,
        par: Int,
        yardage: Int?,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.holeNumber = holeNumber
        self.par = par
        self.yardage = yardage
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Rectangle()
                .fill(Color.accent.opacity(0.6))
                .frame(width: 3)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("HOLE")
                            .font(.glCaption)
                            .foregroundColor(.textTertiary)
                            .tracking(0.10 * 12)
                            .textCase(.uppercase)
                        Text("\(holeNumber)")
                            .font(GLFonts.mono(size: 12, weight: .semibold))
                            .foregroundColor(.textTertiary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Par")
                            .font(GLFonts.sans(size: 22, weight: .semibold))
                        Text("\(par)")
                            .font(GLFonts.mono(size: 22, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    if let yardage {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(yardage)")
                                .font(GLFonts.mono(size: 14, weight: .medium))
                            Text("yds")
                                .font(.glSubhead)
                        }
                        .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
                trailing()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, GLCardMetrics.padding)
        }
        .background(Color.cardBackground)
        .cornerRadius(GLCardMetrics.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }
}
