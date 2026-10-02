import Foundation
import SwiftData

@Model
final class SDProfile {
    var id: UUID = UUID()
    var displayName: String?
    var homeCourseName: String?
    var homeCourseTee: String?
    var preferredUnits: String = "yards"
    var weeklyRoundTarget: Int?
    var weeklyPracticeTarget: Int?
    var weeklyGoalTargetRevisionsData: Data?
    var stockClubYardagesData: Data?

    init(
        id: UUID = UUID(),
        displayName: String? = nil,
        homeCourseName: String? = nil,
        homeCourseTee: String? = nil,
        preferredUnits: String = "yards",
        weeklyRoundTarget: Int? = nil,
        weeklyPracticeTarget: Int? = nil,
        weeklyGoalTargetRevisionsData: Data? = nil,
        stockClubYardagesData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.homeCourseName = homeCourseName
        self.homeCourseTee = homeCourseTee
        self.preferredUnits = preferredUnits
        self.weeklyRoundTarget = weeklyRoundTarget
        self.weeklyPracticeTarget = weeklyPracticeTarget
        self.weeklyGoalTargetRevisionsData = weeklyGoalTargetRevisionsData
        self.stockClubYardagesData = stockClubYardagesData
    }
}

@Model
final class SDRound {
    var id: UUID = UUID()
    var userId: UUID = UUID()
    var courseName: String = ""
    var tee: String?
    var holesCount: Int = 18
    var datePlayed: String = ""
    var totalScore: Int?
    var totalPutts: Int?
    var totalGir: Int?
    var totalFir: Int?
    var createdAt: String?
    var updatedAt: String?

    @Relationship(deleteRule: .cascade, inverse: \SDHole.round)
    var holes: [SDHole]? = []

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        courseName: String = "",
        tee: String? = nil,
        holesCount: Int = 18,
        datePlayed: String = "",
        totalScore: Int? = nil,
        totalPutts: Int? = nil,
        totalGir: Int? = nil,
        totalFir: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.courseName = courseName
        self.tee = tee
        self.holesCount = holesCount
        self.datePlayed = datePlayed
        self.totalScore = totalScore
        self.totalPutts = totalPutts
        self.totalGir = totalGir
        self.totalFir = totalFir
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SDHole {
    var id: UUID = UUID()
    var roundId: UUID = UUID()
    var userId: UUID = UUID()
    var holeNumber: Int = 1
    var par: Int = 4
    var yardage: Int?
    var strokeIndex: Int?
    var score: Int = 0
    var putts: Int = 0
    var gir: Bool = false
    var fir: Bool?
    var penalty: Bool?
    var createdAt: String?
    var updatedAt: String?
    var round: SDRound?

    init(
        id: UUID = UUID(),
        roundId: UUID = UUID(),
        userId: UUID = UUID(),
        holeNumber: Int = 1,
        par: Int = 4,
        yardage: Int? = nil,
        strokeIndex: Int? = nil,
        score: Int = 0,
        putts: Int = 0,
        gir: Bool = false,
        fir: Bool? = nil,
        penalty: Bool? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.roundId = roundId
        self.userId = userId
        self.holeNumber = holeNumber
        self.par = par
        self.yardage = yardage
        self.strokeIndex = strokeIndex
        self.score = score
        self.putts = putts
        self.gir = gir
        self.fir = fir
        self.penalty = penalty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SDPracticeSession {
    var id: UUID = UUID()
    var userId: UUID = UUID()
    var sessionDate: String = ""
    var practicedRange: Bool = false
    var practicedChipping: Bool = false
    var practicedPutting: Bool = false
    var rangeBallsHit: Int?
    var createdAt: String?

    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        sessionDate: String = "",
        practicedRange: Bool = false,
        practicedChipping: Bool = false,
        practicedPutting: Bool = false,
        rangeBallsHit: Int? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.sessionDate = sessionDate
        self.practicedRange = practicedRange
        self.practicedChipping = practicedChipping
        self.practicedPutting = practicedPutting
        self.rangeBallsHit = rangeBallsHit
        self.createdAt = createdAt
    }
}

enum GolfLabTimestamp {
    static func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

enum GolfLabCloud {
    static let containerIdentifier = "iCloud.com.nathanhamilton.golflab"
}
