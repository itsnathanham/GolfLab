import SwiftUI

/// Home + History: weekly round/practice targets, progress, week history, streak (`docs/design.md` § Weekly goals).
struct WeeklyGoalsStreakSection: View {
    @EnvironmentObject private var roundStore: RoundStore

    private let weekNodeSize: CGFloat = 28
    private let weekConnectorWidth: CGFloat = 10
    private let progressBarHeight: CGFloat = 5

    var body: some View {
        let snap = roundStore.weeklyGoalsSnapshot()

        VStack(alignment: .leading, spacing: 0) {
            GLTrendCardHeader(title: "Weekly goals")

            VStack(alignment: .leading, spacing: 14) {
                if snap.hasActiveTargets {
                    progressRow(
                        label: "Rounds",
                        current: snap.roundsThisWeek,
                        target: snap.roundTarget,
                        active: snap.roundTarget > 0
                    )
                    progressRow(
                        label: "Practice",
                        current: snap.practiceSessionsThisWeek,
                        target: snap.practiceTarget,
                        active: snap.practiceTarget > 0,
                        footnote: GLPracticeRangeBalls.weeklyGoalsFootnote(count: snap.rangeBallsHitThisWeek)
                    )
                    weekHistoryBlock(snap: snap)
                } else {
                    Text("Set how many completed rounds and practice logs you want each week in Profile — we’ll track your streak here.")
                        .font(.glFootnote)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .padding(.top, 12)
            .padding(.bottom, GLCardMetrics.padding)
        }
        .glCardChromeFrame(outlined: true)
    }

    @ViewBuilder
    private func progressRow(
        label: String,
        current: Int,
        target: Int,
        active: Bool,
        footnote: String? = nil
    ) -> some View {
        if active {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.glFootnote)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(current) / \(target)")
                        .font(GLFonts.mono(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                GeometryReader { geo in
                    let t = max(target, 1)
                    let frac = min(1, CGFloat(current) / CGFloat(t))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.bgElevated)
                            .frame(height: progressBarHeight)
                        Capsule()
                            .fill(Color.accent.opacity(0.45))
                            .frame(width: max(4, geo.size.width * frac), height: progressBarHeight)
                    }
                }
                .frame(height: progressBarHeight)

                if let footnote {
                    Text(footnote)
                        .font(.glFootnote)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func weekHistoryBlock(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !snap.weekHistory.isEmpty {
                weekHistoryScroller(weeks: snap.weekHistory)
            }
            streakFooter(streakWeeks: snap.completedWeeksStreak)
        }
        .padding(.top, 2)
    }

    private func weekHistoryScroller(weeks: [GLWeeklyGoalsStreak.WeekRecord]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                        if index > 0 {
                            weekConnector
                        }
                        weekNode(week: week)
                            .id(week.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy) }
            .onChange(of: weeks.map(\.id)) { _, _ in
                scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy)
            }
        }
    }

    private func scrollWeekHistoryToNewest(
        weeks: [GLWeeklyGoalsStreak.WeekRecord],
        proxy: ScrollViewProxy
    ) {
        guard let lastId = weeks.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(lastId, anchor: .trailing)
        }
    }

    private var weekConnector: some View {
        Rectangle()
            .fill(Color.bgElevated)
            .frame(width: weekConnectorWidth, height: 2)
            .padding(.top, weekNodeSize * 0.5 + 14)
    }

    private func weekNode(week: GLWeeklyGoalsStreak.WeekRecord) -> some View {
        VStack(spacing: 5) {
            Text("W\(week.weekNumber)")
                .font(GLFonts.mono(size: 10, weight: .medium))
                .foregroundColor(.textTertiary)
                .frame(minWidth: weekNodeSize + 4)
            weekOutcomeCircle(outcome: week.outcome)
        }
    }

    @ViewBuilder
    private func weekOutcomeCircle(outcome: GLWeeklyGoalsStreak.WeekOutcome) -> some View {
        switch outcome {
        case .complete:
            weekCircle(
                fill: .streakSuccess,
                systemImage: "checkmark",
                iconSize: 12,
                iconWeight: .bold
            )
        case .missed:
            weekCircle(
                fill: .bgElevated,
                systemImage: "xmark",
                iconSize: 11,
                iconWeight: .semibold
            )
        case .inProgress:
            weekCircle(
                fill: .bgElevated,
                systemImage: "ellipsis",
                iconSize: 11,
                iconWeight: .semibold
            )
        }
    }

    private func weekCircle(
        fill: Color,
        systemImage: String,
        iconSize: CGFloat,
        iconWeight: Font.Weight
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: weekNodeSize, height: weekNodeSize)
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundColor(.streakOnSuccess)
        }
    }

    private func streakFooter(streakWeeks: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.streakSuccess)
            Text(Self.streakCaption(weeks: streakWeeks))
                .font(.glFootnote)
                .foregroundColor(.streakTextActive)
        }
    }

    private static func streakCaption(weeks: Int) -> String {
        if weeks == 0 {
            return "Hit both goals this week to grow your streak."
        }
        if weeks == 1 {
            return "1 week streak"
        }
        return "\(weeks) week streak"
    }
}
