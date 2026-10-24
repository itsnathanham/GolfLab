import SwiftUI
import UIKit

// MARK: - Series

struct VsParLineChartSeries {
    struct Point: Equatable {
        let xIndex: Int
        let value: Double
    }

    let solid: [Point]
    let dottedTail: [Point]?

    init?(holes: [Hole], totalHoles: Int) {
        let entries = holes.map { ScoredEntry(xIndex: $0.holeNumber, value: $0.score - $0.par) }
        self.init(scoredEntries: entries, totalXSlots: totalHoles)
    }

    init?(savedHoles: [ActiveHole], totalHoles: Int) {
        let entries = savedHoles.filter(\.isSaved).map { ScoredEntry(xIndex: $0.holeNumber, value: $0.score - $0.par) }
        self.init(scoredEntries: entries, totalXSlots: totalHoles)
    }

    init?(roundValues: [Double]) {
        guard !roundValues.isEmpty else { return nil }
        solid = roundValues.enumerated().map { index, value in
            Point(xIndex: index + 1, value: value)
        }
        dottedTail = nil
    }

    init(solid: [Point], dottedTail: [Point]?) {
        self.solid = solid
        self.dottedTail = dottedTail
    }

    private struct ScoredEntry {
        let xIndex: Int
        let value: Int
    }

    private init?(scoredEntries: [ScoredEntry], totalXSlots: Int) {
        guard totalXSlots > 0, !scoredEntries.isEmpty else { return nil }
        let sorted = scoredEntries.sorted { $0.xIndex < $1.xIndex }

        var built: [Point] = []
        var running = 0.0
        for entry in sorted {
            running += Double(entry.value)
            built.append(Point(xIndex: entry.xIndex, value: running))
        }

        guard let lastPt = built.last else { return nil }
        var tail: [Point] = []
        if lastPt.xIndex < totalXSlots {
            for slot in (lastPt.xIndex + 1)...totalXSlots {
                tail.append(Point(xIndex: slot, value: lastPt.value))
            }
        }

        self.solid = built
        self.dottedTail = tail.isEmpty ? nil : tail
    }
}

// MARK: - Chart configuration

enum GLTrendChartMetrics {
    static let chartHeight: CGFloat = 168
    static let axisLabelForeground = Color.textSecondary
    static let defaultYAxisLeadingMargin: CGFloat = 16
}

enum VsParLineChartGridStyle: Equatable {
    case vsParStrokes
    case step(Double)
}

enum VsParLineStrokeStyle: Equatable {
    case solid
    case dashed
}

struct VsParLineChartOverlay {
    let series: VsParLineChartSeries
    var color: Color = .chartSeasonAverage
    var strokeStyle: VsParLineStrokeStyle = .dashed
    var lineWidth: CGFloat = 1
    var showPointMarkers: Bool = false
}

struct VsParLineChartView: View {
    let series: VsParLineChartSeries
    let totalXSlots: Int
    let xAxisLabel: String
    let yAxisLabel: String
    var overlaySeries: [VsParLineChartOverlay] = []
    var gridStyle: VsParLineChartGridStyle = .vsParStrokes
    var anchorLineAtEvenPar: Bool = true
    var yAxisLeadingMargin: CGFloat = GLTrendChartMetrics.defaultYAxisLeadingMargin
    var showLastValueLabel: Bool = false
    var lastValueFormatter: ((Double) -> String)? = nil
    var seriesColor: Color = .accent
    var primaryStrokeStyle: VsParLineStrokeStyle = .solid
    var showsAreaGradient: Bool = true

    @State private var selectedPointIndex: Int?
    @State private var gestureActive = false
    @State private var touchAnchorIndex: Int?
    @State private var hoverPointIndex: Int?

    private let plotHeight = GLTrendChartMetrics.chartHeight
    private let horizontalPlotTrailing: CGFloat = 6
    private let horizontalPlotTrailingWithLabel: CGFloat = 16
    private let verticalMarginTop: CGFloat = 8
    private let verticalMarginBottom: CGFloat = 22

    private var plotTrailingInset: CGFloat {
        showLastValueLabel ? horizontalPlotTrailingWithLabel : horizontalPlotTrailing
    }

