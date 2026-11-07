import ActivityKit
import SwiftUI
import WidgetKit

/// Watch Smart Stack presentation of the phone's round Live Activity.
/// Shipping this widget makes a tap open the watch app instead of prompting for the iPhone.
struct RoundWatchLiveActivityWidget: Widget {
    private static let cardGreen = Color(red: 8 / 255, green: 86 / 255, blue: 46 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.hasSavedHole ? GLVsParLabel.text(context.state.scoreVsPar) : "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchPalette.chartPositive)
                if context.state.holesCompleted > 0 {
                    Text("thru \(context.state.holesCompleted)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(context.attributes.courseName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .activityBackgroundTint(Self.cardGreen)
        }
    }
}
