import ActivityKit
import Foundation

struct RoundLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Saved holes. "thru 2" means two holes are in and the player is on the next one.
        var holesCompleted: Int
        var scoreVsPar: Int
        var hasSavedHole: Bool
    }

    var courseName: String
    var initials: String
    /// Small JPEG for the island and lock screen. Kept under ActivityKit's payload budget.
    var profilePhotoJPEG: Data?
}