    private var activePointIndex: Int? {
        hoverPointIndex ?? selectedPointIndex
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = plotHeight
            let plotW = max(1, w - yAxisLeadingMargin - plotTrailingInset)
            let plotH = max(1, h - verticalMarginTop - verticalMarginBottom)
            let domain = yDomain(for: series, overlays: overlaySeries.map(\.series))

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

                if showLastValueLabel, let last = series.solid.last, activePointIndex == nil {
                    let pt = plotPoint(for: last, plotW: plotW, plotH: plotH, domain: domain)
                    let labelText = formattedValue(last.value)
                    Text(labelText)
                        .font(.glAxis)
                        .foregroundColor(seriesColor)
                        .position(
                            x: min(pt.x + 8, w - 14),
                            y: max(12, pt.y - 12)
                        )
                }

                if let index = activePointIndex, series.solid.indices.contains(index) {
                    let point = series.solid[index]
                    let plotted = plotPoint(for: point, plotW: plotW, plotH: plotH, domain: domain)
                    pointCallout(text: formattedValue(point.value), at: plotted, width: w)
                }
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(plotW: plotW, plotH: plotH, domain: domain))
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverPointIndex = nearestSolidIndex(
                        atX: location.x,
                        plotW: plotW,
                        plotH: plotH,
                        domain: domain
                    )
                case .ended:
                    hoverPointIndex = nil
                @unknown default:
                    hoverPointIndex = nil
                }
            }
        }
        .frame(height: plotHeight)
        .accessibilityLabel(yAxisLabel)
    }

    private func formattedValue(_ value: Double) -> String {
        lastValueFormatter?(value) ?? Self.formatVsPar(value)
    }

    private func pointCallout(text: String, at point: CGPoint, width: CGFloat) -> some View {
        Text(text)
            .font(GLFonts.mono(size: 12, weight: .semibold))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(seriesColor.opacity(0.55), lineWidth: 1)
            )
            .fixedSize()
            .position(x: min(max(point.x, 28), width - 28), y: max(14, point.y - 22))
            .allowsHitTesting(false)
    }

    private func scrubGesture(
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double)
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !gestureActive {
                    gestureActive = true
                    touchAnchorIndex = selectedPointIndex
                }
                let index = nearestSolidIndex(
                    atX: value.location.x,
                    plotW: plotW,
                    plotH: plotH,
                    domain: domain
                )
                guard index != selectedPointIndex else { return }
                if index != nil {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                selectedPointIndex = index
            }
            .onEnded { value in
                let travel = hypot(value.translation.width, value.translation.height)
                if travel < 10, selectedPointIndex == touchAnchorIndex {
                    selectedPointIndex = nil
                }
                gestureActive = false
                touchAnchorIndex = nil
            }
    }

    private func nearestSolidIndex(
        atX x: CGFloat,
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double)
    ) -> Int? {
        guard !series.solid.isEmpty else { return nil }
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, point) in series.solid.enumerated() {
            let plotted = plotPoint(for: point, plotW: plotW, plotH: plotH, domain: domain)
            let distance = abs(plotted.x - x)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func plotPoint(
        for point: VsParLineChartSeries.Point,
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double)
    ) -> CGPoint {
        CGPoint(
            x: yAxisLeadingMargin + xPos(xIndex: point.xIndex, plotW: plotW),
            y: verticalMarginTop + yPos(point.value, plotH: plotH, domain: domain)
        )
    }

    static func formatVsPar(_ value: Double) -> String {
        GLMetricFormat.vsParStrokes(value)
    }

    private func yDomain(for series: VsParLineChartSeries, overlays: [VsParLineChartSeries] = []) -> (lo: Double, hi: Double) {
        var vals = series.solid.map(\.value)
        if let t = series.dottedTail { vals.append(contentsOf: t.map(\.value)) }
        for overlay in overlays {
            vals.append(contentsOf: overlay.solid.map(\.value))
            if let tail = overlay.dottedTail { vals.append(contentsOf: tail.map(\.value)) }
        }
        guard let minV = vals.min(), let maxV = vals.max() else { return (-1, 1) }

        switch gridStyle {
        case .vsParStrokes:
            var lo = min(minV, 0)
            var hi = max(maxV, 0)
            if abs(hi - lo) < 1e-6 {
                lo -= 1
                hi += 1
            }
            let pad = max((hi - lo) * 0.06, 0.5)
            return (lo - pad, hi + pad)

        case .step(let step):
            guard step > 0 else { return (minV - 1, maxV + 1) }
            let lo = floor(minV / step) * step
            var hi = ceil(maxV / step) * step
            if hi - lo < step { hi = lo + step }
            let pad = step * 0.5
            return (lo - pad, hi + pad)
        }
    }

    private func xPos(xIndex: Int, plotW: CGFloat) -> CGFloat {
        guard totalXSlots > 0 else { return 0 }
        if anchorLineAtEvenPar {
            let t = Double(xIndex) / Double(totalXSlots)
            return CGFloat(t) * plotW
        }
        let n = series.solid.count
        guard n > 1 else { return plotW / 2 }
        let slot = min(max(xIndex - 1, 0), n - 1)
        let t = Double(slot) / Double(n - 1)
        return CGFloat(t) * plotW
    }

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
        let originX = yAxisLeadingMargin
        let originY = verticalMarginTop
        let gridDash = StrokeStyle(lineWidth: 1, dash: [4, 3])
        let gridColor = Color.borderDefault

        switch gridStyle {
        case .vsParStrokes:
            let kLo = Int(Darwin.ceil(domain.lo - 1e-9))
            let kHi = Int(Darwin.floor(domain.hi + 1e-9))
            if kLo <= kHi {
                for k in kLo...kHi where k != 0 {
                    strokeHorizontalGridLine(
                        context: ctx, y: Double(k),
                        originX: originX, originY: originY,
                        plotW: plotW, plotH: plotH, domain: domain,
                        color: gridColor, style: gridDash
                    )
                }
            }
            if domain.lo <= 0, domain.hi >= 0 {
                strokeHorizontalGridLine(
                    context: ctx, y: 0,
                    originX: originX, originY: originY,
                    plotW: plotW, plotH: plotH, domain: domain,
                    color: gridColor,
                    style: StrokeStyle(lineWidth: 1)
                )
            }

        case .step(let step):
            guard step > 0 else { break }
            var y = floor(domain.lo / step) * step
            while y <= domain.hi + step * 0.001 {
                strokeHorizontalGridLine(
                    context: ctx, y: y,
                    originX: originX, originY: originY,
                    plotW: plotW, plotH: plotH, domain: domain,
                    color: gridColor, style: gridDash
                )
                y += step
            }
        }

        for overlay in overlaySeries {
            strokeSeriesLine(
                context: ctx,
                series: overlay.series,
                color: overlay.color,
                strokeStyle: overlay.strokeStyle,
                lineWidth: overlay.lineWidth,
                originX: originX,
                originY: originY,
                plotW: plotW,
                plotH: plotH,
                domain: domain,
                drawMarkers: overlay.showPointMarkers,
                showsAreaGradient: false
            )
        }

        strokeSeriesLine(
            context: ctx,
            series: series,
            color: seriesColor,
            strokeStyle: primaryStrokeStyle,
            lineWidth: 2.5,
            originX: originX,
            originY: originY,
            plotW: plotW,
            plotH: plotH,
            domain: domain,
            drawMarkers: true,
            showsAreaGradient: showsAreaGradient
        )

        if let tail = series.dottedTail, !tail.isEmpty, let join = series.solid.last {
            var path = Path()
            path.move(to: plotPoint(for: join, plotW: plotW, plotH: plotH, domain: domain))
            for p in tail {
                path.addLine(to: plotPoint(for: p, plotW: plotW, plotH: plotH, domain: domain))
            }
            ctx.stroke(
                path,
                with: .color(Color.textTertiary.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [5, 4])
            )
        }
    }

    private func strokeSeriesLine(
        context ctx: GraphicsContext,
        series: VsParLineChartSeries,
        color: Color,
        strokeStyle: VsParLineStrokeStyle,
        lineWidth: CGFloat,
        originX: CGFloat,
        originY: CGFloat,
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double),
        drawMarkers: Bool,
        showsAreaGradient: Bool
    ) {
        let solidPoints = series.solid
        guard !solidPoints.isEmpty else { return }

        // Build line path
        var path = Path()
        if anchorLineAtEvenPar {
            let startX = originX + xPos(xIndex: 0, plotW: plotW)
            let startY = originY + yPos(0, plotH: plotH, domain: domain)
            path.move(to: CGPoint(x: startX, y: startY))
        } else if let first = solidPoints.first {
            path.move(to: plotPoint(for: first, plotW: plotW, plotH: plotH, domain: domain))
        }
        let linePoints = anchorLineAtEvenPar ? solidPoints : Array(solidPoints.dropFirst())
        for p in linePoints {
            path.addLine(to: plotPoint(for: p, plotW: plotW, plotH: plotH, domain: domain))
        }

        if strokeStyle == .solid && showsAreaGradient {
            var fillPath = Path()
            if anchorLineAtEvenPar {
                let startX = originX + xPos(xIndex: 0, plotW: plotW)
                let startY = originY + yPos(0, plotH: plotH, domain: domain)
                fillPath.move(to: CGPoint(x: startX, y: originY + plotH))
                fillPath.addLine(to: CGPoint(x: startX, y: startY))
            } else if let first = solidPoints.first {
                let pt = plotPoint(for: first, plotW: plotW, plotH: plotH, domain: domain)
                fillPath.move(to: CGPoint(x: pt.x, y: originY + plotH))
                fillPath.addLine(to: pt)
            }
            for p in linePoints {
                fillPath.addLine(to: plotPoint(for: p, plotW: plotW, plotH: plotH, domain: domain))
            }
            if let last = solidPoints.last {
                let lastPt = plotPoint(for: last, plotW: plotW, plotH: plotH, domain: domain)
                fillPath.addLine(to: CGPoint(x: lastPt.x, y: originY + plotH))
            }
            fillPath.closeSubpath()

            ctx.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.50), location: 0),
                        .init(color: color.opacity(0.18), location: 0.42),
                        .init(color: color.opacity(0.04), location: 0.75),
                        .init(color: color.opacity(0), location: 1)
                    ]),
                    startPoint: CGPoint(x: originX + plotW / 2, y: originY),
                    endPoint: CGPoint(x: originX + plotW / 2, y: originY + plotH)
                )
            )
        }

        // Draw line
        var lineStroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        if strokeStyle == .dashed {
            lineStroke.dash = [5, 5]
        }
        ctx.stroke(path, with: .color(color), style: lineStroke)

        // Draw point markers
        if drawMarkers {
            for p in solidPoints {
                Self.drawSeriesPointMarker(
                    context: ctx,
                    at: plotPoint(for: p, plotW: plotW, plotH: plotH, domain: domain),
                    color: color
                )
            }
        }
    }

    private func strokeHorizontalGridLine(
        context ctx: GraphicsContext,
        y: Double,
        originX: CGFloat,
        originY: CGFloat,
        plotW: CGFloat,
        plotH: CGFloat,
        domain: (lo: Double, hi: Double),
        color: Color,
        style: StrokeStyle
    ) {
        let lineY = originY + yPos(y, plotH: plotH, domain: domain)
        var p = Path()
        p.move(to: CGPoint(x: originX, y: lineY))
        p.addLine(to: CGPoint(x: originX + plotW, y: lineY))
        ctx.stroke(p, with: .color(color), style: style)
    }

    private func axisLabels(width: CGFloat, height: CGFloat, plotH: CGFloat, domain: (lo: Double, hi: Double)) -> some View {
        let originY = verticalMarginTop
        return ZStack(alignment: .topLeading) {
            if case .vsParStrokes = gridStyle, domain.lo <= 0, domain.hi >= 0 {
                Text("E")
                    .font(.glAxis)
                    .foregroundColor(GLTrendChartMetrics.axisLabelForeground)
                    .position(
                        x: 8,
                        y: originY + yPos(0, plotH: plotH, domain: domain)
                    )
            }

            Text(xAxisLabel)
                .font(.glAxis)
                .foregroundColor(GLTrendChartMetrics.axisLabelForeground)
                .frame(width: width, height: height, alignment: .bottom)
                .padding(.bottom, 4)
        }
    }

    static func drawSeriesPointMarker(context: GraphicsContext, at p: CGPoint, color: Color) {
        let coreRadius: CGFloat = 4
        // Outer glow
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)),
            with: .color(color.opacity(0.15))
        )
        // Core dot
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - coreRadius, y: p.y - coreRadius, width: 2 * coreRadius, height: 2 * coreRadius)),
            with: .color(color)
        )
    }
}

