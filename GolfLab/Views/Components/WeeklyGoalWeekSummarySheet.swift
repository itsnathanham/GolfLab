import SwiftUI

/// Week summary shown when a streak week mark is tapped.
struct WeeklyGoalWeekSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let detail: GLWeeklyGoalsStreak.WeekDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    goalsMeterCard

                    if !detail.rounds.isEmpty {
                        roundsSection
                    }

                    if !detail.practices.isEmpty {
                        practiceSection
                    }

                    rangeBallsSection
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.bottom, GLLayout.sheetContentBottomPadding)
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton { dismiss() }
            Spacer()
            Text("Week summary")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("W\(detail.weekNumber)")
                    .font(GLFonts.mono(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(
                    GLWeeklyGoalsStreak.dateRangeDisplay(
                        startYMD: detail.weekStartYMD,
                        endYMD: detail.weekEndYMD
                    )
                )
                .font(.glFootnote)
                .foregroundColor(.textSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Image(systemName: outcomeIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(outcomeColor)
                Text(outcomeLabel)
                    .font(GLFonts.sans(size: 12, weight: .semibold))
                    .foregroundColor(outcomeColor)
            }
        }
        .glCardSurface(outlined: true)
    }

    private var outcomeIcon: String {
        switch detail.outcome {
        case .complete: return "flag.fill"
        case .missed: return "xmark"
        case .inProgress: return "ellipsis"
        }
    }

    private var outcomeColor: Color {
        switch detail.outcome {
        case .complete: return .streakMark
        case .missed: return .textSecondary
        case .inProgress: return .streakMark
        }
    }

    private var outcomeLabel: String {
        switch detail.outcome {
        case .complete: return "Goals met"
        case .missed: return "Missed"
        case .inProgress: return "In progress"
        }
    }

    private var goalsMeterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if detail.roundTarget > 0 {
                meterRow(
                    label: "Rounds",
                    current: detail.completedRoundCount,
                    target: detail.roundTarget
                )
            }
            if detail.practiceTarget > 0 {
                meterRow(
                    label: "Practice",
                    current: detail.practices.count,
                    target: detail.practiceTarget
                )
            }
        }
        .glCardSurface(outlined: true)
    }

    private func meterRow(label: String, current: Int, target: Int) -> some View {
        let frac = min(1, CGFloat(current) / CGFloat(max(target, 1)))
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.glFootnote)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(current) / \(target)")
                    .font(GLFonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.bgElevated)
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.accentTrack)
                        .frame(width: max(4, geo.size.width * frac), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Rounds")
            VStack(spacing: 0) {
                ForEach(Array(detail.rounds.enumerated()), id: \.element.id) { index, round in
                    NavigationLink {
                        RoundDetailView(round: round)
                    } label: {
                        RoundListRowView(round: round, showIncompleteFlag: true)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    if index < detail.rounds.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
        }
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Practice")
            VStack(spacing: 0) {
                ForEach(Array(detail.practices.enumerated()), id: \.element.id) { index, session in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.focusSubtitle.isEmpty ? "Logged practice" : session.focusSubtitle)
                            .font(.glSubhead)
                            .foregroundColor(.textPrimary)
                        Text(GLCalendarISO.mmddyyyyDisplay(from: session.sessionDate))
                            .font(.glFootnote)
                            .foregroundColor(.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    if index < detail.practices.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
        }
    }

    private var rangeBallsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                GLFormFieldLabel(text: "Range balls")
                Spacer()
                Text("\(detail.rangeBallsHit) this week")
                    .font(GLFonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(.streakMark)
            }
            RangeBallsWeekChart(
                weeks: detail.rangeBallsByWeek,
                highlightWeekStartYMD: detail.weekStartYMD
            )
            .padding(.top, 4)
            .glCardSurface(outlined: true)
        }
    }
}

// MARK: - Range balls column chart

private struct RangeBallsWeekChart: View {
    let weeks: [GLWeeklyGoalsStreak.WeekBalls]
    let highlightWeekStartYMD: String

    private let chartHeight: CGFloat = 88

    var body: some View {
        let maxBalls = max(weeks.map(\.balls).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeks) { week in
                    let isCurrent = week.weekStartYMD == highlightWeekStartYMD
                    let barH = max(week.balls == 0 ? 3 : CGFloat(week.balls) / CGFloat(maxBalls) * (chartHeight - 18), 3)
                    VStack(spacing: 6) {
                        if isCurrent && week.balls > 0 {
                            Text("\(week.balls)")
                                .font(GLFonts.mono(size: 10, weight: .semibold))
                                .foregroundColor(.streakMark)
                        } else {
                            Color.clear.frame(height: 12)
                        }
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCurrent ? Color.streakMark : Color.bgElevated)
                            .frame(maxWidth: 22)
                            .frame(height: barH)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: chartHeight, alignment: .bottom)
                }
            }
            HStack(spacing: 8) {
                ForEach(weeks) { week in
                    let isCurrent = week.weekStartYMD == highlightWeekStartYMD
                    Text("W\(week.weekNumber)")
                        .font(GLFonts.mono(size: 10, weight: isCurrent ? .semibold : .medium))
                        .foregroundColor(isCurrent ? .streakMark : .textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
