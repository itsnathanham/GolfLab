import SwiftUI

struct HistoryCalendarMonthCard: View {
    @Binding var monthStart: Date
    /// Local calendar yyyy-MM-dd with a saved, complete scorecard.
    let roundDotYMD: Set<String>
    let practiceDotYMD: Set<String>
    let selectedYMD: String?
    let onTapYMD: (String) -> Void

    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            monthHeaderRow
            weekdayHeaderRow

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(Array(paddedCells.enumerated()), id: \.offset) { _, cell in
                    dayCell(day: cell)
                }
            }

            legendRow
        }
        .padding(GLCardMetrics.padding)
        .glCardSurface(outlined: true)
    }

    private var monthHeaderRow: some View {
        HStack {
            Button {
                monthStart = GLCalendarISO.addingMonths(-1, to: monthStart)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
            Text(monthTitle)
                .font(.glEyebrow)
                .foregroundStyle(Color.textSecondary)
            Spacer()

            Button {
                monthStart = GLCalendarISO.addingMonths(1, to: monthStart)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var monthTitle: String {
        MonthTitleFormatter.string(from: monthStart)
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayLetters, id: \.self) { letter in
                Text(letter)
                    .font(GLFonts.mono(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdayLetters: [String] {
        let syms = cal.shortStandaloneWeekdaySymbols
        let first = max(1, cal.firstWeekday)
        guard !syms.isEmpty else { return [] }
        let idx = first - 1
        let tail = syms.indices.contains(idx) ? Array(syms[idx...]) : syms
        let head = syms.indices.contains(idx) ? Array(syms[..<idx]) : []
        return (tail + head).map {
            guard let ch = $0.first else { return $0 }
            return String(ch).uppercased()
        }
    }

    private var paddedCells: [Date?] {
        guard let domRange = cal.range(of: .day, in: .month, for: monthStart) else {
            return Array(repeating: nil as Date?, count: 42)
        }
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let pad = ((firstWeekday - cal.firstWeekday) + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: pad)
        for day in domRange {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            cells.append(date)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        while cells.count < 42 { cells.append(nil) }
        return cells
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
        .frame(height: 7)
        .opacity((roundDotYMD.contains(ymd) || practiceDotYMD.contains(ymd)) ? 1 : 0)
    }

    private func dayCell(day: Date?) -> some View {
        Group {
            if let day {
                let ymd = GLCalendarISO.ymd(for: day)
                let sel = selectedYMD == ymd
                let today = cal.isDateInToday(day)

                Button {
                    onTapYMD(ymd)
                } label: {
                    VStack(spacing: 5) {
                        Text(dayNumber(day))
                            .font(GLFonts.mono(size: 14, weight: .medium))
                            .foregroundStyle(sel ? Color.ctaOnAccent : Color.textPrimary)

                        dotsStack(ymd: ymd)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(sel ? Color.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(today ? Color.borderAccent.opacity(0.85) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(maxWidth: .infinity).frame(height: 44)
            }
        }
    }

    private func dayNumber(_ day: Date) -> String {
        String(cal.component(.day, from: day))
    }
}

private enum MonthTitleFormatter {
    private static let f: DateFormatter = {
        let x = DateFormatter()
        x.calendar = Calendar.current
        x.locale = Locale(identifier: "en_US_POSIX")
        x.timeZone = TimeZone.current
        x.dateFormat = "MMMM yyyy"
        return x
    }()

    static func string(from date: Date) -> String {
        f.string(from: date)
    }
}
