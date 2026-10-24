import SwiftUI

/// watchOS color palette — Robinhood dark theme, matches iOS tokens.
enum WatchPalette {
    static let accent = Color(red: 0 / 255, green: 200 / 255, blue: 5 / 255)
    static let bg = Color(red: 0 / 255, green: 0 / 255, blue: 0 / 255)
    static let elevated = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let textPrimary = Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255)
    static let textSecondary = Color(red: 174 / 255, green: 174 / 255, blue: 178 / 255)
    static let textTertiary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let chartPositive = accent
    static let chartNegative = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    /// Double-bogey+ / strong negative emphasis.
    static let chartNegativeStrong = Color(red: 255 / 255, green: 55 / 255, blue: 95 / 255)
    /// Practice dot — muted gray.
    static let practice = Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
    
    // Extended chart palette (multi-series, data emphasis)
    static let chartCyan = Color(red: 48 / 255, green: 213 / 255, blue: 200 / 255)
    static let chartMagenta = Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255)
    static let chartYellow = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)
    static let chartPurple = Color(red: 191 / 255, green: 90 / 255, blue: 242 / 255)
    static let chartOrange = Color(red: 255 / 255, green: 159 / 255, blue: 10 / 255)
}
