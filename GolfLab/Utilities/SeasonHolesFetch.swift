import Foundation

enum SeasonHolesFetch {
    static func holesByRoundId(
        rounds: [Round],
        holeRowCountByRoundId: [UUID: Int]
    ) async -> [UUID: [Hole]] {
        var result: [UUID: [Hole]] = [:]
        await withTaskGroup(of: (UUID, [Hole])?.self) { group in
            for round in rounds {
                let rowCount = holeRowCountByRoundId[round.id] ?? 0
                guard VsParCumulativeProgression.isRoundComplete(round, holeRowCount: rowCount) else { continue }
                group.addTask {
                    let holes = (try? await SupabaseService.shared.fetchHoles(roundId: round.id)) ?? []
                    guard holes.count >= round.holes else { return nil }
                    return (round.id, holes)
                }
            }
            for await pair in group {
                if let pair { result[pair.0] = pair.1 }
            }
        }
        return result
    }

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
