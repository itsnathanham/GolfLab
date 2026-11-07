import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var scope: TimeRange = .season
    @State private var selectedSeasonYear = Calendar.current.component(.year, from: Date())
    @State private var calendarMonthStart = GLCalendarISO.startOfMonth(containing: Date())
    @State private var selectedCalendarYMD: String?
    @State private var showDaySummarySheet = false
    @State private var roundToDelete: Round?
    @State private var showDeleteAlert = false

    private var displayedRounds: [Round] {
        let base: [Round]
        switch scope {
        case .season:
            base = roundStore.allRounds.filter { $0.datePlayed.hasPrefix("\(resolvedSeasonYear)") }
        case .last10:
            base = roundStore.allRounds.lastRoundsByDatePlayed(10)
        case .allTime:
            base = roundStore.allRounds
        }
        return base.sortedByDatePlayedDescending()
    }

    private var listFilteredRounds: [Round] { displayedRounds }

    private var historyRoundDotsInMonth: Set<String> {
        let bounds = GLCalendarISO.inclusiveMonthBoundsYMD(monthStart: calendarMonthStart)
        return Set(
            roundStore.allRounds
                .filter { isCompletedRoundForCalendar($0) }
                .map(\.datePlayedYMD)
                .filter { $0 >= bounds.start && $0 <= bounds.end }
        )
    }

    private var historyPracticeDotsInMonth: Set<String> {
        let bounds = GLCalendarISO.inclusiveMonthBoundsYMD(monthStart: calendarMonthStart)
        return Set(
            roundStore.allPracticeSessions
                .map(\.sessionDate)
                .filter { $0 >= bounds.start && $0 <= bounds.end }
        )
    }

    private func isCompletedRoundForCalendar(_ round: Round) -> Bool {
        guard round.holes > 0 else { return false }
        let rows = roundStore.holeRowCountByRoundId[round.id] ?? 0
        return rows >= round.holes
    }

    private var roundsInSelectedYear: Int {
        roundStore.allRounds.filter { $0.datePlayed.hasPrefix("\(resolvedSeasonYear)") }.count
    }

    private var roundCountCaption: String {
        let n = roundsInSelectedYear
        return "\(n) in \(resolvedSeasonYear)"
    }

    private var roundCountDetailLine: String { roundCountCaption }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    historyTopBar
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 14)

                    WeeklyGoalsStreakSection()
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 18)

                    HistoryCalendarMonthCard(
                        monthStart: $calendarMonthStart,
                        roundDotYMD: historyRoundDotsInMonth,
                        practiceDotYMD: historyPracticeDotsInMonth,
                        selectedYMD: selectedCalendarYMD,
                        onTapYMD: toggleCalendarDayFilter
                    )
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 24)

                    scopePills
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 20)

                    if listFilteredRounds.isEmpty {
                        Text(emptyMessage)
                            .font(GLFonts.sans(size: 14, weight: .regular))
                            .foregroundColor(.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .padding(.horizontal, GLLayout.horizontalInset)
                    } else {
                        roundCountRow
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 10)

                        historyRoundCardList
                            .padding(.horizontal, GLLayout.horizontalInset)
                    }
                }
            }
            .refreshable {
                await roundStore.loadRounds()
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            normalizeSelectedSeasonYear()
        }
        .onChange(of: roundStore.roundsListEpoch) { _, _ in
            normalizeSelectedSeasonYear()
        }
        .onChange(of: calendarMonthStart) { _, _ in
            let bounds = GLCalendarISO.inclusiveMonthBoundsYMD(monthStart: calendarMonthStart)
            if let sel = selectedCalendarYMD, (sel < bounds.start || sel > bounds.end) {
                selectedCalendarYMD = nil
                showDaySummarySheet = false
            }
        }
        .sheet(isPresented: $showDaySummarySheet) {
            if let ymd = selectedCalendarYMD {
                NavigationStack {
                    HistoryDaySummarySheet(
                        ymd: ymd,
                        weekNumber: weekNumber(containingYMD: ymd),
                        rounds: roundsForDay(ymd: ymd),
                        practices: practicesForDay(ymd: ymd)
                    )
                }
                .presentationDragIndicator(.visible)
                .environmentObject(roundStore)
            }
        }
        .alert(isPresented: $showDeleteAlert) { deleteAlert }
    }

    private func toggleCalendarDayFilter(_ ymd: String) {
        selectedCalendarYMD = ymd
        showDaySummarySheet = true
    }

    private func roundsForDay(ymd: String) -> [Round] {
        roundStore.allRounds
            .filter { $0.datePlayedYMD == ymd }
            .sortedByDatePlayedDescending()
    }

    private func practicesForDay(ymd: String) -> [PracticeSession] {
        PracticeSession.sortedForDisplay(
            roundStore.allPracticeSessions.filter { $0.sessionDate == ymd }
        )
    }

    private func weekNumber(containingYMD ymd: String) -> Int? {
        GLWeeklyGoalsStreak.weekNumber(
            containingYMD: ymd,
            history: roundStore.weeklyGoalsSnapshot().weekHistory
        )
    }

    private var emptyMessage: String {
        switch scope {
        case .season:
            return "No rounds in \(resolvedSeasonYear) yet."
        case .last10:
            return "No rounds yet."
        case .allTime:
            return "No rounds yet."
        }
    }

    // MARK: - Top bar

    private var historyTopBar: some View {
        GLHubRootTopBar { EmptyView() }
    }

    // MARK: - Scope pills

    private var scopePills: some View {
        HStack {
            TimeRangeFilterPicker(
                timeRange: $scope,
                selectedSeasonYear: $selectedSeasonYear,
                availableSeasonYears: availableSeasonYears,
                resolvedSeasonYear: resolvedSeasonYear
            )
            Spacer(minLength: 0)
        }
    }

    private var availableSeasonYears: [Int] {
        let years = Set(roundStore.allRounds.compactMap(Self.calendarYear(from:)))
        let fallback = Calendar.current.component(.year, from: Date())
        return (years.isEmpty ? [fallback] : Array(years)).sorted(by: >)
    }

    private var resolvedSeasonYear: Int {
        if availableSeasonYears.contains(selectedSeasonYear) {
            return selectedSeasonYear
        }
        let current = Calendar.current.component(.year, from: Date())
        if availableSeasonYears.contains(current) {
            return current
        }
        return availableSeasonYears.first ?? current
    }

    private func normalizeSelectedSeasonYear() {
        selectedSeasonYear = resolvedSeasonYear
    }

    // MARK: - Round count

    private var roundCountRow: some View {
        HStack(alignment: .firstTextBaseline) {
            GLFormFieldLabel(text: "Rounds")
            Spacer()
            Text(roundCountDetailLine)
                .font(GLFonts.mono(size: 12, weight: .medium))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Rounds list

    private var historyRoundCardList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(listFilteredRounds.enumerated()), id: \.element.id) { index, round in
                NavigationLink {
                    RoundDetailView(round: round)
                } label: {
                    RoundListRowView(round: round, showIncompleteFlag: true)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteRound(round)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if index < listFilteredRounds.count - 1 {
                    Rectangle()
                        .fill(Color.borderDefault)
                        .frame(height: 1)
                }
            }
        }
        .glCardChromeFrame(outlined: true)
    }

    private func deleteRound(_ round: Round) {
        roundToDelete = round
        showDeleteAlert = true
    }

    private var deleteAlert: Alert {
        Alert(
            title: Text("Delete Round?"),
            message: Text("This will permanently delete \(roundToDelete?.courseName ?? "this round") and all its hole data."),
            primaryButton: .destructive(Text("Delete")) {
                guard let round = roundToDelete else { return }
                Task {
                    try? await GolfLabData.store.deleteRound(id: round.id)
                    await roundStore.loadRounds()
                }
            },
            secondaryButton: .cancel()
        )
    }

    private static func calendarYear(from round: Round) -> Int? {
        let prefix = String(round.datePlayed.prefix(4))
        return Int(prefix)
    }
}

