import SwiftUI

struct HistoryCalendarMonthCard: View {
    @Binding var monthStart: Date
    /// Local calendar yyyy-MM-dd with a saved, complete scorecard.
    let roundDotYMD: Set<String>
    /// yyyy-MM-dd with a logged practice session (dots only; not a list below).
    let practiceDotYMD: Set<String>
    let selectedYMD: String?
    let onTapYMD: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GLCalendarMetrics.sectionSpacing) {
            GLCalendarMonthNavigationHeader(monthStart: $monthStart)

            GLCalendarWeekdayHeaderRow()

            GLCalendarMonthGridShell(paddedCells: GLCalendarISO.paddedMonthCells(for: monthStart)) { day in
                let ymd = GLCalendarISO.ymd(for: day)
                GLCalendarDayCell(
                    day: day,
                    isSelected: selectedYMD == ymd,
                    isEnabled: true,
                    onTap: { onTapYMD(ymd) },
                    accessory: {
                        dotsStack(ymd: ymd)
                    }
                )
            }

            legendRow
        }
        .padding(GLCardMetrics.padding)
        .glCardSurface(outlined: true)
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendItem(color: Color.calendarRoundDot, label: "Round")
            legendItem(color: Color.calendarPracticeDot, label: "Practice")
            Spacer()
        }
        .padding(.top, 2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.glFootnote)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private func dotsStack(ymd: String) -> some View {
        HStack(spacing: 6) {
            if roundDotYMD.contains(ymd) {
                Circle()
                    .fill(Color.calendarRoundDot)
                    .frame(width: 5, height: 5)
            }
            if practiceDotYMD.contains(ymd) {
                Circle()
                    .fill(Color.calendarPracticeDot)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: GLCalendarMetrics.accessoryStackHeight)
        .opacity((roundDotYMD.contains(ymd) || practiceDotYMD.contains(ymd)) ? 1 : 0)
    }
}
