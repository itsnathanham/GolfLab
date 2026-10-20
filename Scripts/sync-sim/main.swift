import Foundation

// Two-device model of the scorecard sync rules, built on the real Shared/ScorecardSync.swift.
// Run: swiftc Shared/ScorecardSync.swift Scripts/sync-sim/main.swift -o /tmp/sync-sim && /tmp/sync-sim

enum Variant: String, CaseIterable {
    /// Before any of the recent changes: cursor was never applied from a snapshot.
    case original
    /// Current main: every received snapshot overwrites the cursor; echo replies suppressed when cursor changed.
    case unconditionalCursor
    /// Proposed: cursor only moves when a hole version actually wins the merge.
    case derivedCursor
}

struct Snapshot {
    var holes: [HoleVersion]
    var cursor: Int
}

struct Device {
    let holeNumbers = [1, 2, 3, 4, 5, 6]
    var holes: [Int: HoleVersion] = [:]
    var cursor = 0
    var clock: UInt64 = 0
    var date = Date(timeIntervalSince1970: 1_000_000)

    var snapshot: Snapshot { Snapshot(holes: holes.values.sorted { $0.holeNumber < $1.holeNumber }, cursor: cursor) }

    mutating func save(holeNumber: Int) {
        clock += 1
        date += 10
        holes[holeNumber] = HoleVersion(holeNumber: holeNumber, isSaved: true, revision: clock, editedAt: date)
        let idx = holeNumbers.firstIndex(of: holeNumber)!
        cursor = min(idx + 1, holeNumbers.count - 1)
    }

    /// Returns a snapshot to publish back when this device holds progress the sender lacks.
    mutating func receive(_ s: Snapshot, variant: Variant) -> Snapshot? {
        var changed = false
        for remote in s.holes {
            clock = max(clock, remote.revision)
            if let local = holes[remote.holeNumber] {
                if ScorecardSync.prefersRemote(local: local, remote: remote) {
                    holes[remote.holeNumber] = remote
                    changed = true
                }
            } else {
                holes[remote.holeNumber] = remote
                changed = true
            }
        }
        var cursorChanged = false
        switch variant {
        case .original:
            break
        case .unconditionalCursor:
            cursorChanged = cursor != s.cursor
            cursor = s.cursor
        case .derivedCursor:
            if changed, let next = ScorecardSync.nextIndexAfterNewestSave(saved: Array(holes.values), holeNumbers: holeNumbers) {
                cursor = next
            }
        }
        let suppress = variant == .unconditionalCursor && cursorChanged
        if !suppress, ScorecardSync.localHasProgressRemoteLacks(local: Array(holes.values), remote: s.holes) {
            return snapshot
        }
        return nil
    }
}

struct World {
    var phone = Device()
    var watch = Device()
    var variant: Variant

    mutating func deliver(_ s: Snapshot, toPhone: Bool) {
        var queue: [(Snapshot, Bool)] = [(s, toPhone)]
        var steps = 0
        while !queue.isEmpty, steps < 50 {
            steps += 1
            let (snap, toPhone) = queue.removeFirst()
            let reply = toPhone ? phone.receive(snap, variant: variant) : watch.receive(snap, variant: variant)
            if let reply { queue.append((reply, !toPhone)) }
        }
    }
}

func scenarioStaleForeground(_ variant: Variant) -> (phone: Int, watch: Int) {
    var w = World(variant: variant)
    w.phone.save(holeNumber: 1)
    let s1 = w.phone.snapshot
    let staleWatch = w.watch.snapshot
    w.deliver(staleWatch, toPhone: true)
    w.deliver(s1, toPhone: false)
    return (w.phone.cursor, w.watch.cursor)
}

func scenarioWatchSaveThenStaleReplay(_ variant: Variant) -> (phone: Int, watch: Int) {
    var w = World(variant: variant)
    w.phone.save(holeNumber: 1)
    w.deliver(w.phone.snapshot, toPhone: false)
    let oldPhoneSnapshot = w.phone.snapshot
    w.watch.save(holeNumber: 2)
    w.deliver(w.watch.snapshot, toPhone: true)
    w.deliver(oldPhoneSnapshot, toPhone: false)
    w.deliver(w.watch.snapshot, toPhone: true)
    return (w.phone.cursor, w.watch.cursor)
}

