import Foundation

/// Tunable chart intro motion for load / data-change. Add presets per surface so we can roll out app-wide from one place.
struct GLChartIntroAnimation: Equatable, Sendable {
    /// Stroke reveal along the series (ease baked into `Animation` at call site).
    var lineDuration: TimeInterval
    /// One-shot endpoint emphasis after the line finishes (maps through a bell curve so start/end match the static look).
    var glowDuration: TimeInterval
    /// Brief idle beat after layout so the reveal does not snap on right after loading spinners.
    var pauseBeforeLine: TimeInterval

    /// Home scoring trend accent sparkline.
    static let accentSparklineHome = GLChartIntroAnimation(lineDuration: 0.92, glowDuration: 0.36, pauseBeforeLine: 0.16)

    /// Stats tab trend panels (slightly snappier than Home).
    static let accentSparklineStats = GLChartIntroAnimation(lineDuration: 0.8, glowDuration: 0.32, pauseBeforeLine: 0.14)
}
