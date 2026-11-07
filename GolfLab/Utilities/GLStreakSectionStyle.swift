import Foundation

/// Home / History weekly goals presentation. Persisted locally so both layouts can be A/B’d on device.
enum GLStreakSectionStyle: String, CaseIterable, Identifiable {
    case flagstick
    case hero

    var id: String { rawValue }

    static let defaultsKey = "gl.streakSectionStyle"

    var title: String {
        switch self {
        case .flagstick: return "Flagstick"
        case .hero: return "Streak hero"
        }
    }

    var detail: String {
        switch self {
        case .flagstick:
            return "Classic weekly goals card with flagstick week marks."
        case .hero:
            return "Big streak count, week strip, and compact goal chips."
        }
    }
}
