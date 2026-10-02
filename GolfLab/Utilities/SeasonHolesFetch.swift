import Foundation

enum SeasonHolesFetch {
    static func calendarYearRounds(from allRounds: [Round], year: Int? = nil) -> [Round] {
        let y = year ?? Calendar.current.component(.year, from: Date())
        return allRounds.filter { $0.datePlayed.hasPrefix("\(y)") }
    }

    static func flattenedCompletedHoles(
        seasonRounds: [Round],
        holesByRoundId: [UUID: [Hole]],
        holeRowCountByRoundId: [UUID: Int]
    ) -> [Hole] {
        seasonRounds
            .filter { round in
                VsParCumulativeProgression.hasCompleteScorecard(
                    round: round,
                    holes: holesByRoundId[round.id],
                    holeRowCount: holeRowCountByRoundId[round.id] ?? 0
                )
            }
            .compactMap { holesByRoundId[$0.id] }
            .flatMap { $0 }
    }
}
