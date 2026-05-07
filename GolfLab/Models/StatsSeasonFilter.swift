import Foundation

/// Shared season-year resolution for Stats (season pill) and Hole Entry par averages.
enum StatsSeasonFilter {
    static func calendarYear(fromRoundDatePlayed datePlayed: String) -> Int? {
        guard datePlayed.count >= 4 else { return nil }
        return Int(String(datePlayed.prefix(4)))
    }

    static func calendarYear(from round: Round) -> Int? {
        calendarYear(fromRoundDatePlayed: round.datePlayed)
    }

    static func availableSeasonYears(from rounds: [Round], today: Date = .init()) -> [Int] {
        let years = Set(rounds.compactMap { calendarYear(from: $0) })
        let fallback = Calendar.current.component(.year, from: today)
        return (years.isEmpty ? [fallback] : Array(years)).sorted(by: >)
    }

    /// Same rules as `StatsView.resolvedSeasonYear` for a given `selectedSeasonYear` (Stats uses current calendar year on first launch).
    static func resolvedSeasonYear(
        rounds: [Round],
        selectedSeasonYear: Int,
        today: Date = .init()
    ) -> Int {
        let available = availableSeasonYears(from: rounds, today: today)
        if available.contains(selectedSeasonYear) {
            return selectedSeasonYear
        }
        let current = Calendar.current.component(.year, from: today)
        if available.contains(current) {
            return current
        }
        return available.first ?? current
    }

    /// Season year when Stats opens with its default selection (selected year = device calendar year).
    static func resolvedDefaultSeasonYear(rounds: [Round], today: Date = .init()) -> Int {
        let initial = Calendar.current.component(.year, from: today)
        return resolvedSeasonYear(rounds: rounds, selectedSeasonYear: initial, today: today)
    }

    private static let seasonPickerYearDefaultsKey = "GolfLabStatsSelectedSeasonYear"

    /// Persist the Stats season menu year so Hole Entry (and anything else off-Stats) uses the same resolved season as the picker.
    static func persistStatsSeasonPickerYear(_ year: Int) {
        UserDefaults.standard.set(year, forKey: seasonPickerYearDefaultsKey)
    }

    /// Same resolved season year as Stats after the user has used the season picker (falls back to device calendar year before first persist).
    static func seasonYearAlignedWithStatsPicker(rounds: [Round], today: Date = .init()) -> Int {
        let fallbackSelected = Calendar.current.component(.year, from: today)
        let selected = (UserDefaults.standard.object(forKey: seasonPickerYearDefaultsKey) as? Int) ?? fallbackSelected
        return resolvedSeasonYear(rounds: rounds, selectedSeasonYear: selected, today: today)
    }
}
