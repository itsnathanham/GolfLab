import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct RoundLiveActivityWidget: Widget {
    private static let cardGreen = Color(red: 8 / 255, green: 86 / 255, blue: 46 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundLiveActivityBanner(context: context)
                .activityBackgroundTint(Self.cardGreen)
                .widgetURL(ActiveRoundLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RoundActivityAvatar(context: context, side: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RoundActivityScoreStack(context: context, scoreSize: 20, thruSize: 12)
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
                RoundActivityScoreStack(context: context, scoreSize: 12, thruSize: 9)
            } minimal: {
                RoundActivityScoreText(state: context.state)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .widgetURL(ActiveRoundLink.url)
        }
    }
}

private struct RoundLiveActivityBanner: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            RoundActivityAvatar(context: context, side: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.courseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    RoundActivityScoreText(state: context.state)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if context.state.holesCompleted > 0 {
                        Text("thru \(context.state.holesCompleted)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
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

private struct RoundActivityScoreText: View {
    let state: RoundLiveActivityAttributes.ContentState

    var body: some View {
        Text(state.hasSavedHole ? GLVsParLabel.text(state.scoreVsPar) : "—")
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var color: Color {
        guard state.hasSavedHole else { return .white }
        if state.scoreVsPar < 0 { return .accent }
        if state.scoreVsPar > 0 { return .chartNegative }
        return .white
    }
}

private struct RoundActivityAvatar: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>
    let side: CGFloat

    var body: some View {
        Group {
            if let data = context.attributes.profilePhotoJPEG, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(context.attributes.initials.isEmpty ? "?" : context.attributes.initials)
                    .font(.system(size: side * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.18))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
    }
}

@main
struct GolfLabWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RoundLiveActivityWidget()
    }
}
