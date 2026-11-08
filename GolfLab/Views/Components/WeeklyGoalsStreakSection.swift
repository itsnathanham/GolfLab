import SwiftUI

/// Home + History: weekly round/practice targets, progress, week history, streak (`docs/design.md` § Weekly goals).
struct WeeklyGoalsStreakSection: View {
    @EnvironmentObject private var roundStore: RoundStore
    @AppStorage(GLStreakSectionStyle.defaultsKey) private var styleRaw = GLStreakSectionStyle.flagstick.rawValue
    @State private var selectedWeek: GLWeeklyGoalsStreak.WeekRecord?

    private var style: GLStreakSectionStyle {
        GLStreakSectionStyle(rawValue: styleRaw) ?? .flagstick
    }

    var body: some View {
        let snap = roundStore.weeklyGoalsSnapshot()

        Group {
            switch style {
            case .flagstick:
                flagstickCard(snap: snap)
            case .hero:
                heroCard(snap: snap)
            }
        }
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
                    emptyGoalsCopy
                }
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .padding(.top, 12)
            .padding(.bottom, GLCardMetrics.padding)
        }
        .glCardChromeFrame(outlined: true)
    }

    // MARK: - Streak hero

    private func heroCard(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WEEKLY GOALS")
                            .font(.glEyebrow)
                            .foregroundColor(.textTertiary)
                            .tracking(0.08 * 11)
                        Text("Streak runs on both targets")
                            .font(.glFootnote)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(snap.completedWeeksStreak)")
                            .font(GLFonts.mono(size: 32, weight: .semibold))
                            .foregroundColor(.streakMark)
                        Text("week streak")
                            .font(.glFootnote)
                            .foregroundColor(.streakMark)
                    }
                }

                if snap.hasActiveTargets {
                    heroWeekStrip(weeks: snap.weekHistory)
                    HStack(spacing: 8) {
                        if snap.roundTarget > 0 {
                            heroMetricChip(
                                label: "Rounds",
                                value: "\(snap.roundsThisWeek) / \(snap.roundTarget)",
                                fill: CGFloat(snap.roundsThisWeek) / CGFloat(max(snap.roundTarget, 1)),
                                done: snap.roundsThisWeek >= snap.roundTarget
                            )
                        }
                        if snap.practiceTarget > 0 {
                            heroMetricChip(
                                label: "Practice",
                                value: "\(snap.practiceSessionsThisWeek) / \(snap.practiceTarget)",
                                fill: CGFloat(snap.practiceSessionsThisWeek) / CGFloat(max(snap.practiceTarget, 1)),
                                done: snap.practiceSessionsThisWeek >= snap.practiceTarget
                            )
                        }
                    }
                    streakFooter(streakWeeks: snap.completedWeeksStreak, heroPrompt: true)
                } else {
                    emptyGoalsCopy
                }
            }
            .padding(GLCardMetrics.padding)
        }
        .glCardChromeFrame(outlined: true)
    }

    private var emptyGoalsCopy: some View {
        Text("Set how many completed rounds and practice logs you want each week in Profile — we’ll track your streak here.")
            .font(.glFootnote)
            .foregroundColor(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Shared progress

    private let progressBarHeight: CGFloat = 5

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
                            .fill(Color.accentTrack)
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

    private func heroMetricChip(label: String, value: String, fill: CGFloat, done: Bool) -> some View {
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

    @ViewBuilder
    private func weekHistoryBlock(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !snap.weekHistory.isEmpty {
                weekHistoryScroller(weeks: snap.weekHistory)
            }
            streakFooter(streakWeeks: snap.completedWeeksStreak, heroPrompt: false)
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
                    .frame(minWidth: weekNodeSize + 6)
                flagstickMark(outcome: week.outcome)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekAccessibilityLabel(week))
    }

    private func weekAccessibilityLabel(_ week: GLWeeklyGoalsStreak.WeekRecord) -> String {
        let state: String
        switch week.outcome {
        case .complete: state = "goals met"
        case .missed: state = "missed"
        case .inProgress: state = "in progress"
        }
        return "Week \(week.weekNumber), \(state). Shows week summary."
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

    private func heroWeekStrip(weeks: [GLWeeklyGoalsStreak.WeekRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(weeks) { week in
                            Button {
                                selectedWeek = week
                            } label: {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(heroStripFill(week.outcome))
                                    .frame(width: 22, height: 10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(weekAccessibilityLabel(week))
                            .id(week.id)
                        }
                    }
                }
                .onAppear { scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy) }
                .onChange(of: weeks.map(\.id)) { _, _ in
                    scrollWeekHistoryToNewest(weeks: weeks, proxy: proxy)
                }
            }
            if let first = weeks.first, let last = weeks.last {
                HStack {
                    Text("W\(first.weekNumber)")
                        .font(GLFonts.mono(size: 10, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text(first.id == last.id ? "W\(last.weekNumber)" : "W\(last.weekNumber) · now")
                        .font(GLFonts.mono(size: 10, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
        }
    }

    private func heroStripFill(_ outcome: GLWeeklyGoalsStreak.WeekOutcome) -> Color {
        switch outcome {
        case .complete: return .streakMark
        case .missed: return Color.white.opacity(0.12)
        case .inProgress: return Color.streakMark.opacity(0.35)
        }
    }

    private func streakFooter(streakWeeks: Int, heroPrompt: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.streakMark)
            Text(Self.streakCaption(weeks: streakWeeks))
                .font(.glFootnote)
                .foregroundColor(heroPrompt && streakWeeks == 0 ? .textSecondary : .streakMark)
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
            case .met:
                var stick = Path()
                stick.move(to: CGPoint(x: stickX, y: 2))
                stick.addLine(to: CGPoint(x: stickX, y: cupY - 2))
                context.stroke(stick, with: .color(.textSecondary), lineWidth: 2)

                var flag = Path()
                flag.move(to: CGPoint(x: stickX, y: 2))
                flag.addLine(to: CGPoint(x: size.width - 2, y: 7))
                flag.addLine(to: CGPoint(x: stickX, y: 12))
                flag.closeSubpath()
                context.fill(flag, with: .color(.streakMark))

                let green = CGRect(x: stickX - 9, y: cupY - 3, width: 18, height: 6)
                context.fill(Ellipse().path(in: green), with: .color(.bgElevated))
                context.stroke(Ellipse().path(in: green), with: .color(.streakMark), lineWidth: 1)
                context.fill(
                    Circle().path(in: CGRect(x: stickX - 2.4, y: cupY - 2.4, width: 4.8, height: 4.8)),
                    with: .color(.streakMark)
                )

            case .missed:
                var stick = Path()
                stick.move(to: CGPoint(x: stickX, y: 6))
                stick.addLine(to: CGPoint(x: stickX, y: cupY - 4))
                context.stroke(stick, with: .color(.textTertiary), lineWidth: 2)

                let cup = CGRect(x: stickX - 9, y: cupY - 9, width: 18, height: 18)
                context.fill(Circle().path(in: cup), with: .color(.bgElevated))

                var xPath = Path()
                xPath.move(to: CGPoint(x: stickX - 4, y: cupY - 4))
                xPath.addLine(to: CGPoint(x: stickX + 4, y: cupY + 4))
                xPath.move(to: CGPoint(x: stickX + 4, y: cupY - 4))
                xPath.addLine(to: CGPoint(x: stickX - 4, y: cupY + 4))
                context.stroke(xPath, with: .color(.textPrimary), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

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
