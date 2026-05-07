import SwiftUI

/// watchOS cannot bundle iOS `Color` extensions; keep brief-aligned literals here.
enum WatchPalette {
    static let accent = Color(red: 25 / 255, green: 105 / 255, blue: 58 / 255)
    static let bg = Color(red: 244 / 255, green: 246 / 255, blue: 244 / 255)
    static let elevated = Color(red: 234 / 255, green: 238 / 255, blue: 234 / 255)
    static let textPrimary = Color(red: 17 / 255, green: 26 / 255, blue: 19 / 255)
    static let textSecondary = Color(red: 74 / 255, green: 102 / 255, blue: 85 / 255)
    static let textTertiary = Color(red: 143 / 255, green: 168 / 255, blue: 152 / 255)
    static let chartPositive = accent
    static let chartNegative = Color(red: 192 / 255, green: 80 / 255, blue: 32 / 255)
    /// Double-bogey+ / strong negative emphasis (`#C0412D` — matches iOS `chartNegativeStrong`).
    static let chartNegativeStrong = Color(red: 192 / 255, green: 65 / 255, blue: 45 / 255)
}
