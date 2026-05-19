import SwiftUI
import UIKit

struct StatToggle: View {
    enum Style {
        case positive
        case penalty
        case practice
    }

    let label: String
    /// Omit or pass `""` for label-only compact toggles (e.g. Log practice row).
    var subtitle: String = ""
    @Binding var isOn: Bool
    var style: Style = .positive
    var isEnabled: Bool = true

    var body: some View {
        Button {
            guard isEnabled else { return }
            let wasOn = isOn
            isOn.toggle()
            if style == .penalty, isOn, !wasOn {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: subtitle.isEmpty ? 0 : 3) {
                    Text(label)
                        .font(GLFonts.sans(size: 12, weight: .semibold))
                        .foregroundColor(toggleTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.glFootnote)
                            .foregroundColor(.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if isOn {
                    Circle()
                        .fill(dotFill)
                        .frame(width: 8, height: 8)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: subtitle.isEmpty ? 52 : 68)
            .background(toggleBackground)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(toggleBorder, lineWidth: GLCardMetrics.strokeWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.65)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }

    private var dotFill: Color {
        switch style {
        case .penalty: return Color.chartNegativeStrong
        case .practice: return Color.calendarPracticeDot
        case .positive: return Color.accent
        }
    }

    private var toggleBackground: Color {
        guard isOn else { return .cardBackground }
        switch style {
        case .penalty:
            return Color.chartNegativeStrong.opacity(0.08)
        case .practice:
            return Color.calendarPracticeDim
        case .positive:
            return Color.accentDimmer
        }
    }

    private var toggleBorder: Color {
        guard isOn else { return .borderDefault }
        switch style {
        case .penalty: return Color.borderPenalty
        case .practice: return Color.calendarPracticeBorder
        case .positive: return Color.borderAccent
        }
    }

    private var toggleTextColor: Color {
        guard isOn else { return .textSecondary }
        switch style {
        case .penalty: return Color.chartNegativeStrong
        case .practice: return Color.calendarPracticeDot
        case .positive: return Color.accent
        }
    }
}
