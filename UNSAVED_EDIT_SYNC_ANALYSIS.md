# Unsaved Edit Sync Behavior Analysis

## Executive Summary

**CRITICAL FINDINGS:**
1. **Watch unsaved edits are preserved** - Form ignores incoming syncs while dirty
2. **Phone unsaved score/putts can be lost** - Form @State gets out of sync with store  
3. **Phone unsaved GIR/FIR/penalty are persisted** but not synced until save
4. **Revision increments ONLY on save**, not on unsaved edits
5. **"Saved beats unsaved" is 3rd tiebreaker** after revision and timestamp

## Question 1: Do unsaved watch edits trigger WatchConnectivity sends?

**Answer: NO - Nothing leaves the watch until save.**

### Code Path:

**File:** `GolfLabWatch/Views/WatchHoleEntryView.swift`

```swift
// Lines 62-66: onChange handlers
.onChange(of: score) { _, _ in markFormDirty() }
.onChange(of: putts) { _, _ in markFormDirty() }
.onChange(of: gir) { _, _ in markFormDirty() }
.onChange(of: fir) { _, _ in markFormDirty() }
.onChange(of: penalty) { _, _ in markFormDirty() }
```

```swift
// Lines 178-181: markFormDirty implementation
private func markFormDirty() {
    if !suppressDirty {
        formDirty = true  // ← ONLY sets a flag
    }
}
```

**Behavior:**
- Stepper/toggle changes set `formDirty = true`
- NO call to `session.sendHoleEntry()`
- NO update to `session.holeEntries` array
- NO WatchConnectivity message sent
- Changes exist ONLY in form's `@State` variables

### Contrast: Phone unsaved edits DO persist (but don't sync)

**File:** `GolfLab/Views/Round/HoleEntryView.swift`

```swift
// Lines 492-501: onChange handlers for score/putts
.onChange(of: score) { _, newValue in
    if commitInPlace {
        roundStore.patchActiveHole(holeNumber: holeNumber) { $0.score = newValue }
    }
}
.onChange(of: putts) { _, newValue in
    if commitInPlace {
        roundStore.patchActiveHole(holeNumber: holeNumber) { $0.putts = newValue }
    }
}
```

```swift
// Lines 388, 403, 418: Bindings for GIR/FIR/penalty
set: { newValue in
    gir = newValue
    if liveActiveHole != nil {
        roundStore.patchActiveHole(holeNumber: holeNumber) { $0.gir = newValue }
    }
}
```

**File:** `GolfLab/Services/RoundStore.swift`

```swift
// Lines 298-303: patchActiveHole implementation
func patchActiveHole(holeNumber: Int, _ patch: (inout ActiveHole) -> Void) {
    guard var round = activeRound,
          let idx = round.holes.firstIndex(where: { $0.holeNumber == holeNumber }) else { return }
    patch(&round.holes[idx])
    activeRound = round
    persistActiveRoundDraft()  // ← Persists to disk
    // ← NOTE: Does NOT call pushCompanionSnapshotToWatch()!
}
```

**Behavior:**
- Score/putts/GIR/FIR/penalty changes call `patchActiveHole()`
- Updates the hole in `activeRound.holes`
- Persists to local draft file via `persistActiveRoundDraft()`
- Does NOT increment revision
- Does NOT change `isSaved` flag
- Does NOT sync to watch

## Question 2: Phone saves while watch has unsaved edits - what happens?

