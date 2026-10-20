# Golf Lab Watch/Phone Sync - Simple Save Approach

## Overview

Implementation of simple, reliable sync where **saves are the source of truth**:
- Unsaved edits stay local to the device
- When one device saves, it becomes the source of truth
- The save overwrites any unsaved edits on the other device
- Both devices advance to the next hole together

## Critical Bugs Fixed

### 1. **currentHoleIndex Wasn't Syncing** (CRITICAL)

**Problem:** When one device saved and advanced to the next hole, the other device stayed on the previous hole.

**Root Cause:** 
- Phone sent `currentHoleIndex` in snapshot but watch didn't apply it
- Watch sent `currentHoleIndex` in snapshot but phone didn't apply it

**Fix:**
- Watch now applies phone's `currentHoleIndex` in `applyCompanionSnapshot()`
- Phone now applies watch's `currentHoleIndex` in `applyWatchScorecard()`

### 2. **Watch Preserved Unsaved Edits** 

**Problem:** Watch had `formDirty` check that blocked incoming syncs when user had unsaved edits.

**Fix:** Removed `guard !formDirty else { return }` check - saves now overwrite unsaved edits

### 3. **Phone Not Queuing Messages**

**Problem:** Phone only sent live messages if watch was reachable. Updates lost when watch backgrounded.

**Fix:** Phone now queues messages via `transferUserInfo` as backup

### 4. **Session ID Mismatches Blocked Sync**

**Problem:** Strict session ID matching rejected updates after app restarts.

**Fix:** Devices merge based on revision numbers if rounds are compatible (same course, hole count)

## How It Works

### Core Principle: Save = Sync + Advance

1. **Unsaved edits stay local** - No network traffic until save
2. **Save triggers sync** - Saved hole immediately syncs to other device
3. **Save overwrites unsaved** - Other device's unsaved edits replaced
4. **Both advance together** - Both move to next hole

### Example Flow

```
Watch: User adjusts score to 5 (unsaved)
Phone: User enters score=4, saves
Result: 
  - Watch's unsaved 5 overwritten by phone's 4
  - Both devices advance to hole 2
  - ✅ In sync
```

## Files Modified

1. `GolfLab/Services/WatchConnectivityService.swift` - Added message queuing
2. `GolfLab/Services/RoundStore.swift` - Added currentHoleIndex sync, compatibility checks
3. `GolfLabWatch/Services/WatchSessionService.swift` - Added currentHoleIndex sync, compatibility checks
4. `GolfLabWatch/Views/WatchHoleEntryView.swift` - Removed formDirty protection

## Testing Scenarios

✅ Save on phone → watch updates and advances
✅ Save on watch → phone updates and advances  
✅ Force quit + reopen → both restore and sync
✅ Unsaved edit → other device saves → edit overwritten
✅ Session ID mismatch → compatible rounds still merge

## Design Decision

**Accepted tradeoff:** Unsaved edits can be lost if other device saves. This is acceptable because:
- Users typically save after each hole
- Rarely switch devices without saving
- Simplicity > protecting rare edge case
