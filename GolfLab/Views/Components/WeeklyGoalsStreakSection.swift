import SwiftUI

/// Home + History: weekly round/practice targets, progress, week history, streak (`docs/design.md` § Weekly goals).
struct WeeklyGoalsStreakSection: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var selectedWeek: GLWeeklyGoalsStreak.WeekRecord?

    var body: some View {
        let snap = roundStore.weeklyGoalsSnapshot()

        flagstickCard(snap: snap)
        .sheet(item: $selectedWeek, onDismiss: {
            roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
        }) { week in
            NavigationStack {
                if let detail = roundStore.weeklyGoalWeekDetail(week: week, history: snap.weekHistory) {
                    WeeklyGoalWeekSummarySheet(detail: detail)
                } else {
                    Text("Couldn’t load this week.")
                        .font(.glBody)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(GLLayout.horizontalInset)
                        .background(Color.appBackground)
                }
            }
            .presentationDragIndicator(.visible)
            .environmentObject(roundStore)
        }
    }

    // MARK: - Flagstick (classic chrome)

    private func flagstickCard(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            flagstickHeader(streakWeeks: snap.completedWeeksStreak, showsStreak: snap.hasActiveTargets)

            VStack(alignment: .leading, spacing: 12) {
                if snap.hasActiveTargets {
                    if !snap.weekHistory.isEmpty {
                        weekHistoryScroller(weeks: snap.weekHistory)
                    }
                    streakFooter(snap: snap)
                    goalChips(snap: snap)
                    if let footnote = GLPracticeRangeBalls.weeklyGoalsFootnote(count: snap.rangeBallsHitThisWeek) {
                        Text(footnote)
                            .font(.glFootnote)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    emptyGoalsCopy
                }
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .padding(.top, 12)
            .padding(.bottom, GLCardMetrics.padding)
        }
        .glCardChromeFrame(outlined: true)
    }

    private func flagstickHeader(streakWeeks: Int, showsStreak: Bool) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("Weekly goals")
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 11)
                .textCase(.uppercase)
            Spacer(minLength: 12)
            if showsStreak {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(streakWeeks)")
                        .font(GLFonts.mono(size: 22, weight: .semibold))
                    Text("week streak")
                        .font(GLFonts.sans(size: 12, weight: .regular))
                }
                .foregroundColor(.streakMark)
            }
        }
        .padding(.horizontal, GLCardMetrics.padding)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyGoalsCopy: some View {
        Text("Set how many completed rounds and practice logs you want each week in Profile — we’ll track your streak here.")
            .font(.glFootnote)
            .foregroundColor(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Shared progress

    @ViewBuilder
    private func goalChips(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        HStack(spacing: 8) {
            if snap.roundTarget > 0 {
                goalMetricChip(
                    label: "Rounds",
                    value: "\(snap.roundsThisWeek) / \(snap.roundTarget)",
                    fill: CGFloat(snap.roundsThisWeek) / CGFloat(max(snap.roundTarget, 1)),
                    done: snap.roundsThisWeek >= snap.roundTarget
                )
            }
            if snap.practiceTarget > 0 {
                goalMetricChip(
                    label: "Practice",
                    value: "\(snap.practiceSessionsThisWeek) / \(snap.practiceTarget)",
                    fill: CGFloat(snap.practiceSessionsThisWeek) / CGFloat(max(snap.practiceTarget, 1)),
                    done: snap.practiceSessionsThisWeek >= snap.practiceTarget
                )
            }
        }
    }

    private func goalMetricChip(label: String, value: String, fill: CGFloat, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.06 * 10)
            Text(value)
                .font(GLFonts.mono(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.accentTrack)
                        .frame(width: max(3, geo.size.width * min(1, fill)), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall)
                .stroke(done ? Color.accent.opacity(0.35) : Color.clear, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    // MARK: - Week history

    private let weekNodeSize: CGFloat = 28
    private let weekConnectorWidth: CGFloat = 10
    private let flagstickHeight: CGFloat = 36

    private func weekHistoryScroller(weeks: [GLWeeklyGoalsStreak.WeekRecord]) -> some View {
        GeometryReader { geo in
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
                    // A short row stays left-aligned. A row wider than the card starts at the newest week.
                    .frame(minWidth: geo.size.width, alignment: .leading)
                }
                .defaultScrollAnchor(.trailing)
                .onAppear { scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy) }
                .onChange(of: weeks.map(\.id)) { _, _ in
                    scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy, animated: true)
                }
            }
        }
        .frame(height: weekRowHeight)
    }

    private var weekRowHeight: CGFloat { flagstickHeight + 26 }

    private func scrollWeekHistoryToNewest(
        weeks: [GLWeeklyGoalsStreak.WeekRecord],
        proxy: ScrollViewProxy,
        animated: Bool = false
    ) {
        guard let lastId = weeks.last?.id else { return }
        // Yield so a long row has a width before the scroll. A one-week row is only as wide as the card, so this stays put.
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastId, anchor: .trailing)
                }
            } else {
                proxy.scrollTo(lastId, anchor: .trailing)
            }
        }
    }

    private var weekConnector: some View {
        Rectangle()
            .fill(Color.bgElevated)
            .frame(width: weekConnectorWidth, height: 2)
            .padding(.top, 14 + flagstickHeight * 0.55)
    }

    private func weekNode(week: GLWeeklyGoalsStreak.WeekRecord) -> some View {
        Button {
            selectedWeek = week
        } label: {
            VStack(spacing: 5) {
                Text("W\(week.weekNumber)")
                    .font(GLFonts.mono(size: 10, weight: .medium))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: weekNodeSize + 6)
                if week.showsFreezeMark {
                    freezeSnowflake
                } else {
                    flagstickMark(outcome: week.outcome)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekAccessibilityLabel(week))
    }

    private func weekAccessibilityLabel(_ week: GLWeeklyGoalsStreak.WeekRecord) -> String {
        let state: String
        switch week.outcome {
        case .complete:
            state = week.showsFreezeMark ? "frozen, goals met" : "goals met"
        case .missed:
            state = week.showsFreezeMark ? "frozen, goals missed" : "missed"
        case .inProgress:
            state = week.showsFreezeMark ? "frozen" : "in progress"
        }
        return "Week \(week.weekNumber), \(state). Shows week summary."
    }

    private var freezeSnowflake: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let arm = min(size.width, size.height) * 0.34
            var crystal = Path()
            for index in 0..<6 {
                let angle = (Double(index) * 60 - 90) * .pi / 180
                let tip = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * arm,
                    y: center.y + CGFloat(sin(angle)) * arm
                )
                crystal.move(to: center)
                crystal.addLine(to: tip)
                let branch = arm * 0.36
                let branchAngle = 42 * .pi / 180
                let inward = CGPoint(
                    x: tip.x - CGFloat(cos(angle)) * arm * 0.4,
                    y: tip.y - CGFloat(sin(angle)) * arm * 0.4
                )
                crystal.move(to: inward)
                crystal.addLine(to: CGPoint(
                    x: inward.x + CGFloat(cos(angle + branchAngle)) * branch,
                    y: inward.y + CGFloat(sin(angle + branchAngle)) * branch
                ))
                crystal.move(to: inward)
                crystal.addLine(to: CGPoint(
                    x: inward.x + CGFloat(cos(angle - branchAngle)) * branch,
                    y: inward.y + CGFloat(sin(angle - branchAngle)) * branch
                ))
            }
            context.stroke(crystal, with: .color(Color.chartCyan), lineWidth: 1.5)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)),
                with: .color(Color.chartCyan)
            )
        }
        .frame(width: weekNodeSize, height: flagstickHeight)
    }

    private func flagstickMark(outcome: GLWeeklyGoalsStreak.WeekOutcome) -> some View {
        Group {
            switch outcome {
            case .complete:
                FlagstickGlyph(style: .met)
            case .missed:
                FlagstickGlyph(style: .missed)
            case .inProgress:
                FlagstickGlyph(style: .inProgress)
            }
        }
        .frame(width: weekNodeSize, height: flagstickHeight)
    }

    private func streakFooter(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        HStack(spacing: 6) {
            if snap.isFrozen {
                Image(systemName: "snowflake")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.chartCyan)
                Text("Streak frozen")
                    .font(.glFootnote)
                    .foregroundColor(.chartCyan)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                Text(Self.streakCaption(weeks: snap.completedWeeksStreak))
                    .font(.glFootnote)
                    .foregroundColor(.orange)
            }
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

// MARK: - Flagstick glyph

private struct FlagstickGlyph: View {
    enum Style {
        case met
        case missed
        case inProgress
    }

    let style: Style

    var body: some View {
        Canvas { context, size in
            let stickX = size.width * 0.32
            let cupY = size.height - 6

            switch style {
            case .met, .missed:
                let flagColor: Color = style == .met ? .streakMark : .textTertiary
                let stickColor: Color = style == .met ? .textSecondary : .textTertiary

                var pole = Path()
                pole.move(to: CGPoint(x: stickX, y: 2))
                pole.addLine(to: CGPoint(x: stickX, y: cupY - 2))
                context.stroke(pole, with: .color(stickColor), lineWidth: 2)

                var flagPath = Path()
                flagPath.move(to: CGPoint(x: stickX, y: 2))
                flagPath.addLine(to: CGPoint(x: size.width - 2, y: 7))
                flagPath.addLine(to: CGPoint(x: stickX, y: 12))
                flagPath.closeSubpath()
                context.fill(flagPath, with: .color(flagColor))

                let cup = CGRect(x: stickX - 9, y: cupY - 3, width: 18, height: 6)
                context.fill(Ellipse().path(in: cup), with: .color(.bgElevated))
                context.stroke(Ellipse().path(in: cup), with: .color(flagColor), lineWidth: 1)
                context.fill(
                    Circle().path(in: CGRect(x: stickX - 2.4, y: cupY - 2.4, width: 4.8, height: 4.8)),
                    with: .color(flagColor)
                )

            case .inProgress:
                var stick = Path()
                stick.move(to: CGPoint(x: stickX, y: 4))
                stick.addLine(to: CGPoint(x: stickX, y: cupY - 2))
                context.stroke(stick, with: .color(.textTertiary), lineWidth: 2)

                var flag = Path()
                flag.move(to: CGPoint(x: stickX, y: 4))
                flag.addLine(to: CGPoint(x: size.width - 2, y: 9))
                flag.addLine(to: CGPoint(x: stickX, y: 14))
                flag.closeSubpath()
                context.stroke(
                    flag,
                    with: .color(.streakMark),
                    style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2])
                )

                let green = CGRect(x: stickX - 9, y: cupY - 3, width: 18, height: 6)
                context.fill(Ellipse().path(in: green), with: .color(.bgElevated))
                for i in 0..<3 {
                    let dx = CGFloat(i - 1) * 4.5
                    context.fill(
                        Circle().path(in: CGRect(x: stickX + dx - 1.2, y: cupY - 1.2, width: 2.4, height: 2.4)),
                        with: .color(.textPrimary)
                    )
                }
            }
        }
    }
}
