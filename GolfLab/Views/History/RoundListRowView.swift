import SwiftUI

/// History / Home recent round row (course, meta, vs par, total).
struct RoundListRowView: View {
    @EnvironmentObject private var roundStore: RoundStore
    let round: Round
    /// When true, shows an **Incomplete** flag on the title row when stored hole rows are fewer than `round.holes` (History uses this).
    var showIncompleteFlag: Bool = false

    private var isIncompleteRound: Bool {
        guard showIncompleteFlag,
              let n = roundStore.holeRowCountByRoundId[round.id]
        else { return false }
        return round.isScorecardIncomplete(storedHoleRows: n)
    }

    private var vsParDisplay: (text: String, color: Color) {
        guard let score = round.totalScore,
              let par = roundStore.totalParSumByRoundId[round.id],
              par > 0
        else { return ("—", .textTertiary) }
        let delta = score - par
        if delta == 0 {
            return ("E", .textTertiary)
        }
        let raw = String(format: "%+.0f", Double(delta))
        let text = raw.replacingOccurrences(of: "-", with: "\u{2212}")
        let color: Color = delta < 0 ? .accent : .chartNegative
        return (text, color)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    Text(round.courseName)
                        .font(.glSubhead)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    if isIncompleteRound {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Incomplete")
                                .font(.glFilterActive)
                        }
                        .foregroundColor(.chartNegative)
                    }
                }
                Text(Self.metaLine(for: round))
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(vsParDisplay.text)
                        .font(GLFonts.mono(size: 17, weight: .semibold))
                        .foregroundColor(vsParDisplay.color)
                    if let score = round.totalScore {
                        Text("\(score) total")
                            .font(GLFonts.mono(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                Text("›")
                    .font(GLFonts.sans(size: 14, weight: .regular))
                    .foregroundColor(.textTertiary)
                    .frame(alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    static func metaLine(for round: Round) -> String {
        let holesPart = "\(round.holes) holes"
        guard let date = ymdDate(round.datePlayed) else {
            return "\(round.datePlayedDisplay) · \(holesPart)"
        }
        if Calendar.current.isDateInToday(date) {
            return "Today · \(holesPart)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday · \(holesPart)"
        }
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return "\(df.string(from: date)) · \(holesPart)"
    }

    private static func ymdDate(_ ymd: String) -> Date? {
        let head = String(ymd.prefix(10))
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
        return Calendar.current.date(from: dc)
    }
}
