import SwiftUI
import WidgetKit

struct ActiveRoundComplicationEntry: TimelineEntry {
    let date: Date
    let holeNumber: Int?
}

struct ActiveRoundComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveRoundComplicationEntry {
        ActiveRoundComplicationEntry(date: .now, holeNumber: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveRoundComplicationEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveRoundComplicationEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> ActiveRoundComplicationEntry {
        ActiveRoundComplicationEntry(date: .now, holeNumber: WatchComplicationStore.activeHoleNumber())
    }
}

struct ActiveRoundComplicationView: View {
    let entry: ActiveRoundComplicationEntry

    var body: some View {
        Group {
            if let holeNumber = entry.holeNumber {
                Text("\(holeNumber)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
            } else {
                GLComplicationIcon()
            }
        }
        .foregroundStyle(Color.white)
    }
}

struct ActiveRoundComplicationWidget: Widget {
    /// Sampled from the phone and watch app icon background.
    static let iconGreen = Color(red: 8 / 255, green: 86 / 255, blue: 46 / 255)

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchComplicationStore.widgetKind, provider: ActiveRoundComplicationProvider()) { entry in
            ActiveRoundComplicationView(entry: entry)
                .containerBackground(Self.iconGreen, for: .widget)
        }
        .configurationDisplayName("Current Hole")
        .description("Shows the active hole number.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct GolfLabWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        ActiveRoundComplicationWidget()
    }
}