// MARK: - Legend

struct VsParProgressionChartLegend: View {
    struct Item: Identifiable {
        let label: String
        let color: Color
        let strokeStyle: VsParLineStrokeStyle

        var id: String { label }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    legendSwatch(color: item.color, strokeStyle: item.strokeStyle)
                    Text(item.label)
                        .font(.glAxis)
                        .foregroundColor(GLTrendChartMetrics.axisLabelForeground)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func legendSwatch(color: Color, strokeStyle: VsParLineStrokeStyle) -> some View {
        let swatchWidth: CGFloat = 18
        if strokeStyle == .dashed {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 4, height: 2)
                }
            }
            .frame(width: swatchWidth, alignment: .leading)
        } else {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: swatchWidth, height: 2)
        }
    }
}

// MARK: - Card wrappers

struct RoundVsParProgressCard: View {
    private let series: VsParLineChartSeries?
    private let averageOverlay: VsParLineChartSeries?
    let totalHoles: Int

    init(holes: [Hole], totalHoles: Int, averageOverlay: VsParLineChartSeries? = nil) {
        self.series = VsParLineChartSeries(holes: holes, totalHoles: totalHoles)
        self.averageOverlay = averageOverlay
        self.totalHoles = totalHoles
    }

    init(savedHoles: [ActiveHole], totalHoles: Int, averageOverlay: VsParLineChartSeries? = nil) {
        self.series = VsParLineChartSeries(savedHoles: savedHoles, totalHoles: totalHoles)
        self.averageOverlay = averageOverlay
        self.totalHoles = totalHoles
    }

