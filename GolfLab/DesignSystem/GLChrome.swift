import SwiftUI

// Shared top bars and hub chrome (`docs/design.md`).

enum GLTopBarMetrics {
    /// Balanced leading / trailing slot (scorecard-style nav).
    static let sideSlotWidth: CGFloat = 72
    static let sheetTopPadding: CGFloat = 18
    /// Extra space below the sheet grabber / first chrome row (used with `sheetTopPadding` on tall sheets).
    static let sheetExtraTopInset: CGFloat = 8
    static let screenRootTopPadding: CGFloat = 6
    static let titleBarBottomSpacing: CGFloat = 16
}

enum GLButtonMetrics {
    static let primaryHeight: CGFloat = 48
    static let secondaryHeight: CGFloat = 48
}

/// Center title with fixed-width leading and trailing columns (HoleEntry / End round pattern).
struct GLScreenTopBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                leading()
            }
            .frame(width: GLTopBarMetrics.sideSlotWidth, alignment: .leading)

            Spacer(minLength: 0)

            Text(title)
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                trailing()
            }
            .frame(width: GLTopBarMetrics.sideSlotWidth, alignment: .trailing)
        }
    }
}

/// Home / Stats / History: wordmark at leading edge; trailing content (screen title or avatar).
struct GLHubRootTopBar<Trailing: View>: View {
    private let trailing: () -> Trailing

    init(@ViewBuilder trailing: @escaping () -> Trailing) {
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center) {
            Text("Golf Lab")
                .font(GLFonts.mono(size: 14, weight: .semibold))
                .foregroundColor(.accent)
                .tracking(0.14 * 14)
                .textCase(.uppercase)
            Spacer()
            trailing()
        }
    }
}

extension GLHubRootTopBar where Trailing == Text {
    /// Stats / History-style hub title on the trailing side.
    init(screenTitle: String) {
        self.init {
            Text(screenTitle)
                .font(.glSubhead)
                .foregroundColor(.textTertiary)
        }
    }
}

/// Leading control on pushed surfaces (`ProfileView`, `RoundDetailView`, sheets) — circle + chevron, `docs/design.md` hairline.
struct GLCircleBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(width: 32, height: 32)
                .background(Color.cardBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Circle chevron for in-round hole navigation (`HoleEntryView`) — matches `GLCircleBackButton` chrome; dims when `isEnabled` is false.
struct GLCircleChevronButton: View {
    enum Direction {
        case backward
        case forward
    }

    let direction: Direction
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .backward ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isEnabled ? Color.textSecondary : Color.textTertiary)
                .frame(width: 32, height: 32)
                .background(Color.cardBackground.opacity(isEnabled ? 1 : 0.5))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.borderDefault.opacity(isEnabled ? 1 : 0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(direction == .backward ? "Previous hole" : "Next hole")
    }
}
