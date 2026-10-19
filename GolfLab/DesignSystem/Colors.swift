import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Robinhood Dark Theme (dark-only, data-dense)
// Updated: 2026-10-16 — Pure black backgrounds, bold green accents, stock-inspired aesthetic

extension Color {
    // MARK: - Backgrounds (dark-only)
    
    /// Page / screen background — pure black for OLED contrast and outdoor readability.
    static let bgPrimary = Color(hex: "#000000")
    
    /// Card / panel / off-state toggle surface.
    static let bgCard = Color(hex: "#1C1C1E")
    
    /// Stepper −/+, elevated inactive surfaces.
    static let bgElevated = Color(hex: "#2C2C2E")
    
    // MARK: - Borders
    
    static var borderDefault: Color { Color.white.opacity(0.08) }
    static var borderAccent: Color { Color(hex: "#00C805").opacity(0.25) }
    static var borderPenalty: Color { Color(hex: "#FF453A").opacity(0.28) }
    
    // MARK: - Text
    
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#8E8E93")
    static let textTertiary = Color(hex: "#636366")
    
    // MARK: - Accent
    
    /// Bold green — CTAs, active states, under-par scores.
    static let accent = Color(hex: "#00C805")
    
    /// Lighter green — positive trends, birdie rings.
    static let accentMid = Color(hex: "#5AC53B")
    
    static var accentDim: Color { Color(hex: "#00C805").opacity(0.12) }
    static var accentDimmer: Color { Color(hex: "#00C805").opacity(0.06) }
    
    /// Text on primary accent button — pure black for max contrast.
    static let ctaOnAccent = Color(hex: "#000000")
    
    // MARK: - App-wide aliases
    
    static var appBackground: Color { bgPrimary }
    static var cardBackground: Color { bgCard }
    static var brandAccent: Color { accent }
    static var divider: Color { borderDefault }
    
    // MARK: - Charts (vs par: below par = "good" = accent)
    
    static var chartPositive: Color { accent }
    /// Negative / above-par trend — Apple system red.
    static let chartNegative = Color(hex: "#FF453A")
    /// Double-bogey+ emphasis — stronger red.
    static let chartNegativeStrong = Color(hex: "#FF375F")
    /// Steady / neutral series line.
    static var chartNeutral: Color { textSecondary }
    static var chartSeasonAverage: Color { accentMid.opacity(0.55) }
    
    /// Gradient fills for line charts (stock-app style).
    static var chartPositiveFill: Color { chartPositive.opacity(0.20) }
    static var chartNegativeFill: Color { chartNegative.opacity(0.20) }
    
    // MARK: - Extended chart palette (multi-series, data emphasis)
    
    /// Cyan — distance, pace, yardage trends.
    static let chartCyan = Color(hex: "#30D5C8")
    static var chartCyanFill: Color { chartCyan.opacity(0.20) }
    
    /// Magenta — penalty emphasis, focus metrics, hazard stats.
    static let chartMagenta = Color(hex: "#FF2D55")
    static var chartMagentaFill: Color { chartMagenta.opacity(0.20) }
    
    /// Yellow — par baseline, neutral trends, milestones.
    static let chartYellow = Color(hex: "#FFD60A")
    static var chartYellowFill: Color { chartYellow.opacity(0.20) }
    
    /// Purple — practice data, putting stats, short game.
    static let chartPurple = Color(hex: "#BF5AF2")
    static var chartPurpleFill: Color { chartPurple.opacity(0.20) }
    
    /// Orange — peak performance, best rounds, fairway hits.
    static let chartOrange = Color(hex: "#FF9F0A")
    static var chartOrangeFill: Color { chartOrange.opacity(0.20) }
    
    // MARK: - Scorecard (rings / boxes; same semantics as chart vs par)
    
    /// Birdie ring, inner eagle ring — lighter green.
    static var scorecardUnderParMuted: Color { accentMid }
    /// Eagle outer ring — bold green accent.
    static var scorecardUnderParStrong: Color { accent }
    /// Bogey box, inner double-bogey+ box.
    static var scorecardOverPar: Color { chartNegative }
    /// Double-bogey+ outer box — stronger red.
    static var scorecardOverParStrong: Color { chartNegativeStrong }
    
    // MARK: - History calendar (completed rounds vs logged practice)
    
    /// Round completion dots — bold green.
    static var calendarRoundDot: Color { accent }
    /// Practice session dots — muted gray (subdued vs rounds).
    static let calendarPracticeDot = Color(hex: "#636366")
    static var calendarPracticeDim: Color { calendarPracticeDot.opacity(0.10) }
    static var calendarPracticeBorder: Color { calendarPracticeDot.opacity(0.30) }
    
    // MARK: - Weekly goals / streak (consistent with main accent)
    
    /// Met week circle + flame — green theme consistent with brand.
    static var streakSuccess: Color { accent }
    /// Confetti particles + deep accents.
    static var streakSuccessDeep: Color { accentMid }
    /// Checkmark on met week circles.
    static let streakOnSuccess = Color(hex: "#000000")
    /// Active streak footer caption.
    static var streakTextActive: Color { accent }
    /// Season-best badge fill.
    static var streakSuccessDim: Color { accent.opacity(0.12) }
    static var borderStreak: Color { accent.opacity(0.28) }
    
    // MARK: - Legacy palette (deprecated, use semantic tokens above)
    
    static let green900 = Color(hex: "#00C805")
    static let green800 = Color(hex: "#00A004")
    static let green700 = Color(hex: "#00C805")
    static let green500 = Color(hex: "#5AC53B")
    static let green400 = Color(hex: "#4DC97E")
    static let green300 = Color(hex: "#8EDCAA")
    static let green200 = Color(hex: "#A8E2C3")
    static let green50 = Color(hex: "#E0F7EA")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
