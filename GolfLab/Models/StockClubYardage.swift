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

    /// Menu / row label.
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

    /// Stable bag order: driver → woods → irons → gap/sand/lob.
    var sortIndex: Int {
        switch self {
        case .driver: return 0
        case .wood3: return 10
        case .wood5: return 11
        case .wood7: return 12
        case .wood9: return 13
        case .iron1: return 20
        case .iron2: return 21
        case .iron3: return 22
        case .iron4: return 23
        case .iron5: return 24
        case .iron6: return 25
        case .iron7: return 26
        case .iron8: return 27
        case .iron9: return 28
        case .pitchingWedge: return 29
        case .gapWedge: return 40
        case .sandWedge: return 41
        case .lobWedge: return 42
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

/// One club + stock carry distance (yards).
struct StockClubYardage: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var club: StockClub
    /// Yards; required once the row is committed. Template rows may be nil until set.
    var yardage: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case club
        case yardage
    }

    init(id: UUID = UUID(), club: StockClub, yardage: Int? = nil) {
        self.id = id
        self.club = club
        self.yardage = yardage
    }

    var hasRequiredYardage: Bool {
        guard let yardage else { return false }
        return yardage >= GLStockClubYardages.minYards
    }
}

enum GLStockClubYardages {
    static let minYards = 1
    static let maxYards = 400
    static let step = 5
    /// First + tap on an unset row lands here (same spirit as range-ball defaults).
    static let defaultYardsWhenSetting = 100

    static func defaultBagRows() -> [StockClubYardage] {
        StockClub.defaultBag.map { StockClubYardage(club: $0, yardage: nil) }
    }

    static func sorted(_ rows: [StockClubYardage]) -> [StockClubYardage] {
        rows.sorted { lhs, rhs in
            if lhs.club.sortIndex != rhs.club.sortIndex {
                return lhs.club.sortIndex < rhs.club.sortIndex
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
