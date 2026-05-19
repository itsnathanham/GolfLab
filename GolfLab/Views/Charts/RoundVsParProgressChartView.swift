import SwiftUI

// MARK: - Series (cumulative strokes vs par)

struct RoundVsParProgressSeries {
    struct Point: Equatable {
        let hole: Int
        let cumulativeVsPar: Double
    }

    let solid: [Point]
    /// Vertical continuation at last cumulative value through remaining holes (incomplete rounds).
    let dottedTail: [Point]?

    /// Persisted hole rows from history / last round.
    init?(holes: [Hole], totalHoles: Int) {
        let entries = holes.map { ScoredEntry(holeNumber: $0.holeNumber, vsPar: $0.score - $0.par) }
        self.init(scoredEntries: entries, totalHoles: totalHoles)
    }

    /// End-round sheet: only saved holes on the active card.
    init?(savedHoles: [ActiveHole], totalHoles: Int) {
        let entries = savedHoles.filter(\.isSaved).map { ScoredEntry(holeNumber: $0.holeNumber, vsPar: $0.score - $0.par) }
        self.init(scoredEntries: entries, totalHoles: totalHoles)
    }

    private struct ScoredEntry {
        let holeNumber: Int
        let vsPar: Int
    }

    private init?(scoredEntries: [ScoredEntry], totalHoles: Int) {
        guard totalHoles > 0, !scoredEntries.isEmpty else { return nil }
        let sorted = scoredEntries.sorted { $0.holeNumber < $1.holeNumber }

        var solid: [Point] = []
        var cum = 0.0
        for entry in sorted {
            cum += Double(entry.vsPar)
            solid.append(Point(hole: entry.holeNumber, cumulativeVsPar: cum))
        }

        guard let lastPt = solid.last else { return nil }
        var tail: [Point] = []
        if lastPt.hole < totalHoles {
            for hn in (lastPt.hole + 1)...totalHoles {
                tail.append(Point(hole: hn, cumulativeVsPar: lastPt.cumulativeVsPar))
            }
        }

        self.solid = solid
        self.dottedTail = tail.isEmpty ? nil : tail
    }
}

// MARK: - Chart (X = hole, Y = cumulative vs par)

/// Horizontal axis: hole number. Vertical axis: cumulative score vs par.
struct RoundVsParProgressChartView: View {
    let series: RoundVsParProgressSeries
    let totalHoles: Int