    var body: some View {
        if let series {
            let overlays = overlayConfiguration(for: series)
            GLStatTrendCard(title: "Vs par progression") {
                VStack(alignment: .leading, spacing: 8) {
                    VsParLineChartView(
                        series: series,
                        totalXSlots: totalHoles,
                        xAxisLabel: "Hole",
                        yAxisLabel: "Score",
                        overlaySeries: overlays,
                        showsAreaGradient: false
                    )
                    if !overlays.isEmpty {
                        VsParProgressionChartLegend(items: [
                            .init(label: "Season avg", color: .chartSeasonAverage, strokeStyle: .dashed),
                        ])
                    }
                }
            }
        }
    }

    private func overlayConfiguration(for roundSeries: VsParLineChartSeries) -> [VsParLineChartOverlay] {
        guard let averageOverlay else { return [] }
        let trimmed = trimmedAverageOverlay(for: roundSeries, average: averageOverlay)
        guard let trimmed else { return [] }
        return [VsParLineChartOverlay(series: trimmed)]
    }

    private func trimmedAverageOverlay(
        for roundSeries: VsParLineChartSeries,
        average: VsParLineChartSeries
    ) -> VsParLineChartSeries? {
        let maxHole = min(totalHoles, roundSeries.solid.last?.xIndex ?? totalHoles)
        let points = average.solid.filter { $0.xIndex <= maxHole }
        guard points.count == maxHole else { return nil }
        return VsParLineChartSeries(solid: points, dottedTail: nil)
    }
}

