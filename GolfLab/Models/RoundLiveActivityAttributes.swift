import Foundation
import ActivityKit

struct RoundLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentHole: Int
        var scoreVsPar: Int
        var totalHoles: Int
    }
    
    var userId: UUID
    var roundId: UUID
    var courseName: String
    var profilePhotoPath: String?
}
