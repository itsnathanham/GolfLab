import Foundation

/// Local-calendar **yyyy-MM-dd** strings aligned with Postgres `date` and stored round `date_played`.
enum GLCalendarISO {
    private static let cal = Calendar.current

    static func ymd(for date: Date) -> String {
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func startOfMonth(containing date: Date) -> Date {
        let c = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: c)!
    }

    /// Inclusive `yyyy-MM-dd` bounds for `monthStart` (must be start-of-month anchor).
    static func inclusiveMonthBoundsYMD(monthStart: Date) -> (start: String, end: String) {
        let start = ymd(for: monthStart)
        guard let range = cal.range(of: .day, in: .month, for: monthStart),
              let lastDay = cal.date(byAdding: .day, value: range.count - 1, to: monthStart)
        else { return (start, start) }
        return (start, ymd(for: lastDay))
    }

    static func addingMonths(_ delta: Int, to monthStart: Date) -> Date {
        cal.date(byAdding: .month, value: delta, to: monthStart) ?? monthStart
    }

    // MARK: - Month grid (shared History + date picker UIs)

    /// First day of the grid (may be in the previous month) through 42 cells, padded with `nil`.
    static func paddedMonthCells(for monthStart: Date) -> [Date?] {
        guard let domRange = cal.range(of: .day, in: .month, for: monthStart) else {
            return Array(repeating: nil, count: 42)
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

    /// Single-letter weekday labels respecting `Calendar.current.firstWeekday`.
    static func weekdayColumnLetters() -> [String] {
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

    /// `MMMM yyyy` in the current locale, for month navigation headers.
    static func monthTitleMMMMYYYY(from monthStart: Date) -> String {
        monthTitleFormatter.string(from: monthStart)
    }

    private static let monthTitleFormatter = posixFormatter("MMMM yyyy")

    /// For UI copy (History / practice sheets).
    static func mmddyyyyDisplay(from ymdPrefix: String) -> String {
        guard let date = date(fromYMD: ymdPrefix) else { return String(ymdPrefix.prefix(10)) }
        return mmddyyyy.string(from: date)
    }

    /// Day summary title, e.g. `Nov 7 '26`.
    static func daySheetTitle(from ymdPrefix: String) -> String {
        guard let date = date(fromYMD: ymdPrefix) else { return String(ymdPrefix.prefix(10)) }
        return daySheetTitleFormatter.string(from: date)
    }

    /// Full weekday name for a `yyyy-MM-dd` key, e.g. `Saturday`.
    static func weekdayName(from ymdPrefix: String) -> String {
        guard let date = date(fromYMD: ymdPrefix) else { return "" }
        return weekdayNameFormatter.string(from: date)
    }

    static func date(fromYMD ymdPrefix: String) -> Date? {
        let head = String(ymdPrefix.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return cal.date(from: dc)
    }

    private static let mmddyyyy = posixFormatter("MM/dd/yyyy")
    private static let daySheetTitleFormatter = posixFormatter("MMM d ''yy")
    private static let weekdayNameFormatter = posixFormatter("EEEE")

    private static func posixFormatter(_ dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = dateFormat
        return formatter
    }
}
