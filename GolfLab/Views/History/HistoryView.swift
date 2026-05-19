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
        .task {
            await roundStore.loadRounds()
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
                HistoryDaySummarySheet(
                    ymd: ymd,
                    rounds: roundsForDay(ymd: ymd),
                    practices: practicesForDay(ymd: ymd)
                )
                .presentationDragIndicator(.visible)
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
        roundStore.allPracticeSessions.filter { $0.sessionDate == ymd }
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
        GLHubRootTopBar(screenTitle: "History")
    }

    // MARK: - Scope pills

    private var scopePills: some View {
        HStack(spacing: 6) {
            if isSeasonYearSelectable {
                Menu {
                    ForEach(availableSeasonYears, id: \.self) { year in
                        Button {
                            selectedSeasonYear = year
                            scope = .season
                        } label: {
                            if year == resolvedSeasonYear {
                                Label(String(year), systemImage: "checkmark")
                            } else {
                                Text(String(year))
                            }
                        }
                    }
                } label: {
                    GLSelectionPillLabel(
                        title: "\(resolvedSeasonYear) v",
                        isSelected: scope == .season
                    )
                }
            } else {
                GLSelectionPill(title: String(resolvedSeasonYear), isSelected: scope == .season) {
                    scope = .season
                }
            }

            ForEach([TimeRange.last10, TimeRange.allTime], id: \.self) { range in
                GLSelectionPill(title: range.pillTitle, isSelected: scope == range) {
                    scope = range
                }
            }
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

    private var isSeasonYearSelectable: Bool {
        availableSeasonYears.count > 1
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
                    try? await SupabaseService.shared.deleteRound(id: round.id)
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
    let rounds: [Round]
    let practices: [PracticeSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 18) {
                    summaryHeader
                    summaryCounts

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

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GLCalendarISO.mmddyyyyDisplay(from: ymd))
                .font(GLFonts.mono(size: 22, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("Selected date")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
        }
        .glCardSurface(outlined: true)
    }

    private var summaryCounts: some View {
        HStack(spacing: 8) {
            countPill(label: "Rounds", value: rounds.count)
            countPill(label: "Practice", value: practices.count)
            Spacer(minLength: 0)
        }
    }

    private func countPill(label: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 11)
            Text("\(value)")
                .font(GLFonts.mono(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var roundList: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Rounds")
            VStack(spacing: 0) {
                ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                    HStack {
                        Text(round.courseName)
                            .font(.glSubhead)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(round.datePlayedDisplay)
                            .font(GLFonts.mono(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.horizontal, GLCardMetrics.padding)
                    .padding(.vertical, 12)
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
                    HStack {
                        Text(session.focusSubtitle.isEmpty ? "Logged practice" : session.focusSubtitle)
                            .font(.glSubhead)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, GLCardMetrics.padding)
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