**Scenario:**
1. Start round on phone
2. Switch to watch, change score from 4→5 (DON'T save)
3. Switch to phone, save hole with score=4

### Code Path:

**Watch receives phone's save:**

```swift
// WatchSessionService.swift, lines 76-105
func applyCompanionSnapshot(_ snapshot: WatchCompanionSnapshot) {
    // ... validation checks ...
    
    let remoteVersions = snapshot.state.savedEntries.map(\.version)
    mergeSavedEntries(snapshot.state.savedEntries)  // ← Merges into storage
    syncGeneration += 1  // ← Triggers form onChange
    // ...
}
```

```swift
// WatchSessionService.swift, lines 178-190
private func mergeSavedEntries(_ remote: [WatchHoleEntry]) {
    for entry in remote {
        holeClock = max(holeClock, entry.revision)
        if let index = holeEntries.firstIndex(where: { $0.holeNumber == entry.holeNumber }) {
            if ScorecardSync.prefersRemote(local: holeEntries[index].version, remote: entry.version) {
                holeEntries[index] = entry  // ← Storage updated to phone's values
            }
        } else {
            holeEntries.append(entry)
        }
    }
    holeEntries.sort { $0.holeNumber < $1.holeNumber }
}
```

**Watch form reacts to sync:**

```swift
// WatchHoleEntryView.swift, lines 58-61
.onChange(of: session.syncGeneration) { _, _ in
    guard !formDirty else { return }  // ← KEY: Blocks reload if form is dirty!
    loadFormFromSavedHole()
}
```

### Conflict Resolution:

**Initial state (watch):**
- holeEntries[0]: `revision=0, isSaved=false, editedAt=distantPast, score=4`
- Form @State: `score=5, formDirty=true`

**Phone sends:**
- `revision=1, isSaved=true, editedAt=now, score=4`

**ScorecardSync.prefersRemote comparison:**
```swift
// Line 15: remote.revision (1) != local.revision (0)
// Line 15: return remote.revision (1) > local.revision (0)  → TRUE
```

**Result:**
- ✅ Watch storage (`holeEntries[0]`) updated: `score=4, revision=1, isSaved=true`
- ✅ Watch form still shows: `score=5` (because `formDirty=true` blocked reload)
- ✅ **User's unsaved edit preserved in UI**

**What happens when user saves?**

```swift
// WatchHoleEntryView.swift, lines 214-228
private func saveHole() {
    // Creates entry with current form values
    let entry = WatchHoleEntry(
        holeNumber: setupHole.holeNumber,
        par: setupHole.par,
        score: score,  // ← Uses form @State (5)
        putts: putts,
        gir: gir,
        fir: setupHole.par > 3 ? fir : nil,
        penalty: penalty
    )
    session.sendHoleEntry(entry)
    // ...
}
```

```swift
// WatchSessionService.swift, lines 97-120
func sendHoleEntry(_ entry: WatchHoleEntry) {
    guard let sessionId = appliedSessionId else { return }
    holeClock += 1  // ← Was 1, now becomes 2
    let stamped = WatchHoleEntry(
        sessionId: sessionId,
        holeNumber: entry.holeNumber,
        par: entry.par,
        score: entry.score,  // ← score=5 from form
        putts: entry.putts,
        gir: entry.gir,
        fir: entry.fir,
        penalty: entry.penalty,
        revision: holeClock,  // ← revision=2
        editedAt: Date()
    )
    // ... send to phone ...
}
```

**Final outcome:**
- Watch sends: `score=5, revision=2, isSaved=true`
- Phone has: `score=4, revision=1, isSaved=true`
- Phone's merge: `revision 2 > 1` → **Watch wins**
- ✅ **User's unsaved edit (score=5) is preserved and syncs to phone**

### End-User-Visible Outcome:

**✅ WORKS CORRECTLY**
- User's unsaved watch edits are preserved
- When they save, their edits win (higher revision)
- Phone receives and applies the watch's version

## Question 3: Watch saves while phone has unsaved edits - what happens?

**Scenario:**
1. Start round on watch  
2. Switch to phone, change score from 4→5 (DON'T save)
3. Switch to watch, save hole with score=4

### Code Path:

**Phone receives watch's save:**

```swift
// WatchConnectivityService.swift, line 99
private func handleHoleEntry(from dict: [String: Any]) {
    guard let entry = WatchHoleEntry.from(dictionary: dict) else { return }
    // ... updates receivedHoleEntries array ...
    roundStore?.mergeWatchEntries([entry])
}
```

```swift
// RoundStore.swift, lines 307-315
func mergeWatchEntries(_ entries: [WatchHoleEntry]) {
    let versions = entries.map(\.version)
    guard applyWatchHoleVersions(entries) else {
        replyIfWatchIsBehind(remote: versions)
        return
    }
    replyIfWatchIsBehind(remote: versions)
}
```

```swift
// RoundStore.swift, lines 354-380
private func applyWatchHoleVersions(_ entries: [WatchHoleEntry]) -> Bool {
    guard var round = activeRound else { return false }
    var changed = false
    for entry in entries {
        // ... validation ...
        guard let index = round.holes.firstIndex(where: { $0.holeNumber == entry.holeNumber }) else { continue }
        let remote = entry.version
        guard ScorecardSync.prefersRemote(local: round.holes[index].version, remote: remote) else { continue }
        
        // ← KEY: Updates the STORE, not the form!
        round.holes[index].score = entry.score
        round.holes[index].putts = entry.putts
        round.holes[index].gir = entry.gir
        round.holes[index].fir = entry.fir
        round.holes[index].penalty = entry.penalty ?? false
        round.holes[index].isSaved = true
        round.holes[index].revision = entry.revision
        round.holes[index].editedAt = entry.editedAt
        noteRemoteRevision(entry.revision)
        changed = true
    }
    if changed {
        activeRound = round
        persistActiveRoundDraft()  // ← Persists to disk
    }
    return changed
}
```

**Phone form does NOT react:**

```swift
// HoleEntryView.swift, lines 361-373
init(hole: ActiveHole, commitInPlace: Bool = false, onSave: @escaping (ActiveHole) -> Void) {
    // ... 
    _score = State(initialValue: hole.score)  // ← Initialized ONCE at creation
    _putts = State(initialValue: hole.putts)
    // ...
}
```

The form has `.id(hole.holeNumber)` (line 54), so it only reinitializes when hole NUMBER changes, not when hole DATA changes.

**Bindings:**
```swift
// Lines 379-422: GIR/FIR/penalty use computed bindings
private var girBinding: Binding<Bool> {
    Binding(
        get: {
            if let live = liveActiveHole { return live.gir }  // ← Reads from store
            return gir
        },
        set: { newValue in
            gir = newValue
            if liveActiveHole != nil {
                roundStore.patchActiveHole(holeNumber: holeNumber) { $0.gir = newValue }
            }
        }
    )
}
```

But score/putts are plain @State, NOT computed bindings!

### Conflict Resolution:

**Initial state (phone):**
- Store: `revision=0, isSaved=false, editedAt=distantPast, score=4`
- After user's unsaved edit via patchActiveHole: `revision=0, isSaved=false, editedAt=distantPast, score=5`
- Form @State: `score=5`

**Watch sends:**
- `revision=1, isSaved=true, editedAt=now, score=4`

**ScorecardSync.prefersRemote comparison:**
```swift
// Line 15: remote.revision (1) != local.revision (0)
// Line 15: return remote.revision (1) > local.revision (0)  → TRUE
```

**Result:**
- ✅ Phone storage (`activeRound.holes[0]`) updated: `score=4, revision=1, isSaved=true`
- ⚠️ Phone form still shows: `score=5` (form @State not updated!)
- ⚠️ **UI shows stale unsaved value while storage has watch's saved value**

**What happens when user changes score again?**

```swift
// HoleEntryView.swift, lines 492-496
.onChange(of: score) { _, newValue in
    if commitInPlace {
        roundStore.patchActiveHole(holeNumber: holeNumber) { $0.score = newValue }
    }
}
```

User changes score from 5→6:
- `patchActiveHole()` updates store: `score=6`
- Does NOT change `revision` (still 1)
- Does NOT change `isSaved` (still true!)
- Does NOT change `editedAt`
- **Store now has: `score=6, revision=1, isSaved=true`** ← Inconsistent state!

**What happens when user saves?**

```swift
// HoleEntryView.swift, lines 475-489
GLPrimaryCTAButton(title: "Save hole →") {
    if commitInPlace {
        roundStore.commitInProgressHoleSave(
            holeNumber: holeNumber,
            par: par,
            score: score,  // ← Uses form @State (6)
            putts: putts,
            gir: persistedGir,
            fir: par > 3 ? persistedFairwayHit : nil,
            penalty: persistedPenalty
        )
        // ...
    }
}
```

```swift
// RoundStore.swift, lines 276-287
func commitInProgressHoleSave(...) {
    guard var round = activeRound,
          let idx = round.holes.firstIndex(where: { $0.holeNumber == holeNumber }) else { return }
    round.holes[idx].score = score  // ← score=6
    round.holes[idx].putts = putts
    round.holes[idx].gir = gir
    round.holes[idx].fir = par > 3 ? fir : nil
    round.holes[idx].penalty = penalty
    stampSaved(&round.holes[idx])  // ← Increments revision to 2
    activeRound = round
    pushCompanionSnapshotToWatch()
}
```

**Final outcome:**
- Phone sends: `score=6, revision=2, isSaved=true`
- Watch has: `score=4, revision=1, isSaved=true`
- Watch's merge: `revision 2 > 1` → **Phone wins**
- ✅ **User's edit (score=6) eventually syncs to watch**

### End-User-Visible Outcome:

**⚠️ WORKS BUT CONFUSING**
- User changes score on phone (5) - shows in UI
- Watch saves (score=4) - phone storage updates but UI still shows 5
- User can't tell their edit was overwritten until they:
  - Navigate away (form reinitializes from store, shows 4)
  - OR make another change (shows their new value)
  - OR save (their current @State value wins with higher revision)

**Potential data loss scenario:**
- User edits score to 5 on phone (unsaved)
- Watch saves score as 4
- User navigates away without saving
- Form reinitializes from store → shows 4
- **User's edit (5) is silently lost**

## Question 4: Does unsaved edit increment revision?

**Answer: NO - Only save increments revision.**

### Watch:

```swift
// WatchSessionService.swift, lines 97-111
func sendHoleEntry(_ entry: WatchHoleEntry) {
    guard let sessionId = appliedSessionId else { return }
    holeClock += 1  // ← Incremented ONLY when sendHoleEntry is called
    let stamped = WatchHoleEntry(
        sessionId: sessionId,
        holeNumber: entry.holeNumber,
        par: entry.par,
        score: entry.score,
        putts: entry.putts,
        gir: entry.gir,
        fir: entry.fir,
        penalty: entry.penalty,
        revision: holeClock,  // ← Uses incremented clock
        editedAt: Date()
    )
    // ...
}
```

`sendHoleEntry()` is called ONLY from `saveHole()` in WatchHoleEntryView. Unsaved edits don't call it.

### Phone:

```swift
// RoundStore.swift, lines 218-223
private func stampSaved(_ hole: inout ActiveHole) {
    holeClock += 1  // ← Incremented ONLY when stampSaved is called
    hole.revision = holeClock
    hole.editedAt = Date()
    hole.isSaved = true
}
```

`stampSaved()` is called ONLY from:
- `saveHole()` (line 242)
- `saveCurrentScorecardHoleMergingAdvance()` (line 260)
- `commitInProgressHoleSave()` (line 284)
- `persistUnsavedCurrentHoleIfEligible()` (line 447)

All of these are save operations. `patchActiveHole()` (used for unsaved edits) does NOT call `stampSaved()`.

### Initial Hole State:

```swift
// RoundStore.swift, lines 856-870
init(holeNumber: Int, par: Int, yardage: Int? = nil, strokeIndex: Int? = nil) {
    self.holeNumber  = holeNumber
    self.par         = par
    self.yardage     = yardage
    self.strokeIndex = strokeIndex
    self.score       = par
    self.putts       = 2
    self.gir         = false
    self.fir         = par > 3 ? false : nil
    self.penalty     = false
    self.isSaved     = false
    self.revision    = 0  // ← Starts at 0
    self.editedAt    = .distantPast
}
```

**Revision timeline:**
- New hole: `revision=0`
- Unsaved edits: `revision=0` (unchanged)
- First save: `revision=1` (holeClock incremented)
- More unsaved edits: `revision=1` (unchanged)
- Save again: `revision=2` (holoClock incremented)

## Question 5: When does "saved beats unsaved" tiebreaker apply?

**Answer: Only when revisions are equal AND timestamps are within 1 second.**

### Code Path:

```swift
// ScorecardSync.swift, lines 14-20
static func prefersRemote(local: HoleVersion, remote: HoleVersion) -> Bool {
    // 1st: Compare revisions
    if remote.revision != local.revision { 
        return remote.revision > local.revision 
    }
    
    // 2nd: Compare timestamps (if difference > 1 second)
    let delta = remote.editedAt.timeIntervalSince(local.editedAt)
    if abs(delta) > 1 { 
        return delta > 0 
    }
    
    // 3rd: Compare saved status
    if remote.isSaved != local.isSaved { 
        return remote.isSaved  // ← "saved beats unsaved"
    }
    
    // Default: keep local
    return false
}
```

### Tiebreaker Hierarchy:

1. **Revision number** (UInt64): Higher wins
2. **Timestamp** (Date): If timestamps differ by >1 second, newer wins
3. **Saved status** (Bool): Saved beats unsaved
4. **Default**: Keep local (remote loses)

### When "Saved Beats Unsaved" Applies:

**Scenario A: Same revision, similar timestamps**
- Local: `revision=1, editedAt=10:00:00.500, isSaved=false`
- Remote: `revision=1, editedAt=10:00:00.800, isSaved=true`
- Timestamp delta: 0.3 seconds (< 1 second)
- Result: **Remote wins** (saved beats unsaved)

**Scenario B: Same revision, different timestamps**
- Local: `revision=1, editedAt=10:00:00, isSaved=false`
- Remote: `revision=1, editedAt=10:00:02, isSaved=true`
- Timestamp delta: 2 seconds (> 1 second)
- Result: **Remote wins** (newer timestamp, saved status not checked)

**Scenario C: Different revisions**
- Local: `revision=1, editedAt=10:00:02, isSaved=true`
- Remote: `revision=2, editedAt=10:00:00, isSaved=false`
- Result: **Remote wins** (higher revision, timestamp/saved not checked)

### Real-World Scenario:

Given that unsaved edits don't increment revision, the "saved beats unsaved" tiebreaker would apply if:

1. Both devices save the same hole within ~1 second
2. Both get the same revision number (race condition)
3. One saves slightly before the other

This is extremely rare because:
- Saves increment the revision
- Each device increments its own holoClock
- The clocks sync by taking `max(local, remote.revision)`
- Simultaneous saves would give different revisions (e.g., phone gets 1, watch gets 2)

### When It Actually Matters:

The tiebreaker was likely added for **defensive programming** to handle:
- Clock sync issues
- Concurrent saves on same device (multiple UI states?)
- Edge cases in the revision numbering

In practice, it's the **3rd tier fallback** after revision and timestamp have already failed to determine a winner.

## Summary Table

| Scenario | Watch Storage | Watch UI | Phone Storage | Phone UI | Winner |
|----------|--------------|----------|---------------|----------|---------|
| **Watch unsaved, Phone saves** | Updated to phone's saved version | Preserves unsaved edits (formDirty blocks reload) | Phone's saved version | N/A | Phone's save overwrites storage, watch form preserves edits until save |
| **Phone unsaved, Watch saves** | Watch's saved version | N/A | Updated to watch's saved version | Shows stale unsaved value (form @State not updated) | Watch's save overwrites storage, phone form shows stale value |

## Critical Bugs Identified

### 1. Phone Form @State Gets Out of Sync with Store (MEDIUM severity)

**Bug:** When watch saves while phone has unsaved edits, phone's form @State (score/putts) stays at old values while the store is updated.

**Impact:**
- User sees incorrect values in UI
- Confusing UX - changes appear to "disappear" then reappear
- Potential data loss if user navigates away without saving

**Root Cause:** 
- Form uses @State for score/putts (initialized once)
- Form only reinitializes when hole NUMBER changes (`.id(hole.holeNumber)`)
- Store updates don't trigger form reinitialization

**Fix:** Use computed bindings for score/putts like GIR/FIR/penalty do:
```swift
private var scoreBinding: Binding<Int> {
    Binding(
        get: {
            if let live = liveActiveHole { return live.score }
            return score
        },
        set: { newValue in
            score = newValue
            if liveActiveHole != nil {
                roundStore.patchActiveHole(holeNumber: holeNumber) { $0.score = newValue }
            }
        }
    )
}
```

### 2. Phone patchActiveHole Doesn't Clear isSaved Flag (MEDIUM severity)

**Bug:** When user makes unsaved edits via patchActiveHole after a hole is saved, the hole is modified but `isSaved` stays `true`.

**Impact:**
- Store has inconsistent state: modified data with `isSaved=true`
- Violates invariant that saved holes are immutable until next save
- Could cause sync confusion if revision logic changed

**Root Cause:**
- `patchActiveHole()` only calls the patch closure, doesn't manage flags
- Callers (onChange handlers) only patch the specific field

**Fix:** Either:
- A) Clear `isSaved` flag in patchActiveHole if hole was previously saved
- B) Don't use patchActiveHole for unsaved edits, only for saved edits

