import Foundation

enum HoleFilter: String, CaseIterable {
    case all = "All rounds"
    case eighteen = "18 holes"
    case nine = "9 holes"
    
    var displayTitle: String { rawValue }
    
    var holeCount: Int? {
        switch self {
        case .all: return nil
        case .eighteen: return 18
        case .nine: return 9
        }
    }
}

enum HoleFilterState {
    private static let holeFilterDefaultsKey = "GolfLabSelectedHoleFilter"
    
    static func persistHoleFilter(_ filter: HoleFilter) {
        UserDefaults.standard.set(filter.rawValue, forKey: holeFilterDefaultsKey)
    }
    
    static func restoredHoleFilter(rounds: [Round]) -> HoleFilter {
        if let stored = UserDefaults.standard.string(forKey: holeFilterDefaultsKey),
           let filter = HoleFilter(rawValue: stored),
           hasRounds(for: filter, in: rounds) {
            return filter
        }
        return defaultHoleFilter(rounds: rounds)
    }
    
    static func defaultHoleFilter(rounds: [Round]) -> HoleFilter {
        guard !rounds.isEmpty else { return .all }
        
        let nineCt = rounds.filter { $0.holes == 9 }.count
        let eighteenCt = rounds.filter { $0.holes == 18 }.count
        
        if eighteenCt > nineCt {
            return .eighteen
        } else if nineCt > eighteenCt {
            return .nine
        }
        return .all
    }
    
    static func hasRounds(for filter: HoleFilter, in rounds: [Round]) -> Bool {
        guard let holeCount = filter.holeCount else { return true }
        return rounds.contains { $0.holes == holeCount }
    }
    
    static func filteredRounds(_ rounds: [Round], filter: HoleFilter) -> [Round] {
        guard let holeCount = filter.holeCount else { return rounds }
        return rounds.filter { $0.holes == holeCount }
    }
}
