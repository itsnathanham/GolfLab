import Foundation

/// Clubs available for stock yardage setup (no hybrids).
enum StockClub: String, Codable, CaseIterable, Identifiable, Sendable {
    case driver
    case wood3
    case wood5
    case wood7
    case wood9
    case iron1
    case iron2
    case iron3
    case iron4
    case iron5
    case iron6
    case iron7
    case iron8
    case iron9
    case pitchingWedge
    case gapWedge
    case sandWedge
    case lobWedge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .driver: return "Driver"
        case .wood3: return "3W"
        case .wood5: return "5W"
        case .wood7: return "7W"
        case .wood9: return "9W"
        case .iron1: return "1 iron"
        case .iron2: return "2 iron"
        case .iron3: return "3 iron"
        case .iron4: return "4 iron"
        case .iron5: return "5 iron"
        case .iron6: return "6 iron"
        case .iron7: return "7 iron"
        case .iron8: return "8 iron"
        case .iron9: return "9 iron"
        case .pitchingWedge: return "PW"
        case .gapWedge: return "Gap wedge"
        case .sandWedge: return "Sand wedge"
        case .lobWedge: return "Lob wedge"
        }
    }

    /// Starter bag: driver, 3W, 3–PW, gap / sand / lob.
    static var defaultBag: [StockClub] {
        [
            .driver,
            .wood3,
            .iron3, .iron4, .iron5, .iron6, .iron7, .iron8, .iron9, .pitchingWedge,
            .gapWedge, .sandWedge, .lobWedge
        ]
    }
}

struct StockClubYardage: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var club: StockClub
    /// Yards; template rows may be nil until the user sets a value.
    var yardage: Int?
    /// User list order (0-based). Not club-family sorting.
    var displayOrder: Int

    init(id: UUID = UUID(), club: StockClub, yardage: Int? = nil, displayOrder: Int = 0) {
        self.id = id
        self.club = club
        self.yardage = yardage
        self.displayOrder = displayOrder
    }
}

enum GLStockClubYardages {
    static let minYards = 1
    static let maxYards = 400
    static let step = 5
    static let defaultYardsWhenSetting = 100

    static func defaultBagRows() -> [StockClubYardage] {
        StockClub.defaultBag.enumerated().map { index, club in
            StockClubYardage(club: club, yardage: nil, displayOrder: index)
        }
    }

    /// Stable list order from `displayOrder` (insertion / saved order).
    static func ordered(_ rows: [StockClubYardage]) -> [StockClubYardage] {
        rows.sorted { lhs, rhs in
            if lhs.displayOrder != rhs.displayOrder {
                return lhs.displayOrder < rhs.displayOrder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Rewrites `displayOrder` to match the current array index.
    static func withDisplayOrders(_ rows: [StockClubYardage]) -> [StockClubYardage] {
        rows.enumerated().map { index, row in
            var copy = row
            copy.displayOrder = index
            return copy
        }
    }

    static func clampYards(_ value: Int) -> Int {
        min(maxYards, max(minYards, value))
    }
}
