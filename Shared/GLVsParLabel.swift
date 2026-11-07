import Foundation

enum GLVsParLabel {
    /// Even par is "E". Negative scores use a minus sign, matching `GLMetricFormat.vsParRound`.
    static func text(_ score: Int) -> String {
        if score == 0 { return "E" }
        if score > 0 { return "+\(score)" }
        return "\u{2212}\(abs(score))"
    }
}