func fuzz(_ variant: Variant, trials: Int) -> (failures: Int, example: String) {
    var rng = SystemRandomNumberGenerator()
    var failures = 0
    var example = ""
    for _ in 0..<trials {
        var w = World(variant: variant)
        var history: [Snapshot] = []
        var expected = 0
        var log: [String] = []
        for _ in 0..<Int.random(in: 1...5, using: &rng) {
            let onPhone = Bool.random(using: &rng)
            let next = (w.phone.holes.keys.max() ?? 0).advanced(by: 1)
            guard next <= 6 else { break }
            if onPhone { w.phone.save(holeNumber: next) } else { w.watch.save(holeNumber: next) }
            expected = min(next, 5)
            log.append("\(onPhone ? "phone" : "watch") saves \(next)")
            let snap = onPhone ? w.phone.snapshot : w.watch.snapshot
            history.append(snap)
            w.deliver(snap, toPhone: !onPhone)
            // Noise: stale replays and foreground republishes from either side, in any order.
            for _ in 0..<Int.random(in: 0...3, using: &rng) {
                let toPhone = Bool.random(using: &rng)
                if Bool.random(using: &rng), let old = history.randomElement(using: &rng) {
                    w.deliver(old, toPhone: toPhone)
                    log.append("replay old -> \(toPhone ? "phone" : "watch")")
                } else {
                    w.deliver(toPhone ? w.watch.snapshot : w.phone.snapshot, toPhone: toPhone)
                    log.append("republish -> \(toPhone ? "phone" : "watch")")
                }
            }
        }
        if w.phone.cursor != expected || w.watch.cursor != expected {
            failures += 1
            if example.isEmpty {
                example = "\(log.joined(separator: "; ")) => phone=\(w.phone.cursor) watch=\(w.watch.cursor) expected=\(expected)"
            }
        }
    }
    return (failures, example)
}

func walkthroughEditEarlierHole(savedHole3On: String) {
    var w = World(variant: .derivedCursor)
    func show(_ step: String) {
        print("  \(step.padding(toLength: 52, withPad: " ", startingAt: 0)) phone: hole \(w.phone.cursor + 1)   watch: hole \(w.watch.cursor + 1)")
    }
    for n in 1...2 {
        w.phone.save(holeNumber: n)
        w.deliver(w.phone.snapshot, toPhone: false)
    }
    show("holes 1-2 saved")
    if savedHole3On == "phone" {
        w.phone.save(holeNumber: 3)
        w.deliver(w.phone.snapshot, toPhone: false)
    } else {
        w.watch.save(holeNumber: 3)
        w.deliver(w.watch.snapshot, toPhone: true)
    }
    show("hole 3 saved on \(savedHole3On)")
    w.phone.cursor = 1
    w.deliver(w.phone.snapshot, toPhone: false)
    show("phone navigates back to hole 2 (view only)")
    w.phone.save(holeNumber: 2)
    w.deliver(w.phone.snapshot, toPhone: false)
    show("phone saves edited hole 2")
}

print("\nEdit an earlier hole (derived cursor)")
for device in ["phone", "watch"] {
    print(" Case: hole 3 saved on \(device)")
    walkthroughEditEarlierHole(savedHole3On: device)
}
print()

var anyFailure = false
print("Cursor index shown after saving hole 1 (0 = still on hole 1, 1 = hole 2 is correct)\n")
for v in Variant.allCases {
    let a = scenarioStaleForeground(v)
    let b = scenarioWatchSaveThenStaleReplay(v)
    print("[\(v.rawValue)]")
    print("  phone saves 1, watch foregrounds with stale card: phone=\(a.phone) watch=\(a.watch) \(a.phone == 1 && a.watch == 1 ? "OK" : "WRONG")")
    print("  watch saves 2, late stale phone snapshot arrives: phone=\(b.phone) watch=\(b.watch) \(b.phone == 2 && b.watch == 2 ? "OK" : "WRONG")")
    let f = fuzz(v, trials: 20000)
    print("  fuzz 20000 runs with stale replays/republishes: \(f.failures) wrong")
    if !f.example.isEmpty { print("    e.g. \(f.example)") }
    if v == .derivedCursor, a.phone != 1 || a.watch != 1 || b.phone != 2 || b.watch != 2 || f.failures > 0 { anyFailure = true }
}
exit(anyFailure ? 1 : 0)
