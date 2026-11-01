import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var roundStore: RoundStore
    @State private var showLogPractice = false
    @State private var logPracticeSheetUserId: UUID?
    @State private var holeFilter: HoleFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    homeTopBar
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 18)

                    if roundStore.allRounds.isEmpty {
                        EmptyHomeView(selectedTab: $selectedTab, showLogPractice: $showLogPractice)
                            .padding(.top, 8)
                    } else {
                        seasonBlock
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 18)

                        holeFilterPicker
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 18)

                        homeStatGrid
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 22)

                        WeeklyGoalsStreakSection()
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 22)

                        scoringTrendPanel
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 24)

                        homeRoundActionButtons
                            .padding(.horizontal, GLLayout.horizontalInset)
                    }
                }
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            holeFilter = HoleFilterState.restoredHoleFilter(rounds: roundStore.allRounds)
        }
        .onChange(of: roundStore.roundsListEpoch) { _, _ in
            let restored = HoleFilterState.restoredHoleFilter(rounds: roundStore.allRounds)
            if holeFilter != restored && !HoleFilterState.hasRounds(for: holeFilter, in: roundStore.allRounds) {
                holeFilter = restored
            }
        }
        .onChange(of: showLogPractice) { _, open in
            if !open {
                logPracticeSheetUserId = nil
                roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
            }
        }
        .sheet(isPresented: $showLogPractice) {
            Group {
                if let uid = logPracticeSheetUserId {
                    LogPracticeSheet(userId: uid)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .presentationDragIndicator(.visible)
            .task {
                logPracticeSheetUserId = AccountService.shared.currentUserId
            }
        }
    }

    // MARK: - Top bar

    private var homeTopBar: some View {
        GLHubRootTopBar {
            NavigationLink {
                ProfileView()
                    .environmentObject(roundStore)
            } label: {
                Text(roundStore.avatarInitials.isEmpty ? "?" : roundStore.avatarInitials)
                    .font(.glMicro)
                    .foregroundColor(.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
    }

    // MARK: - Season / headline

    private var holeFilterPicker: some View {
        HoleFilterPicker(selectedFilter: $holeFilter, availableRounds: roundStore.allRounds)
    }

    private var seasonBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(seasonCaption)
                .font(.glEyebrow)
                .foregroundColor(.textTertiary)
                .tracking(0.10 * 11)
                .textCase(.uppercase)

            averagingHeadlineBlock
        }
    }

    private var seasonCaption: String {
        let y = Calendar.current.component(.year, from: Date())
        let n = homeSeasonRounds.count
        let suffix: String
        if holeFilter == .all {
            suffix = "\(n) round\(n == 1 ? "" : "s")"
        } else {
            suffix = "\(n) round\(n == 1 ? "" : "s") · \(holeFilter.displayTitle)"
        }
        return "\(y) season · \(suffix)"
    }

    @ViewBuilder
    private var averagingHeadlineBlock: some View {
        if let avg = averageScoreVsPar(for: homeSeasonRounds) {
            averagingHeadlineText(avg: avg)
        }
    }

    private func averagingHeadlineText(avg: Double) -> Text {
        let val = GLMetricFormat.vsParStrokes(avg)
        return Text("Averaging ")
            .font(GLFonts.sans(size: 22, weight: .light))
            .foregroundColor(.textPrimary)
            + Text(val)
            .font(GLFonts.mono(size: 22, weight: .semibold))
            .foregroundColor(.accent)
            + Text(" this season")
            .font(GLFonts.sans(size: 22, weight: .light))
            .foregroundColor(.textPrimary)
    }

    // MARK: - Stat grid (2×2, same chrome + order as Last round)

    private var homeSeasonRounds: [Round] {
        let seasonRounds = SeasonHolesFetch.calendarYearRounds(from: roundStore.allRounds)
        return HoleFilterState.filteredRounds(seasonRounds, filter: holeFilter)
    }

    private var homeStatGrid: some View {
        let rounds = homeSeasonRounds
        let avgVsPar = averageScoreVsPar(for: rounds)
        let girPct = girPercentage(for: rounds)
        let pph = puttsPerHole(for: rounds)
        let firPct = homeSeasonHoles.firHitPercentage

        let scoreText = avgVsPar.map(GLMetricFormat.vsParStrokes) ?? "—"

        let girText = statPercentText(girPct)

        let firText = statPercentText(firPct)

        let puttsText = pph.map(GLMetricFormat.puttsPerHole) ?? "—"

        return GLStatFourUpSummaryGrid(
            scoreLabel: "Score vs par",
            scoreValue: scoreText,
            scoreUsesAccent: avgVsPar != nil,
            firValue: firText,
            girValue: girText,
            puttsValue: puttsText
        )
    }

    // MARK: - Chart

    private var scoringTrendPanel: some View {
        ScoringTrendCard(values: homeScoringTrendSeries)
    }

    private var homeScoringTrendSeries: [Double] {
        homeSeasonRounds.reversed().compactMap { r in
            guard let score = r.totalScore,
                  let par = roundStore.totalParSumByRoundId[r.id]
            else { return nil }
            return Double(score - par)
        }
    }

    // MARK: - Actions

    private var startRoundButton: some View {
        GLPrimaryCTAButton(title: "+ Start round") {
            roundStore.requestRoundSetupFromHome()
            selectedTab = 1
        }
    }

    private var homeRoundActionButtons: some View {
        VStack(spacing: 12) {
            startRoundButton
            GLSecondaryGhostButton(title: "Log practice") {
                showLogPractice = true
            }
        }
    }

    // MARK: - Helpers

    private func averageScoreVsPar(for rounds: [Round]) -> Double? {
        let deltas: [Double] = rounds.compactMap { r in
            guard let score = r.totalScore,
                  let parSum = roundStore.totalParSumByRoundId[r.id]
            else { return nil }
            return Double(score - parSum)
        }
        guard !deltas.isEmpty else { return nil }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    private func girPercentage(for rounds: [Round]) -> Double? {
        let opportunities = rounds.reduce(0) { $0 + $1.holes }
        guard opportunities > 0 else { return nil }
        let hits = rounds.reduce(0) { $0 + ($1.totalGir ?? 0) }
        return Double(hits) / Double(opportunities) * 100
    }

    private func puttsPerHole(for rounds: [Round]) -> Double? {
        let holeCount = rounds.reduce(0) { $0 + $1.holes }
        guard holeCount > 0 else { return nil }
        let putts = rounds.reduce(0) { $0 + ($1.totalPutts ?? 0) }
        return Double(putts) / Double(holeCount)
    }

    private var homeSeasonHoles: [Hole] {
        SeasonHolesFetch.flattenedCompletedHoles(
            seasonRounds: homeSeasonRounds,
            holesByRoundId: roundStore.holesByRoundId,
            holeRowCountByRoundId: roundStore.holeRowCountByRoundId
        )
    }

    private func statPercentText(_ value: Double?) -> String {
        if let value { return String(format: "%.0f", value) }
        return "—"
    }
}

// MARK: - Empty state

struct EmptyHomeView: View {
    @Binding var selectedTab: Int
    @Binding var showLogPractice: Bool
    @EnvironmentObject private var roundStore: RoundStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accent)
                Text("Play your first round to start tracking your progress")
                    .font(GLFonts.sans(size: 17, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            WeeklyGoalsStreakSection()
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                GLPrimaryCTAButton(title: "+ Start round") {
                    roundStore.requestRoundSetupFromHome()
                    selectedTab = 1
                }
                GLSecondaryGhostButton(title: "Log practice") {
                    showLogPractice = true
                }
            }
        }
        .padding(.horizontal, GLLayout.horizontalInset)
    }
}

// MARK: - Time range

enum TimeRange: CaseIterable {
    case season, last10, allTime

    var pillTitle: String {
        switch self {
        case .season:
            return "Season"
        case .last10:
            return "Last 10"
        case .allTime:
            return "All time"
        }
    }
}