private struct HistoryDaySummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let ymd: String
    /// Streak week label when this day falls in tracked history. Hidden otherwise.
    let weekNumber: Int?
    let rounds: [Round]
    let practices: [PracticeSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 14) {
                    dateCard
                    countCard

                    if !rounds.isEmpty {
                        roundList
                    }

                    if !practices.isEmpty {
                        practiceList
                    }
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
            Text("Day summary")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var dateCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(GLCalendarISO.daySheetTitle(from: ymd))
                    .font(GLFonts.mono(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(GLCalendarISO.weekdayName(from: ymd))
                    .font(.glFootnote)
                    .foregroundColor(.textSecondary)
            }
            Spacer(minLength: 8)
            if let weekNumber {
                Text("W\(weekNumber)")
                    .font(GLFonts.mono(size: 13, weight: .semibold))
                    .foregroundColor(.streakMark)
            }
        }
        .glCardSurface(outlined: true)
    }

    private var countCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            countLine(label: "Rounds", value: rounds.count)
            countLine(label: "Practice", value: practices.count)
        }
        .glCardSurface(outlined: true)
    }

    private func countLine(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.glFootnote)
                .foregroundColor(.textSecondary)
            Spacer()
            Text("\(value)")
                .font(GLFonts.mono(size: 12, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
    }

    private var roundList: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Rounds")
            VStack(spacing: 0) {
                ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                    NavigationLink {
                        RoundDetailView(round: round)
                    } label: {
                        RoundListRowView(round: round, showIncompleteFlag: true)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    if index < rounds.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
        }
    }

    private var practiceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Practice")
            VStack(spacing: 0) {
                ForEach(Array(practices.enumerated()), id: \.element.id) { index, session in
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
                    if index < practices.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
        }
    }
}
