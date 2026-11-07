import ActivityKit
import Foundation

struct RoundLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Saved holes. "thru 2" means two holes are in and the player is on the next one.
        var holesCompleted: Int
        var scoreVsPar: Int
        var hasSavedHole: Bool
        /// Small JPEG. Lives on the content state so a running activity can gain a photo
        /// with an update. Starting a new activity is foreground-only.
        var profilePhotoJPEG: Data?

        init(holesCompleted: Int, scoreVsPar: Int, hasSavedHole: Bool, profilePhotoJPEG: Data? = nil) {
            self.holesCompleted = holesCompleted
            self.scoreVsPar = scoreVsPar
            self.hasSavedHole = hasSavedHole
            self.profilePhotoJPEG = profilePhotoJPEG
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            holesCompleted = try container.decode(Int.self, forKey: .holesCompleted)
            scoreVsPar = try container.decode(Int.self, forKey: .scoreVsPar)
            hasSavedHole = try container.decode(Bool.self, forKey: .hasSavedHole)
            profilePhotoJPEG = try container.decodeIfPresent(Data.self, forKey: .profilePhotoJPEG)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(holesCompleted, forKey: .holesCompleted)
            try container.encode(scoreVsPar, forKey: .scoreVsPar)
            try container.encode(hasSavedHole, forKey: .hasSavedHole)
            try container.encodeIfPresent(profilePhotoJPEG, forKey: .profilePhotoJPEG)
        }

        private enum CodingKeys: String, CodingKey {
            case holesCompleted
            case scoreVsPar
            case hasSavedHole
            case profilePhotoJPEG
        }
    }

    var courseName: String
    var initials: String
    /// Photo captured when the activity started. Later photos arrive on `ContentState`.
    var profilePhotoJPEG: Data?
}
