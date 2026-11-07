import ActivityKit
import SwiftUI
import WidgetKit

struct RoundLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundLiveActivityCard(context: context)
                .activityBackgroundTint(RoundLiveActivityBanner.background)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RoundActivityAvatar(context: context, side: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RoundActivityScoreStack(context: context, scoreSize: 26, thruSize: 12)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.courseName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                RoundActivityAvatar(context: context, side: 24)
            } compactTrailing: {
                RoundActivityScoreStack(context: context, scoreSize: 16, thruSize: 9)
            } minimal: {
                RoundActivityScoreText(state: context.state)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct RoundLiveActivityCard: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<RoundLiveActivityAttributes>

    var body: some View {
        RoundLiveActivityBanner(context: context, compact: activityFamily == .small)
    }
}

private struct RoundActivityScoreStack: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>
    let scoreSize: CGFloat
    let thruSize: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            RoundActivityScoreText(state: context.state)
                .font(.system(size: scoreSize, weight: .bold, design: .rounded))
            if context.state.holesCompleted > 0 {
                Text("thru \(context.state.holesCompleted)")
                    .font(.system(size: thruSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
}

@main
struct GolfLabWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RoundLiveActivityWidget()
    }
}
