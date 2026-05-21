import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var roundStore: RoundStore
    @EnvironmentObject private var authService: AuthService
    @State private var avatarInitials = ""
    @State private var showLogPractice = false
    @State private var logPracticeSheetUserId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    homeTopBar
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 18)

                    if roundStore.isLoadingRounds {
                        homeLoadingState
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.top, 8)
                    } else if roundStore.allRounds.isEmpty {
                        EmptyHomeView(selectedTab: $selectedTab, showLogPractice: $showLogPractice)
                            .padding(.top, 8)
                    } else {
                        seasonBlock
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 18)

                        quickStatsSectionHeader
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 10)

                        homeStatGrid
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 22)

                        WeeklyGoalsStreakSection()
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 22)

                        scoringTrendPanel
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 22)

                        recentSectionHeader
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 10)

                        recentRoundsGroupedList
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
        .task {
            await roundStore.loadRounds()
            await loadAvatarInitials()
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
                logPracticeSheetUserId = await authService.currentUserId
            }
        }
    }

    private var homeLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.accent)
            Text("Loading your rounds...")
                .font(.glSubhead)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .top)
    }

    // MARK: - Top bar

    private var homeTopBar: some View {
        GLHubRootTopBar {
            NavigationLink {
                ProfileView()
                    .environmentObject(roundStore)
            } label: {
                Text(avatarInitials.isEmpty ? "?" : avatarInitials)
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
        return "\(y) season · \(n) round\(n == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var averagingHeadlineBlock: some View {
        if let avg = averageScoreVsPar(for: homeSeasonRounds) {
            averagingHeadlineText(avg: avg)
        }
    }

    private func averagingHeadlineText(avg: Double) -> Text {
        let val = formatAvgVsPar(avg)
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

    // MARK: - Quick stats

    private var quickStatsSectionHeader: some View {
        GLFormFieldLabel(text: "Quick stats")
    }

    // MARK: - Stat grid (2×2, same chrome + order as Last round)

    private var homeSeasonRounds: [Round] {
        let y = Calendar.current.component(.year, from: Date())
        return roundStore.allRounds.filter { $0.datePlayed.hasPrefix("\(y)") }
    }

    private var homeStatGrid: some View {
        let rounds = homeSeasonRounds
        let avgVsPar = averageScoreVsPar(for: rounds)
        let girPct = girPercentage(for: rounds)
        let pph = puttsPerHole(for: rounds)
        let firPct = firPercentageFromRoundTotals(for: rounds)

        let scoreText = avgVsPar.map { formatAvgVsPar($0) } ?? "—"

        let girText: String = {
            guard let v = girPct else { return "—" }
            return String(format: "%.0f", v)
        }()

        let firText: String = {
            guard let v = firPct else { return "—" }
            return String(format: "%.0f", v)
        }()

        let puttsText = pph.map { String(format: "%.1f", $0) } ?? "—"

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

    // MARK: - Recent rounds

    private var recentSectionHeader: some View {
        GLFormFieldLabel(text: "Recent rounds")
    }

    private var recentRoundsGroupedList: some View {
        let recent = roundStore.allRounds.lastRoundsByDatePlayed(3)
        return VStack(spacing: 0) {
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, round in
                NavigationLink {
                    RoundDetailView(round: round)
                } label: {
                    RoundListRowView(round: round)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)

                if index < recent.count - 1 {
                    Rectangle()
                        .fill(Color.borderDefault)
                        .frame(height: 1)
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

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

    /// FIR from stored round totals (same weighting as season rollups elsewhere when hole-by-hole isn’t loaded).
    private func firPercentageFromRoundTotals(for rounds: [Round]) -> Double? {
        let holeSum = rounds.reduce(0) { $0 + $1.holes }
        guard holeSum > 0 else { return nil }
        let firSum = rounds.reduce(0) { $0 + ($1.totalFir ?? 0) }
        return Double(firSum) / Double(holeSum) * 100
    }

    private func formatAvgVsPar(_ v: Double) -> String {
        if abs(v - v.rounded()) < 0.05 {
            return String(format: "%+.0f", v)
        }
        return String(format: "%+.1f", v)
    }

    private func loadAvatarInitials() async {
        guard let userId = await authService.currentUserId else { return }
        guard let profile = try? await SupabaseService.shared.fetchProfile(userId: userId) else { return }
        let initials = Self.initials(from: profile.displayName)
        await MainActor.run {
            avatarInitials = initials
        }
    }

    private static func initials(from displayName: String?) -> String {
        guard let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return ""
        }
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Round summary bubble (History list)

struct RoundSummaryBubbleCard: View {
    @EnvironmentObject private var roundStore: RoundStore
    var caption: String?
    let round: Round
    /// When true, shows the coral “Incomplete round” line when stored hole rows are fewer than `round.holes`.
    var showIncompleteBadge: Bool = false
    /// History list: chevron inside the bubble (pair with `navigationLinkIndicatorVisibility(.hidden)` on the `List`).
    var showsListChevron: Bool = false

    private var vsPar: (text: String, color: Color) {
        round.vsParHeadline(totalParFromStoredHoles: roundStore.totalParSumByRoundId[round.id])
    }

    private var shouldShowIncomplete: Bool {
        guard showIncompleteBadge,
              let n = roundStore.holeRowCountByRoundId[round.id]
        else { return false }
        return round.isScorecardIncomplete(storedHoleRows: n)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if let caption {
                    GLFormFieldLabel(text: caption)
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.courseName)
                            .font(.glHeadline)
                            .foregroundColor(.textPrimary)
                        Text(round.datePlayedDisplay)
                            .font(.glSubhead)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vsPar.text)
                            .font(GLFonts.mono(size: 28, weight: .semibold))
                            .foregroundColor(vsPar.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        if let score = round.totalScore {
                            Text("\(score) total")
                                .font(.glSubhead)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                if shouldShowIncomplete {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Incomplete round")
                            .font(.glCaption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.chartNegative)
                }
            }
            if showsListChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .glCardSurface()
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
