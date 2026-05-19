import SwiftUI

// MARK: - Tokens (single place to tune calendar chrome)

enum GLCalendarMetrics {
    /// Space between month header, weekday row, and grid (`History` baseline).
    static let sectionSpacing: CGFloat = 14
    /// `LazyVGrid` row spacing between week rows.
    static let gridRowSpacing: CGFloat = 8
    /// Bottom padding for round/practice dot stack; keep picker cells aligned to same vertical rhythm.
    static let accessoryStackHeight: CGFloat = 7
    /// Day number + accessory + vertical padding.
    static let dayCellMinHeight: CGFloat = 44
    /// Selected day background; matches card radius (`docs/design.md`).
    static let daySelectionCornerRadius: CGFloat = GLCardMetrics.cornerRadius
    /// Month chevron tap targets.
    static let navButtonSize: CGFloat = 36
    static let navChevronPointSize: CGFloat = 15
}

// MARK: - Month navigation

struct GLCalendarMonthNavigationHeader: View {
    @Binding var monthStart: Date

    var body: some View {
        GLCalendarMonthNavigationHeaderBounded(
            monthStart: $monthStart,
            canGoPrevious: true,
            canGoNext: true
        )
    }
}

/// Same header with disabled chevrons (e.g. date picker with min/max month bounds).
struct GLCalendarMonthNavigationHeaderBounded: View {
    @Binding var monthStart: Date
    var canGoPrevious: Bool
    var canGoNext: Bool

    var body: some View {
        HStack {
            Button {
                monthStart = GLCalendarISO.addingMonths(-1, to: monthStart)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: GLCalendarMetrics.navChevronPointSize, weight: .semibold))
                    .foregroundStyle(canGoPrevious ? Color.accent : Color.textTertiary.opacity(0.4))
                    .frame(width: GLCalendarMetrics.navButtonSize, height: GLCalendarMetrics.navButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoPrevious)

            Spacer()
            Text(GLCalendarISO.monthTitleMMMMYYYY(from: monthStart))
                .font(.glEyebrow)
                .foregroundStyle(Color.textSecondary)
            Spacer()

            Button {
                monthStart = GLCalendarISO.addingMonths(1, to: monthStart)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: GLCalendarMetrics.navChevronPointSize, weight: .semibold))
                    .foregroundStyle(canGoNext ? Color.accent : Color.textTertiary.opacity(0.4))
                    .frame(width: GLCalendarMetrics.navButtonSize, height: GLCalendarMetrics.navButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
        }
    }
}

// MARK: - Weekday row

struct GLCalendarWeekdayHeaderRow: View {
    private let letters = GLCalendarISO.weekdayColumnLetters()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(GLFonts.mono(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Day cell

struct GLCalendarDayCell<Accessory: View>: View {
    private let cal = Calendar.current

    let day: Date
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        let today = cal.isDateInToday(day)
        Button {
            guard isEnabled else { return }
            onTap()
        } label: {
            VStack(spacing: 5) {
                Text(dayNumber)
                    .font(GLFonts.mono(size: 14, weight: .medium))
                    .foregroundStyle(foregroundColor(isSelected: isSelected, isEnabled: isEnabled))

                accessory()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(backgroundColor(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: GLCalendarMetrics.daySelectionCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GLCalendarMetrics.daySelectionCornerRadius)
                    .stroke(today ? Color.borderAccent.opacity(0.85) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var dayNumber: String {
        String(cal.component(.day, from: day))
    }

    private func foregroundColor(isSelected: Bool, isEnabled: Bool) -> Color {
        if !isEnabled { return Color.textTertiary.opacity(0.45) }
        return isSelected ? Color.ctaOnAccent : Color.textPrimary
    }

    private func backgroundColor(isSelected: Bool) -> Color {
        guard isSelected else { return Color.clear }
        return Color.accent
    }
}

// MARK: - Month grid shell (shared layout)

struct GLCalendarMonthGridShell<DayContent: View>: View {
    let paddedCells: [Date?]
    @ViewBuilder let dayContent: (Date) -> DayContent

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: GLCalendarMetrics.gridRowSpacing
        ) {
            ForEach(Array(paddedCells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayContent(day)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: GLCalendarMetrics.dayCellMinHeight)
                }
            }
        }
    }
}

// MARK: - Date picker (replaces `DatePicker` / `.graphical` on sheets)

/// Month calendar matching History chrome: same header, weekday row, and day cells (`GLCalendarMetrics`).
struct GLCalendarDatePickerPanel: View {
    @Binding var selectedDate: Date
    /// When set, days after the start of this day are disabled; months beyond it cannot be navigated to.
    var maximumDate: Date?
    /// Optional lower bound (start of day semantics).
    var minimumDate: Date?

    @State private var monthStart: Date

    private let cal = Calendar.current

    init(selectedDate: Binding<Date>, maximumDate: Date? = nil, minimumDate: Date? = nil) {
        self._selectedDate = selectedDate
        self.maximumDate = maximumDate
        self.minimumDate = minimumDate
        _monthStart = State(initialValue: GLCalendarISO.startOfMonth(containing: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GLCalendarMetrics.sectionSpacing) {
            GLCalendarMonthNavigationHeaderBounded(
                monthStart: $monthStart,
                canGoPrevious: canGoToPreviousMonth,
                canGoNext: canGoToNextMonth
            )

            GLCalendarWeekdayHeaderRow()

            GLCalendarMonthGridShell(paddedCells: GLCalendarISO.paddedMonthCells(for: monthStart)) { day in
                let ymd = GLCalendarISO.ymd(for: day)
                let selYmd = GLCalendarISO.ymd(for: selectedDate)
                let enabled = isDaySelectable(day)
                GLCalendarDayCell(
                    day: day,
                    isSelected: enabled && selYmd == ymd,
                    isEnabled: enabled,
                    onTap: {
                        selectedDate = cal.startOfDay(for: day)
                    },
                    accessory: {
                        Color.clear.frame(height: GLCalendarMetrics.accessoryStackHeight)
                    }
                )
            }
        }
        .onChange(of: selectedDate) { _, new in
            syncMonthIfNeeded(for: new)
        }
        .onAppear {
            syncMonthIfNeeded(for: selectedDate)
        }
    }

    private func syncMonthIfNeeded(for date: Date) {
        let m = GLCalendarISO.startOfMonth(containing: date)
        if m != monthStart {
            monthStart = m
        }
    }

    private var canGoToPreviousMonth: Bool {
        guard let minD = minimumDate else { return true }
        guard let prev = cal.date(byAdding: .month, value: -1, to: monthStart) else { return false }
        let minMonth = GLCalendarISO.startOfMonth(containing: minD)
        return prev >= minMonth
    }

    private var canGoToNextMonth: Bool {
        guard let maxD = maximumDate else { return true }
        guard let next = cal.date(byAdding: .month, value: 1, to: monthStart) else { return false }
        let maxMonth = GLCalendarISO.startOfMonth(containing: maxD)
        return next <= maxMonth
    }

    private func isDaySelectable(_ day: Date) -> Bool {
        let start = cal.startOfDay(for: day)
        if let maxD = maximumDate, start > cal.startOfDay(for: maxD) { return false }
        if let minD = minimumDate, start < cal.startOfDay(for: minD) { return false }
        return true
    }
}
