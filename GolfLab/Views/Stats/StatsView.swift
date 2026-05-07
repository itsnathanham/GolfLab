import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var timeRange: TimeRange = .season
    @State private var selectedSeasonYear = Calendar.current.component(.year, from: Date())
    @State private var holesForStats: [Hole] = []
    @State private var isLoadingHoles = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    statsTopBar
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, 14)

                    if roundStore.isLoadingRounds {
                        statsLoadingState
                    } else if filteredRounds.count < 2 {
                        insufficientDataView
                    } else {
                        timeRangePicker
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 18)

                        statsFourUpGrid
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        statsTrendCard(
                            title: "Scoring trend",
                            values: scoringVsParSeries,
                            height: 80,
                            seriesColor: .accent,
                            showParZeroLine: true,
                            valueFormatter: Self.formatVsParEndpoint
                        )
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 12)

                        statsTrendCard(
                            title: "GIR %",
                            values: girSeries,
                            height: 60,
                            seriesColor: .accent,
                            showParZeroLine: false,
                            valueFormatter: { String(format: "%.0f%%", $0) }
                        )
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 12)

                        statsTrendCard(
                            title: "Putts / hole",
                            values: puttsPerHoleSeries,
                            height: 60,
                            seriesColor: .textSecondary,
                            showParZeroLine: false,
                            valueFormatter: { String(format: "%.1f", $0) }
                        )
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 12)

                        avgScoreByParCard
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await roundStore.loadRounds()
            normalizeSelectedSeasonYear()
            StatsSeasonFilter.persistStatsSeasonPickerYear(selectedSeasonYear)
        }
        .task(id: holesFetchTaskID) {
            await loadHolesForFilteredRounds()
        }
        .onChange(of: roundStore.roundsListEpoch) { _, _ in
            normalizeSelectedSeasonYear()
        }
        .onChange(of: selectedSeasonYear) { _, newYear in
            StatsSeasonFilter.persistStatsSeasonPickerYear(newYear)
        }
    }

    // MARK: - Top bar (reference: wordmark + screen title)

    private var statsTopBar: some View {
        GLHubRootTopBar(screenTitle: "Stats")
    }

    // MARK: - Pills

    private var timeRangePicker: some View {
        HStack(spacing: 6) {
            if isSeasonYearSelectable {
                Menu {
                    ForEach(availableSeasonYears, id: \.self) { year in
                        Button {
                            selectedSeasonYear = year
                            timeRange = .season
                        } label: {
                            if year == resolvedSeasonYearValue {
                                Label(String(year), systemImage: "checkmark")
                            } else {
                                Text(String(year))
                            }
                        }
                    }
                } label: {
                    GLSelectionPillLabel(
                        title: "\(resolvedSeasonYearValue) v",
                        isSelected: timeRange == .season
                    )
                }
            } else {
                GLSelectionPill(title: String(resolvedSeasonYearValue), isSelected: timeRange == .season) {
                    timeRange = .season
                }
            }

            ForEach([TimeRange.last10, TimeRange.allTime], id: \.self) { range in
                GLSelectionPill(title: range.pillTitle, isSelected: timeRange == range) {
                    timeRange = range
                }
            }
        }
    }

    // MARK: - 2×2 stat strip

    private var statsFourUpGrid: some View {
        let rounds = chronologicalRounds
        let avgVsPar = averageScoreVsPar(for: rounds)
        let girPct = girPercentage(for: rounds)
        let pph = puttsPerHole(for: rounds)
        let firPct = firPercentageFromHoles(holesForStats)

        let scoreText = avgVsPar.map { formatAvgVsPar($0) } ?? "—"
        let scoreAccent = (avgVsPar ?? 0) <= 0

        let girText: String = {
            guard let v = girPct else { return "—" }
            return String(format: "%.0f", v)
        }()

        let puttsText = pph.map { String(format: "%.1f", $0) } ?? "—"

        let firText: String = {
            if let p = firPct { return String(format: "%.0f", p) }
            if isLoadingHoles { return "…" }
            return "—"
        }()

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                GLStatStripCell(
                    label: "Avg score",
                    value: scoreText,
                    valueUsesAccent: scoreAccent && avgVsPar != nil
                )
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1)
                GLStatStripCell(label: "FIR %", value: firText, valueUsesAccent: false)
            }
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
            HStack(spacing: 0) {
                GLStatStripCell(label: "GIR %", value: girText, valueUsesAccent: false)
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1)
                GLStatStripCell(label: "Putts / hole", value: puttsText, valueUsesAccent: false)
            }
        }
        .background(Color.borderDefault)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    // MARK: - Trend panels

    private func statsTrendCard(
        title: String,
        values: [Double],
        height: CGFloat,
        seriesColor: Color,
        showParZeroLine: Bool,
        valueFormatter: @escaping (Double) -> String
    ) -> some View {
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return GLStatTrendCard(title: title) {
            Group {
                if values.isEmpty {
                    Text("No data yet")
                        .font(.glSubhead)
                        .foregroundColor(.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: height)
                } else {
                    VsParTrendChartView(
                        values: values,
                        height: height,
                        averageVsPar: average,
                        showZeroLine: showParZeroLine,
                        style: .accentSparkline,
                        showEndpointLabel: true,
                        introAnimation: .accentSparklineStats,
                        introReplayToken: statsIntroReplayToken,
                        sparklineSeriesColor: seriesColor,
                        sparklineValueFormatter: valueFormatter
                    )
                }
            }
        }
    }

    // MARK: - Avg score by par

    private var avgScoreByParCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            GLTrendCardHeader(title: "Avg score by par")

            VStack(spacing: 10) {
                if isLoadingHoles && holesForStats.isEmpty {
                    ProgressView()
                        .tint(.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else if avgScoreByParRows.isEmpty {
                    Text("Save hole-by-hole scorecards to see averages by par.")
                        .font(.glFootnote)
                        .foregroundColor(.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(avgScoreByParRows, id: \.par) { row in
                        avgScoreByParRow(row: row)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    private struct ParAvgRow: Sendable {
        let par: Int
        let avgScore: Double
        let holeCount: Int
    }

    private var avgScoreByParRows: [ParAvgRow] {
        let grouped = Dictionary(grouping: holesForStats.filter { [3, 4, 5].contains($0.par) }) { $0.par }
        return [3, 4, 5].compactMap { p -> ParAvgRow? in
            guard let hs = grouped[p], !hs.isEmpty else { return nil }
            let sum = hs.reduce(0) { $0 + $1.score }
            let avg = Double(sum) / Double(hs.count)
            return ParAvgRow(par: p, avgScore: avg, holeCount: hs.count)
        }
    }

    private func avgScoreByParRow(row: ParAvgRow) -> some View {
        let maxAvg = max(avgScoreByParRows.map(\.avgScore).max() ?? 1, 0.01)
        let widthFrac = min(1, row.avgScore / maxAvg)
        let atOrUnderPar = row.avgScore <= Double(row.par) + 0.001
        let barColor: Color = atOrUnderPar ? .accent : .chartNegative

        return HStack(alignment: .center, spacing: 10) {
            Text("Par \(row.par)")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.bgElevated)
                        .frame(height: 5)
                    Capsule()
                        .fill(barColor.opacity(0.4))
                        .frame(width: max(4, geo.size.width * widthFrac), height: 5)
                }
            }
            .frame(height: 5)

            Text(String(format: "%.1f", row.avgScore))
                .font(GLFonts.mono(size: 12, weight: .semibold))
                .foregroundColor(barColor)
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    // MARK: - Empty / loading

    private var insufficientDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.accent)
            Text("Log \(max(0, 2 - filteredRounds.count)) more round\(filteredRounds.count == 1 ? "" : "s") to see trends")
                .font(.glHeadline)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, GLLayout.horizontalInset)
    }

    private var statsLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.accent)
            Text("Loading stats...")
                .font(.glSubhead)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .top)
        .padding(.horizontal, GLLayout.horizontalInset)
        .padding(.top, 12)
    }

    // MARK: - Series (chronological)

    /// Cached hole rows grouped by round (used so GIR% and putts/hole match scorecard denominators).
    private var holesByRoundId: [UUID: [Hole]] {
        Dictionary(grouping: holesForStats, by: \.roundId)
    }

    private var chronologicalRounds: [Round] {
        filteredRounds.reversed()
    }

    /// Holes counted for a round: saved rows when known, else planned `Round.holes`.
    private func holeCountDenominator(for r: Round, cached: [Hole]?) -> Int {
        if let cached, !cached.isEmpty { return cached.count }
        let stored = roundStore.holeRowCountByRoundId[r.id] ?? 0
        if stored > 0 { return stored }
        return r.holes
    }

    private var scoringVsParSeries: [Double] {
        chronologicalRounds.compactMap { r in
            guard let score = r.totalScore,
                  let parSum = roundStore.totalParSumByRoundId[r.id]
            else { return nil }
            return Double(score - parSum)
        }
    }

    /// Per-round GIR% = GIR hits ÷ holes in that round (hole rows when loaded, else round totals + row count).
    private var girSeries: [Double] {
        let byRound = holesByRoundId
        return chronologicalRounds.compactMap { r in
            let cached = byRound[r.id]
            let n = holeCountDenominator(for: r, cached: cached)
            guard n > 0 else { return nil }
            let hits: Int
            if let cached, !cached.isEmpty {
                hits = cached.filter(\.gir).count
            } else if let total = r.totalGir {
                hits = total
            } else {
                return nil
            }
            return Double(hits) / Double(n) * 100
        }
    }

    /// Per-round putts per hole = total putts ÷ holes in that round (same denominator rules as GIR%).
    private var puttsPerHoleSeries: [Double] {
        let byRound = holesByRoundId
        return chronologicalRounds.compactMap { r in
            let cached = byRound[r.id]
            let n = holeCountDenominator(for: r, cached: cached)
            guard n > 0 else { return nil }
            let putts: Int
            if let cached, !cached.isEmpty {
                putts = cached.reduce(0) { $0 + $1.putts }
            } else if let total = r.totalPutts {
                putts = total
            } else {
                return nil
            }
            return Double(putts) / Double(n)
        }
    }

    private var statsIntroReplayToken: AnyHashable {
        "\(timeRange)-\(resolvedSeasonYearValue)-\(chronologicalRounds.count)-\(holesForStats.count)-\(chronologicalRounds.first?.id.uuidString ?? "")"
    }

    private var filteredRounds: [Round] {
        switch timeRange {
        case .season:
            return roundStore.allRounds.filter { $0.datePlayed.hasPrefix("\(resolvedSeasonYearValue)") }
        case .last10:
            return roundStore.allRounds.lastRoundsByDatePlayed(10)
        case .allTime:
            return roundStore.allRounds
        }
    }

    /// Reloads when the server-backed round list changes (`roundsListEpoch`) or filters change.
    /// Uses newest/oldest round ids (not a full id join) so `.task` stays cheap to evaluate.
    private var holesFetchTaskID: String {
        let rounds = filteredRounds
        let sorted = rounds.sortedByDatePlayedDescending()
        let newest = sorted.first?.id.uuidString ?? "none"
        let oldest = sorted.last?.id.uuidString ?? "none"
        return "\(roundStore.roundsListEpoch)|\(timeRange)|\(resolvedSeasonYearValue)|\(rounds.count)|\(newest)|\(oldest)"
    }

    private var availableSeasonYears: [Int] {
        StatsSeasonFilter.availableSeasonYears(from: roundStore.allRounds)
    }

    private var resolvedSeasonYearValue: Int {
        StatsSeasonFilter.resolvedSeasonYear(rounds: roundStore.allRounds, selectedSeasonYear: selectedSeasonYear)
    }

    private var isSeasonYearSelectable: Bool {
        availableSeasonYears.count > 1
    }

    private func normalizeSelectedSeasonYear() {
        selectedSeasonYear = resolvedSeasonYearValue
    }

    private static func formatVsParEndpoint(_ v: Double) -> String {
        if abs(v.rounded() - v) < 0.05 {
            return String(format: "%+.0f", v)
        }
        return String(format: "%+.1f", v)
    }

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

    private func firPercentageFromHoles(_ holes: [Hole]) -> Double? {
        let eligible = holes.filter { $0.par > 3 }
        guard !eligible.isEmpty else { return nil }
        let hits = eligible.filter { $0.fir == true }.count
        return Double(hits) / Double(eligible.count) * 100
    }

    private func formatAvgVsPar(_ v: Double) -> String {
        if abs(v - v.rounded()) < 0.05 {
            return String(format: "%+.0f", v)
        }
        return String(format: "%+.1f", v)
    }

    private func loadHolesForFilteredRounds() async {
        guard !filteredRounds.isEmpty else {
            await MainActor.run {
                holesForStats = []
                isLoadingHoles = false
            }
            return
        }
        await MainActor.run {
            isLoadingHoles = true
            holesForStats = []
        }
        var collected: [Hole] = []
        await withTaskGroup(of: [Hole].self) { group in
            for id in filteredRounds.map(\.id) {
                group.addTask {
                    (try? await SupabaseService.shared.fetchHoles(roundId: id)) ?? []
                }
            }
            for await chunk in group {
                collected.append(contentsOf: chunk)
            }
        }
        await MainActor.run {
            holesForStats = collected
            isLoadingHoles = false
        }
    }
}

// MARK: - ChartPoint (shared with `VsParScoreStatsCard`)

struct ChartPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
    let label: String
}
