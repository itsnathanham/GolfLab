import Foundation

enum VsParCumulativeProgression {
    static let chartHoleSlots = 18
    static let minimumCompletedRounds = 2

    static func isRoundComplete(_ round: Round, holeRowCount: Int) -> Bool {
        round.holes > 0 && holeRowCount >= round.holes
    }

    static func cumulativeValues(
        from holes: [Hole],
        roundHoleCount: Int,
        slotCount: Int = chartHoleSlots
    ) -> [Double]? {
        guard roundHoleCount > 0, slotCount > 0 else { return nil }
        let sorted = holes.sorted { $0.holeNumber < $1.holeNumber }
        guard !sorted.isEmpty else { return nil }

        var running = 0.0
        var byHole: [Int: Double] = [:]
        for hole in sorted where (1...roundHoleCount).contains(hole.holeNumber) {
            running += Double(hole.score - hole.par)
            byHole[hole.holeNumber] = running
        }
        guard (1...roundHoleCount).allSatisfy({ byHole[$0] != nil }) else { return nil }

        var result: [Double] = []
        var last = 0.0
        for index in 1...slotCount {
            if index <= roundHoleCount, let value = byHole[index] {
                last = value
                result.append(value)
            } else {
                result.append(last)
            }
        }
        return result
    }

    static func averageSeries(
        holesByRoundId: [UUID: [Hole]],
        rounds: [Round],
        holeRowCountByRoundId: [UUID: Int],
        slotCount: Int = chartHoleSlots,
        minimumRoundsContributing: Int = minimumCompletedRounds
    ) -> VsParLineChartSeries? {
        guard slotCount > 0 else { return nil }
        var perRoundValues: [[Double]] = []
        for round in rounds {
            guard let holes = holesByRoundId[round.id],
                  hasCompleteScorecard(round: round, holes: holes, holeRowCount: holeRowCountByRoundId[round.id] ?? 0),
                  let values = cumulativeValues(from: holes, roundHoleCount: round.holes, slotCount: slotCount)
            else { continue }
            perRoundValues.append(values)
        }
        guard perRoundValues.count >= minimumRoundsContributing else { return nil }

        var averaged: [Double] = []
        for index in 0..<slotCount {
            let sum = perRoundValues.reduce(0.0) { $0 + $1[index] }
            averaged.append(sum / Double(perRoundValues.count))
        }
        return VsParLineChartSeries(roundValues: averaged)
    }

    static func seasonAverageOverlaySeries(
        holesByRoundId: [UUID: [Hole]],
        seasonRounds: [Round],
        holeRowCountByRoundId: [UUID: Int],
        chartHoleCount: Int
    ) -> VsParLineChartSeries? {
        let completedCount = seasonRounds.filter { round in
            hasCompleteScorecard(
                round: round,
                holes: holesByRoundId[round.id],
                holeRowCount: holeRowCountByRoundId[round.id] ?? 0
            )
        }.count
        guard completedCount >= minimumCompletedRounds else { return nil }
        return averageSeries(
            holesByRoundId: holesByRoundId,
            rounds: seasonRounds,
            holeRowCountByRoundId: holeRowCountByRoundId,
            slotCount: chartHoleCount,
            minimumRoundsContributing: minimumCompletedRounds
        )
    }

    static func hasCompleteScorecard(round: Round, holes: [Hole]?, holeRowCount: Int) -> Bool {
        if isRoundComplete(round, holeRowCount: holeRowCount) { return true }
        guard let holes else { return false }
        return holes.count >= round.holes
    }
}
