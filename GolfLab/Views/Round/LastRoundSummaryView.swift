import SwiftUI

struct LastRoundSummaryView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var roundStore: RoundStore
    @State private var holes: [Hole] = []
    /// Sum of hole pars per round id (season rounds), for score vs season average matching Home’s season vs-par average.
    @State private var seasonParByRoundId: [UUID: Int] = [:]
    @State private var summaryReadyRoundId: UUID?

    private var lastRound: Round? { roundStore.allRounds.first }

    var body: some View {
        ScrollView {
            if let round = lastRound {
                if summaryReadyRoundId == round.id {
                    VStack(spacing: 0) {
                        topNav
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                            .padding(.bottom, GLTopBarMetrics.titleBarBottomSpacing)

                        roundHeader(round: round)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        statGrid(round: round)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        RoundVsParProgressCard(holes: holes, totalHoles: round.holes)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        if isIncompleteScorecard {
                            Text("This round has \(holes.count) of \(round.holes) hole records stored. The figures above sum only those holes.")
                                .font(.glCaption)
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, GLLayout.horizontalInset)
                                .padding(.bottom, 12)
                        }

                        vsAverageRow(round: round)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 20)

                        ctaButtons
                            .padding(.horizontal, GLLayout.horizontalInset)
                    }
                } else {
                    loadingState
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, 24)
                }
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: lastRoundSyncToken) {
            await roundStore.loadRounds()
            guard let round = roundStore.allRounds.first else {
                await MainActor.run {
                    holes = []
                    seasonParByRoundId = [:]
                    summaryReadyRoundId = nil
                }
                return
            }
            await MainActor.run {
                summaryReadyRoundId = nil
            }
            let fetched = (try? await SupabaseService.shared.fetchHoles(roundId: round.id)) ?? []
            await MainActor.run {
                holes = fetched
                if !fetched.isEmpty {
                    seasonParByRoundId[round.id] = fetched.totalParFromHoles
                }
            }
            await loadSeasonParSumsExcludingCached()
            await MainActor.run {
                summaryReadyRoundId = round.id
            }
        }
    }
    
    private var topNav: some View {
        GLScreenTopBar(title: "Last round") {
            Color.clear
        } trailing: {
            Color.clear
        }
    }

    @MainActor
    private func loadSeasonParSumsExcludingCached() async {
        var updates: [UUID: Int] = [:]
        for r in homeSeasonRounds {
            if seasonParByRoundId[r.id] != nil { continue }
            guard let fetched = try? await SupabaseService.shared.fetchHoles(roundId: r.id),
                  !fetched.isEmpty
            else { continue }
            updates[r.id] = fetched.totalParFromHoles
        }
        guard !updates.isEmpty else { return }
        seasonParByRoundId.merge(updates) { _, new in new }
    }

    /// Changes when the first round row updates so we refetch holes after `loadRounds` / reconcile; includes season round ids for par cache.
    private var lastRoundSyncToken: String {
        guard let r = roundStore.allRounds.first else { return "none" }
        let y = Calendar.current.component(.year, from: Date())
        let seasonIds = roundStore.allRounds
            .filter { $0.datePlayed.hasPrefix("\(y)") }
            .map(\.id.uuidString)
            .sorted()
            .joined(separator: ",")
        return "\(r.id.uuidString)-\(r.totalScore.map(String.init) ?? "x")-\(r.totalPutts.map(String.init) ?? "x")-\(r.totalGir.map(String.init) ?? "x")-\(r.totalFir.map(String.init) ?? "x")-\(y)-\(seasonIds)"
    }

    /// Prefer sums from loaded hole rows whenever we have any; avoids trusting `rounds` summary columns when they disagree or `round.holes` does not match row count.
    private func displayAggregates() -> HoleAggregatedTotals? {
        guard !holes.isEmpty else { return nil }
        return holes.aggregatedRoundTotals
    }

    private var isIncompleteScorecard: Bool {
        guard let r = lastRound, !holes.isEmpty else { return false }
        return holes.count < r.holes
    }

    private func roundHeader(round: Round) -> some View {
        let parSum = holes.isEmpty ? roundStore.totalParSumByRoundId[round.id] : holes.totalParFromHoles
        let vs = round.vsParHeadline(totalParFromStoredHoles: parSum)
        return HStack(alignment: .center) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName)
                        .font(GLFonts.sans(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(roundMetaLine(round))
                        .font(.glFootnote)
                        .foregroundColor(.textTertiary)
                    if isSeasonBestRound(round) {
                        seasonBestBadge
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(vs.text)
                    .font(GLFonts.mono(size: 28, weight: .semibold))
                    .foregroundColor(vs.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let score = round.totalScore {
                    Text("\(score) total")
                        .font(GLFonts.mono(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    private func statGrid(round: Round) -> some View {
        let holesTotal = max(round.holes, 1)
        let scoreVsPar = roundScoreVsPar(round: round)
        let girPct = roundGirPct(round: round) ?? 0
        let firPct = roundFirPct(round: round) ?? 0
        let pph = roundPuttsPerHole(round: round) ?? 0

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
            GLStatSummaryTile(
                label: "Score vs par",
                value: scoreVsPar.map(formatVsPar) ?? "—",
                valueUsesAccent: scoreVsPar != nil
            )
            GLStatSummaryTile(
                label: "GIR %",
                value: String(format: "%.0f", girPct),
                valueUsesAccent: false
            )
            GLStatSummaryTile(
                label: "FIR %",
                value: String(format: "%.0f", firPct),
                valueUsesAccent: false
            )
            GLStatSummaryTile(
                label: "Putts / hole",
                value: String(format: "%.1f", pph),
                valueUsesAccent: false
            )
        }
        .background(Color.borderDefault)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Last round stats over \(holesTotal) holes")
    }

    private func vsAverageRow(round: Round) -> some View {
        let rows: [(title: String, round: Double?, season: Double?, roundFormat: (Double) -> String, seasonFormat: (Double) -> String, betterHigh: Bool)] = [
            (
                "Score",
                roundScoreVsPar(round: round),
                seasonAverageScoreVsParMatchingHome(),
                { formatVsPar($0) },
                { formatVsPar($0) },
                false
            ),
            (
                "GIR %",
                roundGirPct(round: round),
                seasonGirPctMatchingHome(),
                { String(format: "%.0f", $0) },
                { String(format: "%.0f", $0) },
                true
            ),
            (
                "FIR %",
                roundFirPct(round: round),
                seasonFirPctMatchingHome(),
                { String(format: "%.0f", $0) },
                { String(format: "%.0f", $0) },
                true
            ),
            (
                "Putts / hole",
                roundPuttsPerHole(round: round),
                seasonPuttsPerHoleMatchingHome(),
                { String(format: "%.1f", $0) },
                { String(format: "%.1f", $0) },
                false
            )
        ]

        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("This round vs season")
                    .font(.glEyebrow)
                    .foregroundColor(.textTertiary)
                    .tracking(0.06 * 11)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 32) {
                    Text("Round")
                    Text("Season")
                }
                .font(GLFonts.mono(size: 10, weight: .medium))
                .foregroundColor(.textTertiary)
                .tracking(0.08 * 10)
                .textCase(.uppercase)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    metricVsSeasonRow(
                        title: row.title,
                        roundValue: row.round,
                        baselineValue: row.season,
                        roundFormat: row.roundFormat,
                        baselineFormat: row.seasonFormat,
                        higherRoundIsBetter: row.betterHigh,
                        showDivider: idx < rows.count - 1
                    )
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

    /// Strokes vs par for the round on this screen (same as Home SCORE card for one round).
    private func roundScoreVsPar(round: Round) -> Double? {
        guard let score = round.totalScore,
              let par = seasonParByRoundId[round.id]
        else { return nil }
        return Double(score - par)
    }

    /// Mean of (gross − par) over season rounds that have par loaded — matches Home **Season** SCORE stat.
    private func seasonAverageScoreVsParMatchingHome() -> Double? {
        let deltas: [Double] = homeSeasonRounds.compactMap { r in
            guard let score = r.totalScore,
                  let par = seasonParByRoundId[r.id]
            else { return nil }
            return Double(score - par)
        }
        guard !deltas.isEmpty else { return nil }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    /// Same set as **Home → Season**: rounds whose `date_played` falls in the current calendar year (used for GIR% / putts-per-hole aggregates on Home).
    private var homeSeasonRounds: [Round] {
        let year = Calendar.current.component(.year, from: Date())
        return roundStore.allRounds.filter { $0.datePlayed.hasPrefix("\(year)") }
    }

    private func roundGirPct(round: Round) -> Double? {
        guard round.holes > 0 else { return nil }
        let hits = displayAggregates()?.gir ?? round.totalGir ?? 0
        return Double(hits) / Double(round.holes) * 100
    }

    private func roundPuttsPerHole(round: Round) -> Double? {
        guard round.holes > 0 else { return nil }
        let putts = displayAggregates()?.putts ?? round.totalPutts ?? 0
        return Double(putts) / Double(round.holes)
    }
    
    private func roundFirPct(round: Round) -> Double? {
        if !holes.isEmpty {
            let eligible = holes.filter { $0.par > 3 }.count
            guard eligible > 0 else { return nil }
            let hits = holes.filter { $0.par > 3 && $0.fir == true }.count
            return Double(hits) / Double(eligible) * 100
        }
        guard round.holes > 0 else { return nil }
        let fir = round.totalFir ?? 0
        return Double(fir) / Double(round.holes) * 100
    }

    private func seasonGirPctMatchingHome() -> Double? {
        aggregateGirPct(over: homeSeasonRounds)
    }

    private func seasonPuttsPerHoleMatchingHome() -> Double? {
        aggregatePuttsPerHole(over: homeSeasonRounds)
    }
    
    private func seasonFirPctMatchingHome() -> Double? {
        let holeSum = homeSeasonRounds.reduce(0) { $0 + $1.holes }
        guard holeSum > 0 else { return nil }
        let firSum = homeSeasonRounds.reduce(0) { $0 + ($1.totalFir ?? 0) }
        return Double(firSum) / Double(holeSum) * 100
    }

    private func aggregateGirPct(over rounds: [Round]) -> Double? {
        let holeSum = rounds.reduce(0) { $0 + $1.holes }
        guard holeSum > 0 else { return nil }
        let girSum = rounds.reduce(0) { $0 + ($1.totalGir ?? 0) }
        return Double(girSum) / Double(holeSum) * 100
    }

    private func aggregatePuttsPerHole(over rounds: [Round]) -> Double? {
        let holeSum = rounds.reduce(0) { $0 + $1.holes }
        guard holeSum > 0 else { return nil }
        let puttSum = rounds.reduce(0) { $0 + ($1.totalPutts ?? 0) }
        return Double(puttSum) / Double(holeSum)
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            GLPrimaryCTAButton(title: "+ Start round") {
                roundStore.requestRoundSetupFromHome()
            }

            GLSecondaryGhostButton(title: "View stats →") {
                selectedTab = 2
            }
        }
    }

    private func metricVsSeasonRow(
        title: String,
        roundValue: Double?,
        baselineValue: Double?,
        roundFormat: (Double) -> String,
        baselineFormat: (Double) -> String,
        higherRoundIsBetter _: Bool,
        showDivider: Bool
    ) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.glSubhead)
                .foregroundColor(.textSecondary)
            Spacer()
            if let r = roundValue, let a = baselineValue {
                HStack(spacing: 32) {
                    Text(roundFormat(r))
                        .font(GLFonts.mono(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(minWidth: 48, alignment: .trailing)
                    Text(baselineFormat(a))
                        .font(GLFonts.mono(size: 14, weight: .regular))
                        .foregroundColor(.textTertiary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
            } else if let r = roundValue {
                HStack(spacing: 32) {
                    Text(roundFormat(r))
                        .font(GLFonts.mono(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(minWidth: 48, alignment: .trailing)
                    Text("—")
                        .font(GLFonts.mono(size: 14, weight: .regular))
                        .foregroundColor(.textTertiary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
            } else {
                Text("—")
                    .font(GLFonts.mono(size: 15, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.accent)
            Text("Loading round summary...")
                .font(.glSubhead)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .top)
    }
    
    private func roundMetaLine(_ round: Round) -> String {
        if let date = ymdDate(round.datePlayed), Calendar.current.isDateInToday(date) {
            return "Today · \(round.holes) holes"
        }
        if let date = ymdDate(round.datePlayed) {
            let df = DateFormatter()
            df.calendar = Calendar.current
            df.locale = Locale.current
            df.setLocalizedDateFormatFromTemplate("MMM d")
            return "\(df.string(from: date)) · \(round.holes) holes"
        }
        return "\(round.datePlayedDisplay) · \(round.holes) holes"
    }
    
    private var seasonBestBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.accent)
            Text("Season best")
                .font(GLFonts.mono(size: 10, weight: .semibold))
                .foregroundColor(.accent)
                .tracking(0.06 * 10)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.accentDim)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.borderAccent, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func isSeasonBestRound(_ round: Round) -> Bool {
        isSeasonBestScoreVsPar(round: round)
    }

    private func isSeasonBestScoreVsPar(round: Round) -> Bool {
        guard let current = roundScoreVsPar(round: round) else { return false }
        let values: [Double] = homeSeasonRounds
            .filter { $0.holes == round.holes }
            .compactMap { seasonRound in
                guard let score = seasonRound.totalScore,
                      let par = seasonParByRoundId[seasonRound.id]
                else { return nil }
                return Double(score - par)
            }
        guard let best = values.min() else { return false }
        return current <= best
    }

    private func formatVsPar(_ value: Double) -> String {
        if value == 0 { return "E" }
        if abs(value.rounded() - value) < 0.01 {
            let raw = String(format: "%+.0f", value)
            return raw.replacingOccurrences(of: "-", with: "\u{2212}")
        }
        let raw = String(format: "%+.1f", value)
        return raw.replacingOccurrences(of: "-", with: "\u{2212}")
    }
    
    private func ymdDate(_ ymd: String) -> Date? {
        let head = String(ymd.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return Calendar.current.date(from: dc)
    }
}
