import SwiftUI

struct LastRoundSummaryView: View {
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

                        RoundVsSeasonComparisonCard(
                            rows: RoundSeasonComparison.rows(
                                round: round,
                                holes: holes,
                                roundStore: roundStore,
                                seasonYear: Calendar.current.component(.year, from: Date())
                            )
                        )
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 20)

                        GLPrimaryCTAButton(title: "+ Start round") {
                            roundStore.requestRoundSetupFromHome()
                        }
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

    /// Strokes vs par for the round on this screen (same as Home SCORE card for one round).
    private func roundScoreVsPar(round: Round) -> Double? {
        guard let score = round.totalScore,
              let par = seasonParByRoundId[round.id]
        else { return nil }
        return Double(score - par)
    }

    private var homeSeasonRounds: [Round] {
        let seasonRounds = SeasonHolesFetch.calendarYearRounds(from: roundStore.allRounds)
        guard let currentRound = lastRound else { return seasonRounds }
        return seasonRounds.filter { $0.holes == currentRound.holes }
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

enum RoundSeasonComparison {
    struct Row: Identifiable {
        let title: String
        let roundText: String?
        let seasonText: String?
        var id: String { title }
    }

    static func rows(
        round: Round,
        holes: [Hole],
        roundStore: RoundStore,
        seasonYear: Int
    ) -> [Row] {
        let seasonRounds = SeasonHolesFetch.calendarYearRounds(from: roundStore.allRounds, year: seasonYear)
            .filter { $0.holes == round.holes }
        let holesByRoundId = Dictionary(uniqueKeysWithValues: seasonRounds.compactMap { seasonRound -> (UUID, [Hole])? in
            let cached = seasonRound.id == round.id && !holes.isEmpty
                ? holes
                : roundStore.holes(for: seasonRound.id)
            guard !cached.isEmpty else { return nil }
            return (seasonRound.id, cached)
        })

        let score = scoreVsPar(round: round, holes: holes, roundStore: roundStore)
        let seasonScore = average(seasonRounds.compactMap { candidate in
            scoreVsPar(
                round: candidate,
                holes: holesByRoundId[candidate.id] ?? [],
                roundStore: roundStore
            )
        })

        let gir = percent(hits: holes.isEmpty ? (round.totalGir ?? 0) : holes.aggregatedRoundTotals.gir, over: round.holes)
        let seasonGir = percent(
            hits: seasonRounds.reduce(0) { $0 + ($1.totalGir ?? 0) },
            over: seasonRounds.reduce(0) { $0 + $1.holes }
        )

        let fir = holes.isEmpty
            ? holesByRoundId[round.id]?.firHitPercentage
            : holes.firHitPercentage
        let seasonFir = SeasonHolesFetch.flattenedCompletedHoles(
            seasonRounds: seasonRounds,
            holesByRoundId: holesByRoundId,
            holeRowCountByRoundId: roundStore.holeRowCountByRoundId
        ).firHitPercentage

        let putts = perHole(
            total: holes.isEmpty ? (round.totalPutts ?? 0) : holes.aggregatedRoundTotals.putts,
            holes: round.holes
        )
        let seasonPutts = perHole(
            total: seasonRounds.reduce(0) { $0 + ($1.totalPutts ?? 0) },
            holes: seasonRounds.reduce(0) { $0 + $1.holes }
        )

        let penalties: Double? = holes.isEmpty ? nil : Double(holes.aggregatedRoundTotals.penalties)
        let penaltyCounts = seasonRounds.compactMap { candidate -> Double? in
            guard let cached = holesByRoundId[candidate.id] else { return nil }
            return Double(cached.aggregatedRoundTotals.penalties)
        }
        let seasonPenalties = average(penaltyCounts)

        return [
            row("Score", score, seasonScore, GLMetricFormat.vsParRound),
            row("GIR %", gir, seasonGir) { String(format: "%.0f", $0) },
            row("FIR %", fir, seasonFir) { String(format: "%.0f", $0) },
            row("Putts / hole", putts, seasonPutts, GLMetricFormat.puttsPerHole),
            row("Penalties / round", penalties, seasonPenalties) { String(format: "%.0f", $0) }
        ]
    }

    private static func row(
        _ title: String,
        _ roundValue: Double?,
        _ seasonValue: Double?,
        _ format: (Double) -> String
    ) -> Row {
        Row(
            title: title,
            roundText: roundValue.map(format),
            seasonText: seasonValue.map(format)
        )
    }

    private static func scoreVsPar(round: Round, holes: [Hole], roundStore: RoundStore) -> Double? {
        let par = holes.isEmpty ? roundStore.totalParSumByRoundId[round.id] : holes.totalParFromHoles
        guard let score = round.totalScore, let par else { return nil }
        return Double(score - par)
    }

    private static func percent(hits: Int, over holes: Int) -> Double? {
        guard holes > 0 else { return nil }
        return Double(hits) / Double(holes) * 100
    }

    private static func perHole(total: Int, holes: Int) -> Double? {
        guard holes > 0 else { return nil }
        return Double(total) / Double(holes)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

struct RoundVsSeasonComparisonCard: View {
    let rows: [RoundSeasonComparison.Row]

    var body: some View {
        VStack(spacing: 0) {
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
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    comparisonRow(row, showDivider: index < rows.count - 1)
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

    private func comparisonRow(_ row: RoundSeasonComparison.Row, showDivider: Bool) -> some View {
        HStack(alignment: .center) {
            Text(row.title)
                .font(.glSubhead)
                .foregroundColor(.textSecondary)
            Spacer()
            if let roundText = row.roundText {
                HStack(spacing: 32) {
                    Text(roundText)
                        .font(GLFonts.mono(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(minWidth: 48, alignment: .trailing)
                    Text(row.seasonText ?? "—")
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
}
