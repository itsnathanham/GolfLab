import Foundation

enum GLPracticeRangeBalls {
    static let defaultCount = 50
    static let step = 5
    static let min = 1

    static func weeklyGoalsFootnote(count: Int) -> String? {
        count > 0 ? "\(count) range balls hit this week" : nil
    }
}
