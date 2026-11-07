import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// Lock Screen card. The same layout, slightly tighter, is the watch Smart Stack card.
struct RoundLiveActivityBanner: View {
    static let background = Color(red: 8 / 255, green: 86 / 255, blue: 46 / 255)

    let context: ActivityViewContext<RoundLiveActivityAttributes>
    var compact = false

    var body: some View {
        let avatarSide: CGFloat = compact ? 32 : 44
        let courseSize: CGFloat = compact ? 13 : 15
        let scoreSize: CGFloat = compact ? 16 : 18
        let thruSize: CGFloat = compact ? 12 : 14
        HStack(spacing: compact ? 8 : 12) {
            RoundActivityAvatar(context: context, side: avatarSide)
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(context.attributes.courseName)
                    .font(.system(size: courseSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: compact ? 6 : 8) {
                    RoundActivityScoreText(state: context.state)
                        .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                    if context.state.holesCompleted > 0 {
                        Text("thru \(context.state.holesCompleted)")
                            .font(.system(size: thruSize, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 16)
    }
}

struct RoundActivityAvatar: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>
    let side: CGFloat

    var body: some View {
        Group {
            if let data = context.state.profilePhotoJPEG ?? context.attributes.profilePhotoJPEG,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(context.attributes.initials.isEmpty ? "?" : context.attributes.initials)
                    .font(.system(size: side * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.18))
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .clipShape(Circle())
    }
}

struct RoundActivityScoreText: View {
    let state: RoundLiveActivityAttributes.ContentState

    var body: some View {
        Text(state.hasSavedHole ? GLVsParLabel.text(state.scoreVsPar) : "—")
            .foregroundStyle(Color.green)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
