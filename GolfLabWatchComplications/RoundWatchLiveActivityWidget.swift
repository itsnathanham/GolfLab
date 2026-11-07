import ActivityKit
import SwiftUI
import WidgetKit

/// Smart Stack card. A watch widget here makes a tap open the watch app.
struct RoundWatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundLiveActivityBanner(context: context)
                .activityBackgroundTint(RoundLiveActivityBanner.background)
        }
    }
}