### 3. Phone and Watch Have Different Unsaved Edit Models (LOW severity)

**Inconsistency:**
- Watch: Unsaved edits stay in @State, not persisted
- Phone: Unsaved edits persisted to draft via patchActiveHole

**Impact:**
- Confusing behavior - phone preserves unsaved edits across app restarts, watch doesn't
- Different mental models for developers
- Harder to reason about sync behavior

**Recommendation:** Make both platforms consistent - either both persist unsaved edits or neither does.

## Recommendations

### Short Term (High Priority)

1. **Fix phone form bindings** - Use computed bindings for score/putts to stay in sync with store
2. **Add unsaved indicator** - Show visual indicator when form has unsaved edits
3. **Clear isSaved on patch** - Clear the flag when patchActiveHole modifies a saved hole

### Medium Term

4. **Standardize unsaved model** - Make watch and phone consistent in how they handle unsaved edits
5. **Add "loading" state** - Show when sync is in progress so user knows to wait
6. **Improve tombstone handling** - Ensure rejected sessions are clearly communicated

### Long Term

7. **Add optimistic UI** - Show incoming changes with animation/indicator
8. **Sync status dashboard** - Let user see sync state and force sync if needed
9. **Conflict resolution UI** - For rare cases where timestamps/revisions tie, let user choose
