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
        .sheet(item: $selectedWeek) { week in
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

            VStack(alignment: .leading, spacing: 14) {
                if snap.hasActiveTargets {
                    goalChips(snap: snap)
                    if let footnote = GLPracticeRangeBalls.weeklyGoalsFootnote(count: snap.rangeBallsHitThisWeek) {
                        Text(footnote)
                            .font(.glFootnote)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    /// Eyebrow plus the hero streak count. The hairline stays so the card still reads as the flagstick header.
    private func flagstickHeader(streakWeeks: Int, showsStreak: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Weekly goals")
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 11)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsStreak {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(streakWeeks)")
                        .font(GLFonts.mono(size: 32, weight: .semibold))
                        .foregroundColor(.streakMark)
                    Text("week streak")
                        .font(.glFootnote)
                        .foregroundColor(.streakMark)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, showsStreak ? 10 : 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
        }
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
                    goalChips(snap: snap)
                    streakFooter(
                        streakWeeks: snap.completedWeeksStreak,
                        flame: .streakMark,
                        caption: snap.completedWeeksStreak == 0 ? .textSecondary : .streakMark
                    )
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

    @ViewBuilder
    private func goalChips(snap: GLWeeklyGoalsStreak.Snapshot) -> some View {
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
            streakFooter(streakWeeks: snap.completedWeeksStreak, flame: .orange, caption: .orange)
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

    private func streakFooter(streakWeeks: Int, flame: Color, caption: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(flame)
            Text(Self.streakCaption(weeks: streakWeeks))
                .font(.glFootnote)
                .foregroundColor(caption)
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