struct AvgVsParProgressionCard: View {
    let averageSeries: VsParLineChartSeries?

    var body: some View {
        GLStatTrendCard(title: "Avg vs par progression") {
            if let averageSeries {
                VStack(alignment: .leading, spacing: 8) {
                    VsParLineChartView(
                        series: averageSeries,
                        totalXSlots: VsParCumulativeProgression.chartHoleSlots,
                        xAxisLabel: "Hole",
                        yAxisLabel: "Score",
                        anchorLineAtEvenPar: true,
                        seriesColor: .chartCyan,
                        primaryStrokeStyle: .dashed,
                        showsAreaGradient: false
                    )
                    VsParProgressionChartLegend(items: [
                        .init(label: "Average", color: .chartCyan, strokeStyle: .dashed),
                    ])
                }
            } else {
                Text("Complete at least 2 full scorecards to see your average progression.")
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: GLTrendChartMetrics.chartHeight)
            }
        }
    }
}

struct ScoringTrendCard: View {
    let values: [Double]

    var body: some View {
        GLStatTrendCard(title: "Scoring trend") {
            if let series = VsParLineChartSeries(roundValues: values) {
                VsParLineChartView(
                    series: series,
                    totalXSlots: values.count,
                    xAxisLabel: "Round",
                    yAxisLabel: "Score",
                    gridStyle: .vsParStrokes,
                    anchorLineAtEvenPar: false,
                    showLastValueLabel: true,
                    lastValueFormatter: VsParLineChartView.formatVsPar
                )
            } else {
                ChartEmptyPlaceholder()
            }
        }
    }
}

struct StatsMetricTrendCard: View {
    let title: String
    let values: [Double]
    let yAxisLabel: String
    let gridStep: Double
    var seriesColor: Color = .accent
    let valueFormatter: (Double) -> String
    var yAxisLeadingMargin: CGFloat = GLTrendChartMetrics.defaultYAxisLeadingMargin

    var body: some View {
        GLStatTrendCard(title: title) {
            if let series = VsParLineChartSeries(roundValues: values) {
                VsParLineChartView(
                    series: series,
                    totalXSlots: values.count,
                    xAxisLabel: "Round",
                    yAxisLabel: yAxisLabel,
                    gridStyle: .step(gridStep),
                    anchorLineAtEvenPar: false,
                    yAxisLeadingMargin: yAxisLeadingMargin,
                    showLastValueLabel: true,
                    lastValueFormatter: valueFormatter,
                    seriesColor: seriesColor
                )
            } else {
                ChartEmptyPlaceholder()
            }
        }
    }
}

private struct ChartEmptyPlaceholder: View {
    var body: some View {
        Text("No data yet")
            .font(.glSubhead)
            .foregroundColor(.textTertiary)
            .frame(maxWidth: .infinity, minHeight: GLTrendChartMetrics.chartHeight)
    }
}
