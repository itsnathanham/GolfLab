import SwiftUI

struct LastRoundSummaryView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var roundStore: RoundStore

    private var lastRound: Round? { roundStore.allRounds.first }

    private var holes: [Hole] {
        guard let id = lastRound?.id else { return [] }
        return roundStore.holes(for: id)
    }

    private var seasonHolesByRoundId: [UUID: [Hole]] {
        Dictionary(uniqueKeysWithValues: homeSeasonRounds.compactMap { round in
            let holes = roundStore.holes(for: round.id)
            guard !holes.isEmpty else { return nil }
            return (round.id, holes)
        })
    }

    private var seasonParByRoundId: [UUID: Int] {
        var result: [UUID: Int] = [:]
        for (id, holes) in seasonHolesByRoundId {
            result[id] = holes.totalParFromHoles
        }
        for round in homeSeasonRounds where result[round.id] == nil {
            if let par = roundStore.totalParSumByRoundId[round.id] {
                result[round.id] = par
            }
        }
        return result
    }

    private var seasonPenaltiesByRoundId: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: seasonHolesByRoundId.map { id, holes in
            (id, holes.aggregatedRoundTotals.penalties)
        })
    }

    var body: some View {
        ScrollView {
            if let round = lastRound {
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

                        RoundVsParProgressCard(
                            holes: holes,
                            totalHoles: round.holes,
                            averageOverlay: seasonAverageOverlay
                        )
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
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topNav: some View {
        GLScreenTopBar(title: "Last round") {
            Color.clear
        } trailing: {
            Color.clear
        }
    }

    private var seasonAverageOverlay: VsParLineChartSeries? {
        guard let round = lastRound else { return nil }
        return VsParCumulativeProgression.seasonAverageOverlaySeries(
            holesByRoundId: seasonHolesByRoundId,
            seasonRounds: homeSeasonRounds,
            holeRowCountByRoundId: roundStore.holeRowCountByRoundId,
            chartHoleCount: round.holes
        )
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

        return GLStatFourUpSummaryGrid(
            scoreLabel: "Score vs par",
            scoreValue: scoreVsPar.map(GLMetricFormat.vsParRound) ?? "—",
            scoreUsesAccent: scoreVsPar != nil,
            firValue: String(format: "%.0f", firPct),
            girValue: String(format: "%.0f", girPct),
            puttsValue: GLMetricFormat.puttsPerHole(pph),
            scoreShowsSeasonBest: isSeasonBest(.scoreVsPar, round: round),
            firShowsSeasonBest: isSeasonBest(.fir, round: round),
            girShowsSeasonBest: isSeasonBest(.gir, round: round),
            puttsShowsSeasonBest: isSeasonBest(.puttsPerHole, round: round),
            accessibilityLabel: "Last round stats over \(holesTotal) holes"
        )
    }

    private func vsAverageRow(round: Round) -> some View {
        let rows: [(title: String, round: Double?, season: Double?, roundFormat: (Double) -> String, seasonFormat: (Double) -> String, betterHigh: Bool)] = [
            (
                "Score",
                roundScoreVsPar(round: round),
                seasonAverageScoreVsParMatchingHome(),
                GLMetricFormat.vsParRound,
                GLMetricFormat.vsParRound,
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
                GLMetricFormat.puttsPerHole,
                GLMetricFormat.puttsPerHole,
                false
            ),
            (
                "Penalties / round",
                roundPenaltiesPerRound(round: round),
                seasonPenaltiesPerRoundMatchingHome(),
                { String(format: "%.0f", $0) },
                { String(format: "%.0f", $0) },
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

    private var homeSeasonRounds: [Round] {
        SeasonHolesFetch.calendarYearRounds(from: roundStore.allRounds)
    }

    private func roundGirPct(round: Round) -> Double? {
        guard round.holes > 0 else { return nil }
        let hits: Int
        if round.id == lastRound?.id, let agg = displayAggregates() {
            hits = agg.gir
        } else {
            hits = round.totalGir ?? 0
        }
        return Double(hits) / Double(round.holes) * 100
    }

    private func roundPuttsPerHole(round: Round) -> Double? {
        guard round.holes > 0 else { return nil }
        let putts: Int
        if round.id == lastRound?.id, let agg = displayAggregates() {
            putts = agg.putts
        } else {
            putts = round.totalPutts ?? 0
        }
        return Double(putts) / Double(round.holes)
    }

    private func roundFirPct(round: Round) -> Double? {
        if round.id == lastRound?.id, !holes.isEmpty {
            return holes.firHitPercentage
        }
        return seasonHolesByRoundId[round.id]?.firHitPercentage
    }

    private func seasonGirPctMatchingHome() -> Double? {
        aggregateGirPct(over: homeSeasonRounds)
    }

    private func seasonPuttsPerHoleMatchingHome() -> Double? {
        aggregatePuttsPerHole(over: homeSeasonRounds)
    }
    
    private func seasonFirPctMatchingHome() -> Double? {
        SeasonHolesFetch.flattenedCompletedHoles(
            seasonRounds: homeSeasonRounds,
            holesByRoundId: seasonHolesByRoundId,
            holeRowCountByRoundId: roundStore.holeRowCountByRoundId
        ).firHitPercentage
    }

    private func roundPenaltiesPerRound(round _: Round) -> Double? {
        guard !holes.isEmpty else { return nil }
        return Double(displayAggregates()?.penalties ?? 0)
    }

    /// Mean penalty count per round over season rounds with loaded hole rows.
    private func seasonPenaltiesPerRoundMatchingHome() -> Double? {
        let counts: [Double] = homeSeasonRounds.compactMap { r in
            guard let n = seasonPenaltiesByRoundId[r.id] else { return nil }
            return Double(n)
        }
        guard !counts.isEmpty else { return nil }
        return counts.reduce(0, +) / Double(counts.count)
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
    
    private enum SeasonBestStat {
        case scoreVsPar, fir, gir, puttsPerHole
    }

    private func isSeasonBest(_ stat: SeasonBestStat, round: Round) -> Bool {
        switch stat {
        case .scoreVsPar:
            let peers = homeSeasonRounds.filter { $0.holes == round.holes }
            return ranksSeasonBest(
                roundScoreVsPar(round: round),
                in: peers.compactMap { roundScoreVsPar(round: $0) },
                lowerIsBetter: true
            )
        case .fir:
            return ranksSeasonBest(
                roundFirPct(round: round),
                in: homeSeasonRounds.compactMap { roundFirPct(round: $0) },
                lowerIsBetter: false
            )
        case .gir:
            return ranksSeasonBest(
                roundGirPct(round: round),
                in: homeSeasonRounds.compactMap { roundGirPct(round: $0) },
                lowerIsBetter: false
            )
        case .puttsPerHole:
            return ranksSeasonBest(
                roundPuttsPerHole(round: round),
                in: homeSeasonRounds.compactMap { roundPuttsPerHole(round: $0) },
                lowerIsBetter: true
            )
        }
    }

    private func ranksSeasonBest(_ current: Double?, in values: [Double], lowerIsBetter: Bool) -> Bool {
        guard let current, let best = lowerIsBetter ? values.min() : values.max() else { return false }
        return lowerIsBetter ? current <= best : current >= best
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
