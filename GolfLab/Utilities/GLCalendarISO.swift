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

    /// For UI copy (History / practice sheets).
    static func mmddyyyyDisplay(from ymdPrefix: String) -> String {
        let head = String(ymdPrefix.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return head }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        guard let date = cal.date(from: dc) else { return head }
        return mmddyyyy.string(from: date)
    }

    private static let mmddyyyy: DateFormatter = {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()
}
