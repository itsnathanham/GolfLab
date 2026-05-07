import SwiftUI

// MARK: - Presentation style

/// How the vs-par series is drawn: **semantic** vs par splits red/green; **accent sparkline** matches Home’s scoring trend chrome (`docs/design.md`).
enum GLTrendChartStyle: Equatable {
    case semanticVsPar
    case accentSparkline
}

/// Line + area for vs-par trends. Default **semantic** style uses red/green vs par; **accent sparkline** uses a single accent line, soft fill, grid, and endpoint emphasis.
struct VsParTrendChartView: View {
    /// Chronological vs-par values (strokes − par per round).
    let values: [Double]
    var height: CGFloat = 100
    /// Horizontal dashed guide (mean vs par).
    var averageVsPar: Double? = nil
    /// Baseline at par (dashed in sparkline style; solid hairline in semantic when enabled).
    var showZeroLine: Bool = true
    var style: GLTrendChartStyle = .semanticVsPar
    /// When `style == .accentSparkline`, draws the last value in mono beside the endpoint (Home scoring trend).
    var showEndpointLabel: Bool = false
    /// Optional load / filter-change intro (accent sparkline only). Presets live in ``GLChartIntroAnimation``.
    var introAnimation: GLChartIntroAnimation? = nil
    /// Combined with the series hash so the intro replays when filters change (e.g. Home time pill).
    var introReplayToken: AnyHashable? = nil
    /// Stroke, fill, and endpoint emphasis for ``GLTrendChartStyle/accentSparkline`` (default matches Home).
    var sparklineSeriesColor: Color = .accent
    /// Trailing endpoint label; default formats vs-par like Home.
    var sparklineValueFormatter: ((Double) -> String)? = nil

    var body: some View {
        switch style {
        case .semanticVsPar:
            semanticChartCanvas
        case .accentSparkline:
            accentSparklineBody
        }
    }

    // MARK: - Semantic (Stats / legacy)

