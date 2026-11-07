import ActivityKit
import os
import UIKit

private let liveActivityLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "GolfLab",
    category: "LiveActivity"
)

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var chain: Task<Void, Never>?

    private init() {}

    func sync(
        courseName: String,
        initials: String,
        photo: UIImage?,
        state: RoundLiveActivityAttributes.ContentState,
        replacePhoto: Bool = false
    ) {
        enqueue { [photo] in
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let existing = Activity<RoundLiveActivityAttributes>.activities
            if let current = existing.first {
                for extra in existing.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
                let photoPresenceChanged = (current.attributes.profilePhotoJPEG != nil) != (photo != nil)
                let identityChanged = current.attributes.initials != initials || current.attributes.courseName != courseName
                if replacePhoto || photoPresenceChanged || identityChanged {
                    await current.end(nil, dismissalPolicy: .immediate)
                    self.request(courseName: courseName, initials: initials, photo: photo, state: state)
                } else {
                    await current.update(.init(state: state, staleDate: nil))
                }
                return
            }
            self.request(courseName: courseName, initials: initials, photo: photo, state: state)
        }
    }

    func end() {
        enqueue {
            for activity in Activity<RoundLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func request(
        courseName: String,
        initials: String,
        photo: UIImage?,
        state: RoundLiveActivityAttributes.ContentState
    ) {
        let content = ActivityContent(state: state, staleDate: nil)
        let jpeg = photo.flatMap(ProfilePhotoStorage.activityThumbnail(from:))
        let attributes = RoundLiveActivityAttributes(
            courseName: courseName,
            initials: initials,
            profilePhotoJPEG: jpeg
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            guard jpeg != nil else {
                liveActivityLogger.error("Live Activity failed: \(error.localizedDescription)")
                return
            }
            let slim = RoundLiveActivityAttributes(
                courseName: courseName,
                initials: initials,
                profilePhotoJPEG: nil
            )
            do {
                _ = try Activity.request(attributes: slim, content: content, pushType: nil)
            } catch {
                liveActivityLogger.error("Live Activity failed: \(error.localizedDescription)")
            }
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }
}
