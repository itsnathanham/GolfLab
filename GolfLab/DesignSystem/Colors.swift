import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design brief (docs/design.md)

extension Color {
    /// Page / screen background — light green tint, not pure white.
    static let bgPrimary = Color(hex: "#F4F6F4")
    /// Card / panel / off-state toggle surface.
    static let bgCard = Color(hex: "#FFFFFF")
    /// Stepper −/+, elevated inactive surfaces.
    static let bgElevated = Color(hex: "#EAEEEA")

    static var borderDefault: Color { Color.black.opacity(0.07) }
    static var borderAccent: Color { Color(hex: "#19693A").opacity(0.25) }
    static var borderPenalty: Color { Color(hex: "#C0412D").opacity(0.28) }

    static let textPrimary = Color(hex: "#111A13")
    static let textSecondary = Color(hex: "#4A6655")
    static let textTertiary = Color(hex: "#8FA898")

    /// Deep forest — CTAs, active states, improving trends (use sparingly).
    static let accent = Color(hex: "#19693A")
    /// Slightly lighter green — positive deltas.
    static let accentMid = Color(hex: "#22874E")
    static var accentDim: Color { accent.opacity(0.08) }
    static var accentDimmer: Color { accent.opacity(0.04) }
    /// Text on primary accent button.
    static let ctaOnAccent = Color(hex: "#F2F8F4")

    // MARK: - App-wide aliases (existing call sites)

    static var appBackground: Color { bgPrimary }
    static var cardBackground: Color { bgCard }
    /// Primary CTA tint, selected filters, key emphasis.
    static var brandAccent: Color { accent }
    /// 1px hairlines on cards and panels.
    static var divider: Color { borderDefault }

    // MARK: - Charts (vs par: below par = “good” = accent)

    static var chartPositive: Color { accent }
    /// Negative / above-par trend — bogey orange from the brief.
    static let chartNegative = Color(hex: "#C05020")
    /// Double-bogey+ emphasis — penalty red.
    static let chartNegativeStrong = Color(hex: "#C0412D")
    /// Steady / neutral series line.
    static var chartNeutral: Color { textSecondary }

    static var chartPositiveFill: Color { chartPositive.opacity(0.14) }
    static var chartNegativeFill: Color { chartNegative.opacity(0.14) }

    // MARK: - Scorecard (paper-style rings / boxes; same semantics as chart vs par)

    /// Birdie ring, inner eagle ring — `accentMid` (“positive deltas” / lighter green).
    static var scorecardUnderParMuted: Color { accentMid }
    /// Eagle outer ring — deep forest `accent`.
    static var scorecardUnderParStrong: Color { accent }
    /// Bogey box, inner double-bogey+ box — bogey orange (`chartNegative`).
    static var scorecardOverPar: Color { chartNegative }
    /// Double-bogey+ outer box — penalty red (`chartNegativeStrong`).
    static var scorecardOverParStrong: Color { chartNegativeStrong }

    // MARK: - History calendar (completed rounds vs logged practice)

#if canImport(UIKit)
    static var calendarRoundDot: Color { Color(uiColor: .systemGreen) }
#else
    static var calendarRoundDot: Color { Color.green }
#endif
    static let calendarPracticeDot = Color(hex: "#4268AE")
    static var calendarPracticeDim: Color { calendarPracticeDot.opacity(0.10) }
    static var calendarPracticeBorder: Color { calendarPracticeDot.opacity(0.30) }

    // MARK: - Legacy palette (kept for gradual migration; prefer tokens above)

    static let green900 = Color(hex: "#19693A")
    static let green800 = Color(hex: "#143D26")
    static let green700 = Color(hex: "#19693A")
    static let green500 = Color(hex: "#22874E")
    static let green400 = Color(hex: "#2EAD65")
    static let green300 = Color(hex: "#4DC97E")
    static let green200 = Color(hex: "#8EDCAA")
    static let green50 = Color(hex: "#EBF7F0")
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

