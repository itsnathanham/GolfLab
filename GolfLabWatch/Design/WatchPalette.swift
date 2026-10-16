import SwiftUI

/// watchOS color palette — Robinhood dark theme, matches iOS tokens.
enum WatchPalette {
    static let accent = Color(red: 0 / 255, green: 200 / 255, blue: 5 / 255)
    static let bg = Color(red: 0 / 255, green: 0 / 255, blue: 0 / 255)
    static let elevated = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let textPrimary = Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255)
    static let textSecondary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let textTertiary = Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
    static let chartPositive = accent
    static let chartNegative = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    /// Double-bogey+ / strong negative emphasis.
    static let chartNegativeStrong = Color(red: 255 / 255, green: 55 / 255, blue: 95 / 255)
    /// Practice dot — muted gray.
    static let practice = Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
}
