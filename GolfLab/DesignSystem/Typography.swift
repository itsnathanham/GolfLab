import SwiftUI

// IBM Plex via `GLFonts` + bundle (docs/design.md).

extension Font {
    /// Mono 34 semibold — large stat values, round totals.
    static let glDisplay = GLFonts.mono(size: 34, weight: .semibold)
    /// Sans 22 semibold — screen titles.
    static let glTitle = GLFonts.sans(size: 22, weight: .semibold)
    /// Sans 18 medium — card titles, section headers.
    static let glHeadline = GLFonts.sans(size: 18, weight: .medium)
    /// Sans 16 regular — body.
    static let glBody = GLFonts.sans(size: 16, weight: .regular)
    /// Sans 14 medium — secondary labels.
    static let glSubhead = GLFonts.sans(size: 14, weight: .medium)
    /// Sans 12 medium — field labels (often uppercase + tracking in views).
    static let glCaption = GLFonts.sans(size: 12, weight: .medium)
    /// Sans 11 medium — dense uppercase chrome (chart card titles, tab labels, segmented-scale labels).
    static let glEyebrow = GLFonts.sans(size: 11, weight: .medium)
    /// Sans 11 regular — compact tertiary lines (toggle subtitles, stepper hints).
    static let glFootnote = GLFonts.sans(size: 11, weight: .regular)
    /// Mono 10 medium — badges, compact numeric meta.
    static let glMicro = GLFonts.mono(size: 10, weight: .medium)
    /// Mono 9 — chart axes (color applied in views).
    static let glAxis = GLFonts.mono(size: 9, weight: .regular)
    /// Sans 11 semibold — active filter pill.
    static let glFilterActive = GLFonts.sans(size: 11, weight: .semibold)
    /// Sans 11 medium — inactive filter pill.
    static let glFilterInactive = GLFonts.sans(size: 11, weight: .medium)
    /// Sans 14 semibold — primary full-width CTAs.
    static let glButtonPrimary = GLFonts.sans(size: 14, weight: .semibold)
    /// Sans 14 medium — ghost / secondary CTAs.
    static let glButtonSecondary = GLFonts.sans(size: 14, weight: .medium)
    /// Sans 14 semibold — centered bar title (`GLScreenTopBar`).
    static let glNavTitle = GLFonts.sans(size: 14, weight: .semibold)
}

// MARK: - Layout (docs/design.md)

enum GLLayout {
    static let horizontalInset: CGFloat = 22
}

// MARK: - Layout tokens (cards, sheets, chart panels)

enum GLCardMetrics {
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusSmall: CGFloat = 8
    static let padding: CGFloat = 14
    static let strokeWidth: CGFloat = 1
}

// MARK: - Card surfaces

private struct GLCardSurfaceModifier: ViewModifier {
    var outlined: Bool

    func body(content: Content) -> some View {
        content
            .padding(GLCardMetrics.padding)
            .background(Color.cardBackground)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: outlined ? GLCardMetrics.strokeWidth : 0)
            )
    }
}

/// Background + corner + optional stroke **without** inset padding (e.g. full-bleed scorecard tables).
private struct GLCardChromeFrameModifier: ViewModifier {
    var outlined: Bool

    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: outlined ? GLCardMetrics.strokeWidth : 0)
            )
    }
}

extension View {
    /// Standard inset card: `cardBackground`, `GLCardMetrics` padding + corner radius; optional hairline border (e.g. stat tiles).
    func glCardSurface(outlined: Bool = false) -> some View {
        modifier(GLCardSurfaceModifier(outlined: outlined))
    }

    func glCardChromeFrame(outlined: Bool = false) -> some View {
        modifier(GLCardChromeFrameModifier(outlined: outlined))
    }

    /// Home **StatCard**-style tile: full width, vertical padding, rounded rect + divider stroke.
    func glStatTileSurface() -> some View {
        frame(maxWidth: .infinity)
            .padding(.vertical, GLCardMetrics.padding)
            .background(Color.cardBackground)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
    }

    /// **End round** summary cells: smaller corner radius, same stroke treatment.
    func glCompactStatTileSurface() -> some View {
        frame(maxWidth: .infinity)
            .padding(.vertical, GLCardMetrics.padding)
            .background(Color.cardBackground)
            .cornerRadius(GLCardMetrics.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
    }
}

// MARK: - Selection pills (time range, year chips)

struct GLSelectionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GLSelectionPillLabel(title: title, isSelected: isSelected)
        }
    }
}

struct GLSelectionPillLabel: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title.uppercased())
            .font(isSelected ? .glFilterActive : .glFilterInactive)
            .tracking(0.08 * 11)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentDim : Color.clear)
            .foregroundColor(isSelected ? Color.accent : Color.textTertiary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
            )
    }
}

// MARK: - Chart / table card header (`design.md` — chart card header row)

/// 9pt uppercase tertiary title + bottom hairline; pairs with inset chart or table body.
struct GLTrendCardHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.glEyebrow)
            .foregroundColor(.textTertiary)
            .tracking(0.08 * 11)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
            }
    }
}

// MARK: - Stat summary tile (2×2 grids: Last round, End round, Home quick stats)

/// Uppercase micro label + mono value only — matches `LastRoundSummaryView` / `EndRoundView` stat cells (no footnote).
struct GLStatSummaryTile: View {
    let label: String
    let value: String
    var valueUsesAccent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 11)
                .textCase(.uppercase)
            Text(value)
                .font(GLFonts.mono(size: 20, weight: .semibold))
                .foregroundColor(valueUsesAccent ? .accent : .textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
    }
}

// MARK: - Stat strip cell (Home / Stats bordered summary grids)

/// Micro label + mono value + optional tertiary footnote (`Stats` four-up).
struct GLStatStripCell: View {
    let label: String
    let value: String
    var valueUsesAccent: Bool = false
    var footnote: String? = "Vs season avg"
    var valueMonoSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 11)
            Text(value)
                .font(GLFonts.mono(size: valueMonoSize, weight: .semibold))
                .foregroundColor(valueUsesAccent ? Color.accent : Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.top, 5)
            if let footnote {
                Text(footnote)
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
    }
}

// MARK: - Trend stat card (Home / Stats shared chrome)

/// Bordered trend card: uppercase title header, inset chart (`GLStatTrendCard` on Home / Stats).
struct GLStatTrendCard<ChartContent: View>: View {
    let title: String
    @ViewBuilder var chartContent: () -> ChartContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GLTrendCardHeader(title: title)

            chartContent()
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }
}
