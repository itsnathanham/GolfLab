import SwiftUI

/// Single pill for season year / Last 10 / All time (Stats + History). The label shows the chosen year or range.
struct TimeRangeFilterPicker: View {
    @Binding var timeRange: TimeRange
    @Binding var selectedSeasonYear: Int
    let availableSeasonYears: [Int]
    let resolvedSeasonYear: Int

    var body: some View {
        GLFilterMenuPill(title: pillTitle) {
            ForEach(availableSeasonYears, id: \.self) { year in
                Button {
                    selectedSeasonYear = year
                    timeRange = .season
                } label: {
                    GLFilterMenuRow(
                        title: String(year),
                        isSelected: timeRange == .season && year == resolvedSeasonYear
                    )
                }
            }

            ForEach([TimeRange.last10, TimeRange.allTime], id: \.self) { range in
                Button {
                    timeRange = range
                } label: {
                    GLFilterMenuRow(title: range.pillTitle, isSelected: timeRange == range)
                }
            }
        }
    }

    private var pillTitle: String {
        switch timeRange {
        case .season:
            return String(resolvedSeasonYear)
        case .last10, .allTime:
            return timeRange.pillTitle
        }
    }
}
