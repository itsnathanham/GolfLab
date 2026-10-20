import Foundation

/// Identity of one hole version. The whole scorecard is never versioned as a unit:
/// a newer snapshot revision must not delete holes that snapshot does not contain.
struct HoleVersion: Equatable {
    var holeNumber: Int
    var isSaved: Bool
    var revision: UInt64
    var editedAt: Date
}

enum ScorecardSync {
    /// Remote wins only when it is strictly newer. A saved hole beats an unsaved hole at the same revision.
    static func prefersRemote(local: HoleVersion, remote: HoleVersion) -> Bool {
        if remote.revision != local.revision { return remote.revision > local.revision }
        let delta = remote.editedAt.timeIntervalSince(local.editedAt)
        if abs(delta) > 1 { return delta > 0 }
        if remote.isSaved != local.isSaved { return remote.isSaved }
        return false
    }

    /// Union by hole number. Local holes the remote payload omits are kept.
    static func merge(local: [HoleVersion], remote: [HoleVersion]) -> [HoleVersion] {
        var byNumber: [Int: HoleVersion] = [:]
        var order: [Int] = []
        for hole in local {
            if byNumber[hole.holeNumber] == nil {
                order.append(hole.holeNumber)
            }
            byNumber[hole.holeNumber] = hole
        }
        for hole in remote {
            if let existing = byNumber[hole.holeNumber] {
                if prefersRemote(local: existing, remote: hole) {
                    byNumber[hole.holeNumber] = hole
                }
            } else {
                byNumber[hole.holeNumber] = hole
                order.append(hole.holeNumber)
            }
        }
        return order.compactMap { byNumber[$0] }
    }

    /// True when this device should publish its card so the other side can catch up.
    /// Absorbing the remote card without having anything newer does not publish, which stops echo loops.
    static func localHasProgressRemoteLacks(local: [HoleVersion], remote: [HoleVersion]) -> Bool {
        let remoteByNumber = Dictionary(remote.map { ($0.holeNumber, $0) }, uniquingKeysWith: { _, latest in latest })
        for hole in local where hole.isSaved {
            guard let other = remoteByNumber[hole.holeNumber] else { return true }
            if prefersRemote(local: other, remote: hole) { return true }
        }
        return false
    }

    /// The hole both devices should show after a save: the hole after the newest saved version, clamped to the last hole.
    /// Derived from hole data so a stale or replayed snapshot can never move it. Nil when nothing is saved.
    static func nextIndexAfterNewestSave(saved: [HoleVersion], holeNumbers: [Int]) -> Int? {
        let newest = saved.filter(\.isSaved).max { lhs, rhs in
            if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
            return lhs.editedAt < rhs.editedAt
        }
        guard let newest, let index = holeNumbers.firstIndex(of: newest.holeNumber) else { return nil }
        return min(index + 1, holeNumbers.count - 1)
    }

    /// Forward is allowed when the current hole is saved, or when a later hole is already saved.
    /// An unsaved gap must not hide holes that were logged after it.
    static func canReviewForward(currentIndex: Int, isSaved: [Bool]) -> Bool {
        guard currentIndex >= 0, currentIndex < isSaved.count - 1 else { return false }
        if isSaved[currentIndex] { return true }
        return isSaved[(currentIndex + 1)...].contains(true)
    }

    static func savedScore(scores: [Int], saved: [Bool]) -> Int {
        var total = 0
        for (score, isSaved) in zip(scores, saved) where isSaved {
            total += score
        }
        return total
    }
}
