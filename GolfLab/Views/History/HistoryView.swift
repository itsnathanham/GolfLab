import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var scope: TimeRange = .season
    @State private var selectedSeasonYear = Calendar.current.component(.year, from: Date())
    @State private var calendarMonthStart = GLCalendarISO.startOfMonth(containing: Date())
    @State private var selectedCalendarYMD: String?
    @State private var practiceSessionsMonth: [PracticeSession] = []
    @State private var showLogPractice = false
    @State private var logPracticeSheetUserId: UUID?
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

    private var listFilteredRounds: [Round] {
        guard let ymd = selectedCalendarYMD else { return displayedRounds }
        return displayedRounds.filter { $0.datePlayedYMD == ymd }
    }

    private var filteredPracticeSessions: [PracticeSession] {
        guard let ymd = selectedCalendarYMD else { return practiceSessionsMonth }
        return practiceSessionsMonth.filter { $0.sessionDate == ymd }
    }

    private var hasListContent: Bool {
        !filteredPracticeSessions.isEmpty || !listFilteredRounds.isEmpty
    }

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
        Set(practiceSessionsMonth.map(\.sessionDate))
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

    private var roundCountSubtitle: String {
        if practiceSessionsMonth.isEmpty {
            return roundCountCaption
        }
        return "\(roundCountCaption) · \(practiceSessionsMonth.count) practice log(s) this month"
    }

    private var roundCountDetailLine: String {
        if selectedCalendarYMD != nil {
            return "\(listFilteredRounds.count) round(s) · \(filteredPracticeSessions.count) practice"
        }
        return roundCountSubtitle
    }

    private var combinedEmptyMessage: String {
        if let ymd = selectedCalendarYMD {
            return "No rounds or practice on \(GLCalendarISO.mmddyyyyDisplay(from: ymd)) for this filter."
        }
        return emptyMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    historyTopBar
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 14)

                    scopePills
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 20)

                    HistoryCalendarMonthCard(
                        monthStart: $calendarMonthStart,
                        roundDotYMD: historyRoundDotsInMonth,
                        practiceDotYMD: historyPracticeDotsInMonth,
                        selectedYMD: selectedCalendarYMD,
                        onTapYMD: toggleCalendarDayFilter
                    )
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 12)

                    GLSecondaryGhostButton(title: "Log practice") {
                        showLogPractice = true
                    }
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 14)

                    if selectedCalendarYMD != nil {
                        HStack {
                            Text("Showing one day")
                                .font(GLFonts.sans(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Button("Clear day") {
                                selectedCalendarYMD = nil
                            }
                            .font(GLFonts.sans(size: 12, weight: .semibold))
                            .foregroundColor(.accent)
                        }
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 12)
                    }

                    if !hasListContent {
                        Text(combinedEmptyMessage)
                            .font(GLFonts.sans(size: 14, weight: .regular))
                            .foregroundColor(.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .padding(.horizontal, GLLayout.horizontalInset)
                    } else {
                        if !filteredPracticeSessions.isEmpty {
                            practiceSessionsCardList
                                .padding(.horizontal, GLLayout.horizontalInset)
                                .padding(.bottom, 14)
                        }

                        roundCountRow
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 10)

                        if listFilteredRounds.isEmpty {
                            Text("No rounds match this filter.")
                                .font(GLFonts.sans(size: 14, weight: .regular))
                                .foregroundColor(.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, GLLayout.horizontalInset)
                        } else {
                            historyRoundCardList
                                .padding(.horizontal, GLLayout.horizontalInset)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
            .refreshable {
                await roundStore.loadRounds()
                await reloadPracticeSessionsForMonth()
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await roundStore.loadRounds()
            normalizeSelectedSeasonYear()
            await reloadPracticeSessionsForMonth()
        }
        .onChange(of: roundStore.roundsListEpoch) { _, _ in
            normalizeSelectedSeasonYear()
        }
        .onChange(of: calendarMonthStart) { _, _ in
            let bounds = GLCalendarISO.inclusiveMonthBoundsYMD(monthStart: calendarMonthStart)
            if let sel = selectedCalendarYMD, (sel < bounds.start || sel > bounds.end) {
                selectedCalendarYMD = nil
            }
            Task { await reloadPracticeSessionsForMonth() }
        }
        .onChange(of: showLogPractice) { _, open in
            if !open {
                logPracticeSheetUserId = nil
            }
        }
        .sheet(isPresented: $showLogPractice) {
            Group {
                if let uid = logPracticeSheetUserId {
                    LogPracticeSheet(userId: uid) {
                        Task { await reloadPracticeSessionsForMonth() }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .presentationDragIndicator(.visible)
            .task {
                logPracticeSheetUserId = await AuthService.shared.currentUserId
            }
        }
        .alert(isPresented: $showDeleteAlert) { deleteAlert }
    }

    private func reloadPracticeSessionsForMonth() async {
        guard let uid = await AuthService.shared.currentUserId else {
            practiceSessionsMonth = []
            return
        }
        let bounds = GLCalendarISO.inclusiveMonthBoundsYMD(monthStart: calendarMonthStart)
        do {
            practiceSessionsMonth = try await SupabaseService.shared.fetchPracticeSessions(
                userId: uid,
                fromInclusiveYMD: bounds.start,
                toInclusiveYMD: bounds.end
            )
        } catch {
            practiceSessionsMonth = []
        }
    }

    private func toggleCalendarDayFilter(_ ymd: String) {
        if selectedCalendarYMD == ymd {
            selectedCalendarYMD = nil
        } else {
            selectedCalendarYMD = ymd
        }
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

    // MARK: - Practice logs list

    private var practiceSessionsCardList: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Practice logs")
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredPracticeSessions.enumerated()), id: \.element.id) { index, session in
                    HStack(alignment: .firstTextBaseline) {
                        Text(GLCalendarISO.mmddyyyyDisplay(from: session.sessionDate))
                            .font(GLFonts.mono(size: 13, weight: .medium))
                            .foregroundColor(.textPrimary)
                        Spacer(minLength: 12)
                        Text(session.focusSubtitle)
                            .font(GLFonts.sans(size: 12, weight: .regular))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, GLCardMetrics.padding)
                    .padding(.vertical, 14)
                    if index < filteredPracticeSessions.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
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