    private let plotHeight: CGFloat = 168
    /// Leading space for Y-axis labels (matches `VsParTrendChartView` sparkline `plotLeading` intent).
    private let horizontalMargin: CGFloat = 36
    /// Trailing inset so the last hole’s marker + halo aren’t clipped (`VsParTrendChartView` uses 12pt `plotTrailing` without endpoint label).
    private let horizontalPlotTrailing: CGFloat = 12
    private let verticalMarginTop: CGFloat = 8
    private let verticalMarginBottom: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = plotHeight
            let plotW = max(1, w - horizontalMargin - horizontalPlotTrailing)
            let plotH = max(1, h - verticalMarginTop - verticalMarginBottom)
            let domain = yDomain(for: series)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    drawChart(
                        context: ctx,
                        size: CGSize(width: w, height: h),
                        plotW: plotW,
                        plotH: plotH,
                        domain: domain
                    )
                }
                .frame(width: w, height: h)

                axisLabels(width: w, height: h, plotH: plotH, domain: domain)
            }
        }
        .frame(height: plotHeight)
    }

    private func yDomain(for series: RoundVsParProgressSeries) -> (lo: Double, hi: Double) {
        var vals: [Double] = [0]
        vals.append(contentsOf: series.solid.map(\.cumulativeVsPar))
        if let t = series.dottedTail { vals.append(contentsOf: t.map(\.cumulativeVsPar)) }
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 0
        var lo = min(minV, 0)
        var hi = max(maxV, 0)
        if abs(hi - lo) < 1e-6 {
            lo -= 1
            hi += 1
        }
        let span = hi - lo
        let pad = max(span * 0.06, 0.5)
        return (lo - pad, hi + pad)
    }

    /// Hole 0 maps to x = 0 (the even-par origin on the Y axis); hole `totalHoles` lands at the right edge.
    /// This places the first scored hole one slot to the right of the Y axis so the line can begin at E.
    private func xPos(hole: Int, plotW: CGFloat) -> CGFloat {
        guard totalHoles > 0 else { return 0 }
        let t = Double(hole) / Double(totalHoles)
        return CGFloat(t) * plotW
    }

    /// Positive deltas are higher on the chart, zero is the even-par baseline.
    private func yPos(_ v: Double, plotH: CGFloat, domain: (lo: Double, hi: Double)) -> CGFloat {
        let t = (v - domain.lo) / (domain.hi - domain.lo)
        return plotH - (CGFloat(t) * plotH)
    }

    private func drawChart(
        context ctx: GraphicsContext,
        size: CGSize,
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double)
    ) {
        let originX = horizontalMargin
        let originY = verticalMarginTop

        let integerGridDash = StrokeStyle(lineWidth: 1, dash: [4, 3])
        let integerGridColor = Color.borderDefault

        // Dashed horizontal line at each whole-number vs par (excluding E, drawn solid below).
        let kLo = Int(Darwin.ceil(domain.lo - 1e-9))
        let kHi = Int(Darwin.floor(domain.hi + 1e-9))
        if kLo <= kHi {
            for k in kLo...kHi where k != 0 {
                let y = originY + yPos(Double(k), plotH: plotH, domain: domain)
                var p = Path()
                p.move(to: CGPoint(x: originX, y: y))
                p.addLine(to: CGPoint(x: originX + plotW, y: y))
                ctx.stroke(p, with: .color(integerGridColor), style: integerGridDash)
            }
        }

        // Even-par (E): single solid horizontal reference at cumulative vs par = 0.
        if domain.lo <= 0, domain.hi >= 0 {
            let zy = originY + yPos(0, plotH: plotH, domain: domain)
            var zp = Path()
            zp.move(to: CGPoint(x: originX, y: zy))
            zp.addLine(to: CGPoint(x: originX + plotW, y: zy))
            ctx.stroke(zp, with: .color(integerGridColor), style: StrokeStyle(lineWidth: 1))
        }

        // Solid path and markers. Always anchor the line at E on the Y axis (hole 0, vs par 0)
        // so the first scored hole's marker sits one slot to the right of the Y axis.
        let solidPoints = series.solid
        if !solidPoints.isEmpty {
            let startX = originX + xPos(hole: 0, plotW: plotW)
            let startY = originY + yPos(0, plotH: plotH, domain: domain)
            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            for p in solidPoints {
                let cx = originX + xPos(hole: p.hole, plotW: plotW)
                let cy = originY + yPos(p.cumulativeVsPar, plotH: plotH, domain: domain)
                path.addLine(to: CGPoint(x: cx, y: cy))
            }
            ctx.stroke(path, with: .color(Color.accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            for p in solidPoints {
                let cx = originX + xPos(hole: p.hole, plotW: plotW)
                let cy = originY + yPos(p.cumulativeVsPar, plotH: plotH, domain: domain)
                let r: CGFloat = 3
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)),
                    with: .color(Color.accent.opacity(0.12))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                    with: .color(Color.accent)
                )
            }
        }

        // Dotted tail (incomplete); the join is the last solid hole's marker.
        if let tail = series.dottedTail, !tail.isEmpty, let join = series.solid.last {
            var path = Path()
            let sx = originX + xPos(hole: join.hole, plotW: plotW)
            let sy = originY + yPos(join.cumulativeVsPar, plotH: plotH, domain: domain)
            path.move(to: CGPoint(x: sx, y: sy))
            for p in tail {
                let cx = originX + xPos(hole: p.hole, plotW: plotW)
                let cy = originY + yPos(p.cumulativeVsPar, plotH: plotH, domain: domain)
                path.addLine(to: CGPoint(x: cx, y: cy))
            }
            ctx.stroke(
                path,
                with: .color(Color.textTertiary.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [5, 4])
            )
        }
    }

    private func axisLabels(width: CGFloat, height: CGFloat, plotH: CGFloat, domain: (lo: Double, hi: Double)) -> some View {
        let originY = verticalMarginTop
        return ZStack(alignment: .topLeading) {
            Text("Score")
                .font(.glAxis)
                .foregroundColor(Color.black.opacity(0.18))
                .rotationEffect(.degrees(-90))
                .position(x: 16, y: originY + plotH / 2)

            if domain.lo <= 0, domain.hi >= 0 {
                Text("E")
                    .font(.glAxis)
                    .foregroundColor(Color.black.opacity(0.18))
                    .position(
                        x: horizontalMargin - 10,
                        y: originY + yPos(0, plotH: plotH, domain: domain)
                    )
            }

            Text("Hole")
                .font(.glAxis)
                .foregroundColor(Color.black.opacity(0.18))
                .frame(width: width, height: height, alignment: .bottom)
                .padding(.bottom, 4)
        }
    }
}

// MARK: - Card wrapper

struct RoundVsParProgressCard: View {
    let holes: [Hole]
    let totalHoles: Int

    var body: some View {
        if let series = RoundVsParProgressSeries(holes: holes, totalHoles: totalHoles) {
            GLStatTrendCard(title: "Vs par progression") {
                RoundVsParProgressChartView(series: series, totalHoles: totalHoles)
            }
        }
    }
}

struct RoundVsParProgressCardActive: View {
    let savedHoles: [ActiveHole]
    let totalHoles: Int

    var body: some View {
        if let series = RoundVsParProgressSeries(savedHoles: savedHoles, totalHoles: totalHoles) {
            GLStatTrendCard(title: "Vs par progression") {
                RoundVsParProgressChartView(series: series, totalHoles: totalHoles)
            }
        }
    }
}
