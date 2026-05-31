import Foundation
import WidgetKit

enum WatchComplicationStore {
    static let appGroupIdentifier = "group.com.nathanhamilton.golflab"
    static let widgetKind = "ActiveRoundComplication"

    private enum Key {
        static let isRoundActive = "watchComplication.isRoundActive"
        static let displayHoleNumber = "watchComplication.displayHoleNumber"
    }

    static func activeHoleNumber() -> Int? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.bool(forKey: Key.isRoundActive)
        else { return nil }
        let hole = defaults.integer(forKey: Key.displayHoleNumber)
        return hole > 0 ? hole : nil
    }

    static func publish(displayHoleNumber: Int?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(displayHoleNumber != nil, forKey: Key.isRoundActive)
        if let displayHoleNumber {
            defaults.set(displayHoleNumber, forKey: Key.displayHoleNumber)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
