import Foundation
import WidgetKit

enum WatchComplicationStore {
    static let appGroupIdentifier = "group.com.nathanhamilton.golflab"
    static let widgetKind = "ActiveRoundComplication"

    private enum Key {
        static let isRoundActive = "watchComplication.isRoundActive"
        static let displayHoleNumber = "watchComplication.displayHoleNumber"
        static let scoreVsPar = "watchComplication.scoreVsPar"
    }

    static func activeHoleNumber() -> Int? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.bool(forKey: Key.isRoundActive)
        else { return nil }
        let hole = defaults.integer(forKey: Key.displayHoleNumber)
        return hole > 0 ? hole : nil
    }
    
    static func activeRoundData() -> (holeNumber: Int?, scoreVsPar: Int?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.bool(forKey: Key.isRoundActive)
        else { return (nil, nil) }
        let hole = defaults.integer(forKey: Key.displayHoleNumber)
        let score = defaults.object(forKey: Key.scoreVsPar) as? Int
        return (hole > 0 ? hole : nil, score)
    }

    static func publish(displayHoleNumber: Int?, scoreVsPar: Int? = nil) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(displayHoleNumber != nil, forKey: Key.isRoundActive)
        if let displayHoleNumber {
            defaults.set(displayHoleNumber, forKey: Key.displayHoleNumber)
        } else {
            defaults.removeObject(forKey: Key.displayHoleNumber)
        }
        if let scoreVsPar {
            defaults.set(scoreVsPar, forKey: Key.scoreVsPar)
        } else {
            defaults.removeObject(forKey: Key.scoreVsPar)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
