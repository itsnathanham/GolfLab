import SwiftUI

/// One `Menu` wrapper for every filter dropdown (holes, time range, course) so they all open, close,
/// and relabel identically: accent chip, chevron, fixed item order, no label animation on change.
struct GLFilterMenuPill<Content: View>: View {
    let title: String
    var minWidth: CGFloat?
    var maxTitleWidth: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.glFilterActive)
                    .tracking(0.08 * 11)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: maxTitleWidth)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(minWidth: minWidth)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentDim)
            .foregroundColor(.accent)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderAccent, lineWidth: 1)
            )
        }
        .menuOrder(.fixed)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

/// Menu row with a leading checkmark on the current selection.
struct GLFilterMenuRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
