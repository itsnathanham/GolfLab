import Foundation
import ActivityKit
import os

private let liveActivityLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "GolfLab",
    category: "LiveActivity"
)

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<RoundLiveActivityAttributes>?
    
    private init() {}
    
    func startActivity(
        userId: UUID,
        roundId: UUID,
        courseName: String,
        currentHole: Int,
        scoreVsPar: Int,
        totalHoles: Int,
        profilePhotoPath: String?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityLogger.info("Live Activities are not enabled")
            return
        }
        
        endActivity()
        
        let attributes = RoundLiveActivityAttributes(
            userId: userId,
            roundId: roundId,
            courseName: courseName,
            profilePhotoPath: profilePhotoPath
        )
        
        let contentState = RoundLiveActivityAttributes.ContentState(
            currentHole: currentHole,
            scoreVsPar: scoreVsPar,
            totalHoles: totalHoles
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            liveActivityLogger.info("Started Live Activity for round \(roundId)")
        } catch {
            liveActivityLogger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(
        currentHole: Int,
        scoreVsPar: Int,
        totalHoles: Int
    ) {
        guard let activity = currentActivity else {
            liveActivityLogger.info("No active Live Activity to update")
            return
        }
        
        let contentState = RoundLiveActivityAttributes.ContentState(
            currentHole: currentHole,
            scoreVsPar: scoreVsPar,
            totalHoles: totalHoles
        )
        
        Task {
            await activity.update(
                .init(state: contentState, staleDate: nil)
            )
            liveActivityLogger.info("Updated Live Activity: hole \(currentHole), score \(scoreVsPar)")
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            liveActivityLogger.info("Ended Live Activity")
        }
    }
    
    var isActivityActive: Bool {
        currentActivity != nil
    }
}
