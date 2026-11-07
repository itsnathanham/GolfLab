import SwiftUI
import WidgetKit
import ActivityKit

struct RoundLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    profileImageView(context: context)
                        .frame(width: 40, height: 40)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        scoreVsParView(context: context)
                        thruTextView(context: context)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.courseName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                profileImageView(context: context)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                HStack(spacing: 4) {
                    scoreVsParView(context: context)
                        .font(.system(size: 12, weight: .semibold))
                }
            } minimal: {
                scoreVsParView(context: context)
                    .font(.system(size: 10, weight: .bold))
            }
        }
    }
    
    @ViewBuilder
    private func profileImageView(context: ActivityViewContext<RoundLiveActivityAttributes>) -> some View {
        if let photoPath = context.attributes.profilePhotoPath,
           let image = ProfilePhotoStorage.loadProfilePhoto(path: photoPath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text("⛳️")
                        .font(.system(size: 20))
                )
        }
    }
    
    @ViewBuilder
    private func scoreVsParView(context: ActivityViewContext<RoundLiveActivityAttributes>) -> some View {
        let score = context.state.scoreVsPar
        let scoreText = score > 0 ? "+\(score)" : score == 0 ? "E" : "\(score)"
        let scoreColor: Color = score > 0 ? .red : score < 0 ? .green : .white
        
        Text(scoreText)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(scoreColor)
    }
    
    @ViewBuilder
    private func thruTextView(context: ActivityViewContext<RoundLiveActivityAttributes>) -> some View {
        let thruHole = context.state.currentHole - 1
        if thruHole > 0 {
            Text("thru \(thruHole)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct RoundLiveActivityLockScreenView: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            if let photoPath = context.attributes.profilePhotoPath,
               let image = ProfilePhotoStorage.loadProfilePhoto(path: photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("⛳️")
                            .font(.system(size: 24))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.courseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    scoreVsParBadge
                    thruText
                }
            }
            
            Spacer()
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.3))
    }
    
    private var scoreVsParBadge: some View {
        let score = context.state.scoreVsPar
        let scoreText = score > 0 ? "+\(score)" : score == 0 ? "E" : "\(score)"
        let scoreColor: Color = score > 0 ? .red : score < 0 ? .green : .white
        
        return Text(scoreText)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(scoreColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
            )
    }
    
    private var thruText: some View {
        let thruHole = context.state.currentHole - 1
        if thruHole > 0 {
            return Text("thru \(thruHole)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        } else {
            return Text("")
        }
    }
}

@main
struct GolfLabWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RoundLiveActivityWidget()
    }
}
