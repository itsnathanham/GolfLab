import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String?
    var homeCourseName: String?
    var homeCourseTee: String?
    var preferredUnits: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName    = "display_name"
        case homeCourseName = "home_course_name"
        case homeCourseTee  = "home_course_tee"
        case preferredUnits = "preferred_units"
    }
}
