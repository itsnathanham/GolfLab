import SwiftUI
import WidgetKit

struct ActiveRoundComplicationEntry: TimelineEntry {
    let date: Date
    let holeNumber: Int?
    let scoreVsPar: Int?
}

struct ActiveRoundComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveRoundComplicationEntry {
        ActiveRoundComplicationEntry(date: .now, holeNumber: 1, scoreVsPar: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveRoundComplicationEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveRoundComplicationEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> ActiveRoundComplicationEntry {
        let data = WatchComplicationStore.activeRoundData()
        return ActiveRoundComplicationEntry(
            date: .now,
            holeNumber: data.holeNumber,
            scoreVsPar: data.scoreVsPar
        )
    }
}

struct ActiveRoundComplicationView: View {
    let entry: ActiveRoundComplicationEntry

    var body: some View {
        Group {
            if let holeNumber = entry.holeNumber, let scoreVsPar = entry.scoreVsPar {
                VStack(spacing: 2) {
                    Text(scoreText(scoreVsPar))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(scoreVsPar))
                    Text("H\(holeNumber)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            } else {
                GLComplicationIcon()
            }
        }
        .foregroundStyle(Color.white)
    }
    
    private func scoreText(_ score: Int) -> String {
        score > 0 ? "+\(score)" : score == 0 ? "E" : "\(score)"
    }
    
    private func scoreColor(_ score: Int) -> Color {
        score > 0 ? .red : score < 0 ? .green : .white
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