    private var semanticChartCanvas: some View {
        Canvas { context, size in
            guard !values.isEmpty else { return }
            let w = size.width
            let h = size.height
            let ys = values
            let yMin = min(0, ys.min() ?? 0) - 1
            let yMax = max(0, ys.max() ?? 0) + 1

            func xPos(_ i: Int) -> CGFloat {
                guard ys.count > 1 else { return w / 2 }
                return CGFloat(i) / CGFloat(ys.count - 1) * w
            }

            func yPos(_ y: Double) -> CGFloat {
                let t = (y - yMin) / (yMax - yMin)
                return CGFloat(h) - CGFloat(t) * h
            }

            let zY = yPos(0)

            if showZeroLine {
                var zeroPath = Path()
                zeroPath.move(to: CGPoint(x: 0, y: zY))
                zeroPath.addLine(to: CGPoint(x: w, y: zY))
                context.stroke(zeroPath, with: .color(Color.black.opacity(0.07)), lineWidth: 1)
            }

            let red = Color.chartNegativeFill
            let green = Color.chartPositiveFill

            for i in 0..<(ys.count - 1) {
                let y0 = ys[i]
                let y1 = ys[i + 1]
                let x0 = xPos(i)
                let x1 = xPos(i + 1)
                let p0 = yPos(y0)
                let p1 = yPos(y1)

                if y0 >= 0, y1 >= 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: p0))
                    path.addLine(to: CGPoint(x: x1, y: p1))
                    path.addLine(to: CGPoint(x: x1, y: zY))
                    path.addLine(to: CGPoint(x: x0, y: zY))
                    path.closeSubpath()
                    context.fill(path, with: .color(red))
                } else if y0 <= 0, y1 <= 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: p0))
                    path.addLine(to: CGPoint(x: x1, y: p1))
                    path.addLine(to: CGPoint(x: x1, y: zY))
                    path.addLine(to: CGPoint(x: x0, y: zY))
                    path.closeSubpath()
                    context.fill(path, with: .color(green))
                } else if y0 > 0, y1 < 0 {
                    let denom = y0 - y1
                    guard abs(denom) > 1e-9 else { continue }
                    let t = y0 / denom
                    let xCross = x0 + CGFloat(t) * (x1 - x0)
                    var redPath = Path()
                    redPath.move(to: CGPoint(x: x0, y: p0))
                    redPath.addLine(to: CGPoint(x: xCross, y: zY))
                    redPath.addLine(to: CGPoint(x: x0, y: zY))
                    redPath.closeSubpath()
                    context.fill(redPath, with: .color(red))
                    var greenPath = Path()
                    greenPath.move(to: CGPoint(x: xCross, y: zY))
                    greenPath.addLine(to: CGPoint(x: x1, y: p1))
                    greenPath.addLine(to: CGPoint(x: x1, y: zY))
                    greenPath.closeSubpath()
                    context.fill(greenPath, with: .color(green))
                } else if y0 < 0, y1 > 0 {
                    let denom = y1 - y0
                    guard abs(denom) > 1e-9 else { continue }
                    let t = -y0 / denom
                    let xCross = x0 + CGFloat(t) * (x1 - x0)
                    var greenPath = Path()
                    greenPath.move(to: CGPoint(x: x0, y: p0))
                    greenPath.addLine(to: CGPoint(x: xCross, y: zY))
                    greenPath.addLine(to: CGPoint(x: x0, y: zY))
                    greenPath.closeSubpath()
                    context.fill(greenPath, with: .color(green))
                    var redPath = Path()
                    redPath.move(to: CGPoint(x: xCross, y: zY))
                    redPath.addLine(to: CGPoint(x: x1, y: p1))
                    redPath.addLine(to: CGPoint(x: x1, y: zY))
                    redPath.closeSubpath()
                    context.fill(redPath, with: .color(red))
                }
            }

            let lineStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            if ys.count == 1 {
                let y = ys[0]
                let dot = CGPoint(x: xPos(0), y: yPos(y))
                let dotColor: Color = y > 0 ? .chartNegative : (y < 0 ? .chartPositive : .textTertiary)
                context.fill(
                    Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)),
                    with: .color(dotColor)
                )
            } else {
                for i in 0..<(ys.count - 1) {
                    let y0 = ys[i]
                    let y1 = ys[i + 1]
                    let x0 = xPos(i)
                    let x1 = xPos(i + 1)
                    let p0 = yPos(y0)
                    let p1 = yPos(y1)

                    if y0 >= 0, y1 >= 0 {
                        var seg = Path()
                        seg.move(to: CGPoint(x: x0, y: p0))
                        seg.addLine(to: CGPoint(x: x1, y: p1))
                        context.stroke(seg, with: .color(.chartNegative), style: lineStyle)
                    } else if y0 <= 0, y1 <= 0 {
                        var seg = Path()
                        seg.move(to: CGPoint(x: x0, y: p0))
                        seg.addLine(to: CGPoint(x: x1, y: p1))
                        context.stroke(seg, with: .color(.chartPositive), style: lineStyle)
                    } else if y0 > 0, y1 < 0 {
                        let denom = y0 - y1
                        guard abs(denom) > 1e-9 else { continue }
                        let t = y0 / denom
                        let xCross = x0 + CGFloat(t) * (x1 - x0)
                        var segA = Path()
                        segA.move(to: CGPoint(x: x0, y: p0))
                        segA.addLine(to: CGPoint(x: xCross, y: zY))
                        context.stroke(segA, with: .color(.chartNegative), style: lineStyle)
                        var segB = Path()
                        segB.move(to: CGPoint(x: xCross, y: zY))
                        segB.addLine(to: CGPoint(x: x1, y: p1))
                        context.stroke(segB, with: .color(.chartPositive), style: lineStyle)
                    } else if y0 < 0, y1 > 0 {
                        let denom = y1 - y0
                        guard abs(denom) > 1e-9 else { continue }
                        let t = -y0 / denom
                        let xCross = x0 + CGFloat(t) * (x1 - x0)
                        var segA = Path()
                        segA.move(to: CGPoint(x: x0, y: p0))
                        segA.addLine(to: CGPoint(x: xCross, y: zY))
                        context.stroke(segA, with: .color(.chartPositive), style: lineStyle)
                        var segB = Path()
                        segB.move(to: CGPoint(x: xCross, y: zY))
                        segB.addLine(to: CGPoint(x: x1, y: p1))
                        context.stroke(segB, with: .color(.chartNegative), style: lineStyle)
                    }
                }

                if let last = ys.indices.last {
                    let yLast = ys[last]
                    let dot = CGPoint(x: xPos(last), y: yPos(yLast))
                    let dotColor: Color = yLast > 0 ? .chartNegative : (yLast < 0 ? .chartPositive : .textTertiary)
                    context.fill(
                        Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)),
                        with: .color(dotColor)
                    )
                }
            }

            if let avg = averageVsPar {
                let ay = yPos(avg)
                var avgPath = Path()
                avgPath.move(to: CGPoint(x: 0, y: ay))
                avgPath.addLine(to: CGPoint(x: w, y: ay))
                context.stroke(
                    avgPath,
                    with: .color(Color.black.opacity(0.07)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }
        }
        .frame(height: height)
    }

    // MARK: - Accent sparkline (Home)

    @ViewBuilder
    private var accentSparklineBody: some View {
        let plotLeading: CGFloat = 8
        let plotTrailing: CGFloat = showEndpointLabel ? 28 : 12
        if let intro = introAnimation {
            AccentSparklineIntroHost(
                values: values,
                height: height,
                showZeroLine: showZeroLine,
                averageVsPar: averageVsPar,
                showEndpointLabel: showEndpointLabel,
                plotLeading: plotLeading,
                plotTrailing: plotTrailing,
                introAnimation: intro,
                introReplayToken: introReplayToken,
                sparklineSeriesColor: sparklineSeriesColor,
                sparklineValueFormatter: sparklineValueFormatter
            )
        } else {
            AccentSparklineLayeredView(
                values: values,
                height: height,
                showZeroLine: showZeroLine,
                averageVsPar: averageVsPar,
                showEndpointLabel: showEndpointLabel,
                plotLeading: plotLeading,
                plotTrailing: plotTrailing,
                lineReveal: 1,
                glowEnvelope: 0,
                sparklineSeriesColor: sparklineSeriesColor,
                sparklineValueFormatter: sparklineValueFormatter
            )
        }
    }

    static func chartIntroTaskID(values: [Double], replayToken: AnyHashable?) -> String {
        var hasher = Hasher()
        hasher.combine(values.count)
        if let replayToken {
            hasher.combine(replayToken)
        }
        for v in values {
            hasher.combine(v)
        }
        return String(hasher.finalize())
    }

    /// Shared layout for accent sparkline (Canvas + optional label overlay). Horizontal insets keep the endpoint halo and label inside bounds.
    private static func sparklineLayout(
        values: [Double],
        size: CGSize,
        plotLeading: CGFloat,
        plotTrailing: CGFloat
    ) -> (w: CGFloat, h: CGFloat, yMin: Double, yMax: Double, xPos: (Int) -> CGFloat, yPos: (Double) -> CGFloat)? {
        guard !values.isEmpty else { return nil }
        let w = size.width
        let h = size.height
        let ys = values
        let yMin = min(0, ys.min() ?? 0) - 1
        let yMax = max(0, ys.max() ?? 0) + 1
        let plotWidth = max(1, w - plotLeading - plotTrailing)
        func xPos(_ i: Int) -> CGFloat {
            guard ys.count > 1 else { return plotLeading + plotWidth / 2 }
            return plotLeading + CGFloat(i) / CGFloat(ys.count - 1) * plotWidth
        }
        func yPos(_ y: Double) -> CGFloat {
            let t = (y - yMin) / (yMax - yMin)
            return CGFloat(h) - CGFloat(t) * h
        }
        return (w, h, yMin, yMax, xPos, yPos)
    }

    fileprivate static func sparklineLastPoint(
        values: [Double],
        size: CGSize,
        plotLeading: CGFloat,
        plotTrailing: CGFloat
    ) -> CGPoint {
        guard let layout = sparklineLayout(values: values, size: size, plotLeading: plotLeading, plotTrailing: plotTrailing),
              let lastIdx = values.indices.last
        else { return .zero }
        return CGPoint(x: layout.xPos(lastIdx), y: layout.yPos(values[lastIdx]))
    }

    fileprivate static func sparklineLastLabel(_ v: Double) -> String {
        if abs(v - v.rounded()) < 0.05 {
            return String(format: "%+.0f", v)
        }
        return String(format: "%+.1f", v)
    }

    fileprivate static func drawAccentSparklineBackground(
        context: GraphicsContext,
        size: CGSize,
        values: [Double],
        showZeroLine: Bool,
        averageVsPar: Double?,
        plotLeading: CGFloat,
        plotTrailing: CGFloat
    ) {
        guard let layout = sparklineLayout(values: values, size: size, plotLeading: plotLeading, plotTrailing: plotTrailing) else { return }
        let w = layout.w
        let h = layout.h
        let yPos = layout.yPos
        let zY = yPos(0)

        for frac in [0.1875, 0.5] as [CGFloat] {
            var g = Path()
            let yy = h * frac
            g.move(to: CGPoint(x: 0, y: yy))
            g.addLine(to: CGPoint(x: w, y: yy))
            context.stroke(g, with: .color(Color.black.opacity(0.04)), lineWidth: 1)
        }

        if showZeroLine {
            var zeroPath = Path()
            zeroPath.move(to: CGPoint(x: 0, y: zY))
            zeroPath.addLine(to: CGPoint(x: w, y: zY))
            context.stroke(
                zeroPath,
                with: .color(Color.black.opacity(0.07)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }

        if let avg = averageVsPar {
            let ay = yPos(avg)
            var avgPath = Path()
            avgPath.move(to: CGPoint(x: 0, y: ay))
            avgPath.addLine(to: CGPoint(x: w, y: ay))
            context.stroke(
                avgPath,
                with: .color(Color.black.opacity(0.07)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
    }

    fileprivate static func drawAccentSparklineForegroundAreaAndLine(
        context: GraphicsContext,
        size: CGSize,
        values: [Double],
        plotLeading: CGFloat,
        plotTrailing: CGFloat,
        seriesColor: Color
    ) {
        guard let layout = sparklineLayout(values: values, size: size, plotLeading: plotLeading, plotTrailing: plotTrailing) else { return }
        let w = layout.w
        let h = layout.h
        let ys = values
        let xPos = layout.xPos
        let yPos = layout.yPos

        if ys.count == 1 {
            let x0 = xPos(0)
            let y0 = yPos(ys[0])
            let stub = max(4, plotLeading * 0.5)
            var area = Path()
            area.move(to: CGPoint(x: x0, y: y0))
            area.addLine(to: CGPoint(x: min(x0 + stub, w - 1), y: y0))
            area.addLine(to: CGPoint(x: min(x0 + stub, w - 1), y: h))
            area.addLine(to: CGPoint(x: max(x0 - stub, 0), y: h))
            area.addLine(to: CGPoint(x: max(x0 - stub, 0), y: y0))
            area.closeSubpath()
            let fillTop = seriesColor.opacity(0.14)
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: fillTop, location: 0),
                        .init(color: fillTop.opacity(0), location: 1)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: 0),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        } else {
            var area = Path()
            area.move(to: CGPoint(x: xPos(0), y: yPos(ys[0])))
            for i in 1..<ys.count {
                area.addLine(to: CGPoint(x: xPos(i), y: yPos(ys[i])))
            }
            area.addLine(to: CGPoint(x: xPos(ys.count - 1), y: h))
            area.addLine(to: CGPoint(x: xPos(0), y: h))
            area.closeSubpath()
            let fillTop = seriesColor.opacity(0.14)
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: fillTop, location: 0),
                        .init(color: fillTop.opacity(0), location: 1)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: 0),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        let lineStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        if ys.count == 1 {
            let x0 = xPos(0)
            let y0 = yPos(ys[0])
            let stub = max(4, plotLeading * 0.5)
            var seg = Path()
            seg.move(to: CGPoint(x: max(x0 - stub, 0), y: y0))
            seg.addLine(to: CGPoint(x: min(x0 + stub, w - 1), y: y0))
            context.stroke(seg, with: .color(seriesColor), style: lineStyle)
        } else {
            var line = Path()
            line.move(to: CGPoint(x: xPos(0), y: yPos(ys[0])))
            for i in 1..<ys.count {
                line.addLine(to: CGPoint(x: xPos(i), y: yPos(ys[i])))
            }
            context.stroke(line, with: .color(seriesColor), style: lineStyle)
        }
    }

    fileprivate static func drawAccentSparklineEndpointOnly(
        context: GraphicsContext,
        size: CGSize,
        values: [Double],
        plotLeading: CGFloat,
        plotTrailing: CGFloat,
        glowEnvelope: CGFloat,
        seriesColor: Color
    ) {
        guard let layout = sparklineLayout(values: values, size: size, plotLeading: plotLeading, plotTrailing: plotTrailing) else { return }
        let ys = values
        let xPos = layout.xPos
        let yPos = layout.yPos
        if ys.count == 1 {
            let p = CGPoint(x: xPos(0), y: yPos(ys[0]))
            drawSparklineEndpoint(context: context, at: p, glowEnvelope: glowEnvelope, seriesColor: seriesColor)
        } else if let last = ys.indices.last {
            let p = CGPoint(x: xPos(last), y: yPos(ys[last]))
            drawSparklineEndpoint(context: context, at: p, glowEnvelope: glowEnvelope, seriesColor: seriesColor)
        }
    }

    fileprivate static func drawSparklineEndpoint(context: GraphicsContext, at p: CGPoint, glowEnvelope: CGFloat, seriesColor: Color) {
        let bell = sin(Double.pi * Double(glowEnvelope))
        for (radius, opacity) in [(CGFloat(10), 0.08), (6, 0.15), (3, 1.0)] as [(CGFloat, Double)] {
            let isCore = radius < 4
            let rScale: CGFloat = isCore ? 1 : (1 + CGFloat(bell) * 0.14)
            let effR = radius * rScale
            let opBoost = isCore ? 0 : bell * 0.55
            let op = min(1.0, opacity * (1 + opBoost))
            let rect = CGRect(x: p.x - effR, y: p.y - effR, width: effR * 2, height: effR * 2)
            context.fill(Path(ellipseIn: rect), with: .color(seriesColor.opacity(op)))
        }
    }
}

// MARK: - Accent sparkline layers (shared + intro)

private struct AccentSparklineLayeredView: View {
    let values: [Double]
    var height: CGFloat
    var showZeroLine: Bool
    var averageVsPar: Double?
    var showEndpointLabel: Bool
    let plotLeading: CGFloat
    let plotTrailing: CGFloat
    let lineReveal: CGFloat
    let glowEnvelope: CGFloat
    var sparklineSeriesColor: Color = .accent
    var sparklineValueFormatter: ((Double) -> String)? = nil

    private var labelOpacity: CGFloat {
        if lineReveal >= 0.995 { return 1 }
        let t = (lineReveal - 0.82) / 0.17
        return max(0, min(1, t))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maskW = max(1, w * lineReveal)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    VsParTrendChartView.drawAccentSparklineBackground(
                        context: context,
                        size: size,
                        values: values,
                        showZeroLine: showZeroLine,
                        averageVsPar: averageVsPar,
                        plotLeading: plotLeading,
                        plotTrailing: plotTrailing
                    )
                }
                Canvas { context, size in
                    VsParTrendChartView.drawAccentSparklineForegroundAreaAndLine(
                        context: context,
                        size: size,
                        values: values,
                        plotLeading: plotLeading,
                        plotTrailing: plotTrailing,
                        seriesColor: sparklineSeriesColor
                    )
                }
                .mask(
                    Rectangle()
                        .frame(width: maskW)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
                if lineReveal >= 0.998 {
                    Canvas { context, size in
                        VsParTrendChartView.drawAccentSparklineEndpointOnly(
                            context: context,
                            size: size,
                            values: values,
                            plotLeading: plotLeading,
                            plotTrailing: plotTrailing,
                            glowEnvelope: glowEnvelope,
                            seriesColor: sparklineSeriesColor
                        )
                    }
                }
                if showEndpointLabel, let last = values.last, !values.isEmpty {
                    let pt = VsParTrendChartView.sparklineLastPoint(
                        values: values,
                        size: geo.size,
                        plotLeading: plotLeading,
                        plotTrailing: plotTrailing
                    )
                    let labelY = max(10, pt.y - 12)
                    let labelText = sparklineValueFormatter?(last) ?? VsParTrendChartView.sparklineLastLabel(last)
                    Text(labelText)
                        .font(.glAxis)
                        .foregroundColor(sparklineSeriesColor)
                        .position(x: min(pt.x + 8, geo.size.width - 4), y: labelY)
                        .opacity(labelOpacity)
                }
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

/// Hosts the accent sparkline intro only after the view has **appeared** (so it never runs while a parent
/// loading branch keeps this view out of the hierarchy, and it does not race the first visible frame).
private struct AccentSparklineIntroHost: View {
    let values: [Double]
    var height: CGFloat
    var showZeroLine: Bool
    var averageVsPar: Double?
    var showEndpointLabel: Bool
    let plotLeading: CGFloat
    let plotTrailing: CGFloat
    let introAnimation: GLChartIntroAnimation
    var introReplayToken: AnyHashable?
    var sparklineSeriesColor: Color = .accent
    var sparklineValueFormatter: ((Double) -> String)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineReveal: CGFloat = 0
    @State private var glowEnvelope: CGFloat = 0
    /// Set in `onAppear` so `.task` does not animate until the user can see this chart (post–loading UI, on-screen).
    @State private var sparklineHostDidAppear = false

    private var introTaskIdentity: String {
        "\(sparklineHostDidAppear ? 1 : 0)-\(VsParTrendChartView.chartIntroTaskID(values: values, replayToken: introReplayToken))"
    }

    var body: some View {
        AccentSparklineLayeredView(
            values: values,
            height: height,
            showZeroLine: showZeroLine,
            averageVsPar: averageVsPar,
            showEndpointLabel: showEndpointLabel,
            plotLeading: plotLeading,
            plotTrailing: plotTrailing,
            lineReveal: reduceMotion ? 1 : lineReveal,
            glowEnvelope: reduceMotion ? 0 : glowEnvelope,
            sparklineSeriesColor: sparklineSeriesColor,
            sparklineValueFormatter: sparklineValueFormatter
        )
        .onAppear {
            sparklineHostDidAppear = true
        }
        .onDisappear {
            sparklineHostDidAppear = false
            lineReveal = 0
            glowEnvelope = 0
        }
        .task(id: introTaskIdentity) {
            guard sparklineHostDidAppear else { return }
            if reduceMotion {
                lineReveal = 1
                glowEnvelope = 0
                return
            }
            lineReveal = 0
            glowEnvelope = 0
            // One main-queue pass after appear so layout/paint completes, then the reveal reads as intentional polish.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
            guard !Task.isCancelled, sparklineHostDidAppear else { return }
            let a = introAnimation
            if a.pauseBeforeLine > 0 {
                try? await Task.sleep(for: .seconds(a.pauseBeforeLine))
                guard !Task.isCancelled, sparklineHostDidAppear else { return }
            }
            withAnimation(.timingCurve(0.22, 0.04, 0.2, 1, duration: a.lineDuration)) {
                lineReveal = 1
            }
            try? await Task.sleep(for: .seconds(a.lineDuration))
            guard !Task.isCancelled, sparklineHostDidAppear else { return }
            withAnimation(.easeOut(duration: a.glowDuration)) {
                glowEnvelope = 1
            }
        }
    }
}

// MARK: - Stats tab card (header + vs-par chart + mean)

struct VsParScoreStatsCard: View {
    let title: String
    let subtitle: String
    let dataPoints: [ChartPoint]

    private var sortedValues: [Double] {
        dataPoints.sorted { $0.index < $1.index }.map(\.value)
    }

    private var averageVsPar: Double? {
        guard !dataPoints.isEmpty else { return nil }
        return dataPoints.map(\.value).reduce(0, +) / Double(dataPoints.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.glCaption)
                    .foregroundColor(.textTertiary)
                    .tracking(0.10 * 11)
                Spacer()
                if let last = sortedValues.last {
                    Text(formatVsParHeader(last))
                        .font(GLFonts.mono(size: 12, weight: .semibold))
                        .foregroundColor(last <= 0 ? Color.accent : Color.chartNegative)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 11)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
            }

            if !subtitle.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle)
                        .font(.glCaption)
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text("\(dataPoints.count) rounds")
                        .font(.glMicro)
                        .foregroundColor(.textTertiary)
                }
            }

            VsParTrendChartView(values: sortedValues, height: 140, averageVsPar: averageVsPar, showZeroLine: true)

            if let avg = averageVsPar {
                HStack {
                    Spacer()
                    Text(String(format: "Avg %+.1f", avg))
                        .font(.glMicro)
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(GLCardMetrics.padding)
        .background(Color.cardBackground)
        .cornerRadius(GLCardMetrics.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .padding(.horizontal, GLLayout.horizontalInset)
    }

    private func formatVsParHeader(_ v: Double) -> String {
        if abs(v.rounded() - v) < 0.01 {
            return String(format: "%+.0f", v)
        }
        return String(format: "%+.1f", v)
    }
}
