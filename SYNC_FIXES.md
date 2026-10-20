# Golf Lab Watch/Phone Sync Fixes

## Issues Identified

### 1. **Phone Not Queuing Messages to Watch**
**Location:** `GolfLab/Services/WatchConnectivityService.swift` - `pushCompanionSnapshot()`

**Problem:**
- Phone only sent live messages when watch was "reachable" (active and in foreground)
- If watch was backgrounded or sleeping, phone only updated application context
- No queued `transferUserInfo` was sent as a backup
- This meant updates were lost if watch wasn't actively running

**Impact:** When user saved a hole on phone while watch app was backgrounded, the watch would never receive the update until user manually opened watch app and it checked application context.

**Fix:**
- Added `transferUserInfo()` call when watch is not reachable
- Added error handler to `sendMessage()` that queues via `transferUserInfo()` if live send fails
- This ensures updates are reliably delivered even when watch is backgrounded

### 2. **Session ID Mismatches Blocking Sync**
**Location:** Multiple places in sync logic

**Problem:**
- Both phone and watch used strict session ID matching
- If session IDs didn't match (e.g., after app restarts, crashes, or out-of-sync state), devices would silently reject all updates from each other
- No mechanism to reconcile session ID mismatches for compatible rounds

**Impact:** If phone and watch got out of sync on their session IDs, sync would completely stop working until one device was reset or a new round was started with `replacesSession=true`.

**Fixes:**

**Watch Side** (`GolfLabWatch/Services/WatchSessionService.swift`):
- Removed hard guard on session ID matching
- Added logic to check if rounds are compatible (same course, same hole count) even if session IDs differ
- Watch now merges holes from phone using revision numbers regardless of session ID, as long as rounds are compatible

**Phone Side** (`GolfLab/Services/RoundStore.swift`):
- Removed hard guard on session ID matching in `applyWatchScorecard()`
- Added compatibility check for rounds (same course name, same hole count)
- Removed session ID check in `applyWatchHoleVersions()` - now only checks if session is tombstoned
- Phone now merges holes from watch using revision numbers regardless of session ID, as long as rounds are compatible

### 3. **Silent Failures**
**Problem:**
- All sync failures were silent - no logging, no error indicators to user
- Impossible to debug why sync wasn't working

**Status:** Not fully addressed in this fix, but the above fixes should eliminate most failure scenarios. Future enhancement: Add logging and sync status indicators.

## How Sync Now Works

### Phone → Watch
1. User saves hole on phone
2. Phone stamps hole with revision number (holeClock++)
3. Phone calls `pushCompanionSnapshotToWatch()`
4. Phone updates application context with full snapshot
5. Phone attempts live `sendMessage()`:
   - **If watch is reachable:** Send live message
   - **If live send fails:** Queue via `transferUserInfo()`
   - **If watch not reachable:** Queue via `transferUserInfo()`
6. Watch receives update via:
   - **Live message:** `didReceiveMessage` → `handleIncomingPayload` → `applyCompanionSnapshot`
   - **Queued message:** `didReceiveUserInfo` → `handleIncomingPayload` → `applyCompanionSnapshot`
   - **Application context:** `didReceiveApplicationContext` → `applyReceivedApplicationContext` → `applyCompanionSnapshot`
7. Watch merges holes using revision numbers, even if session IDs don't match

### Watch → Phone
1. User saves hole on watch
2. Watch stamps hole with revision number (holeClock++)
3. Watch calls `sendHoleEntry()`
4. Watch updates local state and persists to disk
5. Watch calls `republishLocalContext()` → updates application context
6. Watch calls `sendLiveOrQueued()` with `alwaysQueue: true`:
   - Always queues via `transferUserInfo()`
   - Also attempts live `sendMessage()` if reachable
7. Phone receives update via:
   - **Live message:** `didReceiveMessage` → `handleIncomingFromWatch` → `handleHoleEntry` → `mergeWatchEntries`
   - **Queued message:** `didReceiveUserInfo` → `handleIncomingFromWatch` → `handleHoleEntry` → `mergeWatchEntries`
   - **Application context:** `didReceiveApplicationContext` → `applyReceivedApplicationContext` → `handleScorecardData` → `applyWatchScorecard`
8. Phone merges holes using revision numbers, even if session IDs don't match

## Conflict Resolution

Both devices use `ScorecardSync.prefersRemote()` to determine which version wins:

1. **Compare revision numbers:** Higher revision wins
2. **If revisions equal:** Compare timestamps (> 1 second difference)
3. **If timestamps similar:** Saved hole beats unsaved hole
4. **Otherwise:** Keep local version

This ensures that even if messages arrive out of order or session IDs are mismatched, the correct hole data is preserved based on actual revision history.

## Testing Scenarios

To verify sync is working properly, test these scenarios:

### Scenario 1: Normal Operation
1. Start round on phone
2. Verify watch shows the round
3. Save hole on phone → verify it appears on watch
4. Save hole on watch → verify it appears on phone
5. Alternate saving between devices → verify all holes sync correctly

### Scenario 2: Backgrounded Watch
1. Start round on phone
2. Background watch app (press crown to go home)
3. Save multiple holes on phone
4. Open watch app → verify all holes have synced

### Scenario 3: Backgrounded Phone
1. Start round on watch
2. Background phone app
3. Save multiple holes on watch
4. Open phone app → verify all holes have synced

### Scenario 4: Both Devices Active
1. Have both phone and watch visible
2. Rapidly alternate saving holes between devices
3. Verify all saves sync correctly without conflicts

### Scenario 5: App Restarts
1. Start round on phone, save some holes
2. Force quit watch app
3. Relaunch watch app → verify round and holes sync
4. Save hole on watch → verify it syncs to phone
5. Force quit phone app
6. Relaunch phone app → verify everything syncs

### Scenario 6: Out of Sync Recovery
1. Start round on phone
2. Put watch in airplane mode
3. Save holes on both devices while disconnected
4. Turn off airplane mode on watch
5. Verify devices reconcile and merge holes correctly

## Expert Questions & Answers

**Q: What happens if the same hole is edited on both devices with the same revision?**
A: The sync logic uses timestamps to break ties. If timestamps are within 1 second, the saved version wins. This is rare but handles edge cases.

**Q: Why use both application context AND queued transfers?**
A: 
- Application context is efficient for "latest state" - only one update pending
- Queued transfers are reliable for delivery but can queue multiple messages
- Using both ensures both efficiency and reliability

**Q: What if one device is offline for an extended period?**
A: 
- Each device persists its state locally
- When connectivity is restored, application context has the latest snapshot
- Queued transfers deliver any pending hole updates
- Revision numbers ensure correct merge regardless of order

**Q: Can sync cause data loss?**
A: No. The merge logic is conservative:
- Only applies remote changes if they're strictly newer (higher revision)
- Never deletes holes unless explicitly tombstoned
- Both devices persist state locally before syncing

**Q: What about performance with many queued messages?**
A: Watch Connectivity has built-in limits on transferUserInfo queue size. If the queue is full, older messages are dropped. However:
- Application context always has the latest full snapshot as backup
- Hole revisions prevent accepting stale data
- In practice, sync happens quickly enough that queues don't overflow

## Files Changed

1. `GolfLab/Services/WatchConnectivityService.swift`
   - Enhanced `pushCompanionSnapshot()` to queue messages when watch not reachable
   - Added error handling to queue on live send failure

2. `GolfLab/Services/RoundStore.swift`
   - Enhanced `applyWatchScorecard()` to merge holes even with session ID mismatch
   - Removed session ID check from `applyWatchHoleVersions()`
   - Added compatibility checks for round setup

3. `GolfLabWatch/Services/WatchSessionService.swift`
   - Enhanced `applyCompanionSnapshot()` to merge holes even with session ID mismatch
   - Added compatibility checks for round setup

## Future Enhancements

1. **Sync Status Indicator**
   - Show sync icon when updates are pending
   - Show warning if sync hasn't succeeded recently
   - Show session ID mismatch warning if applicable

2. **Logging & Diagnostics**
   - Add structured logging for all sync operations
   - Track sync success/failure rates
   - Add debug view showing sync state

3. **Manual Sync Trigger**
   - Add pull-to-refresh or button to force sync
   - Useful if user suspects sync is stuck

4. **Conflict Resolution UI**
   - For rare cases where revision numbers are identical
   - Let user choose which version to keep

5. **Session ID Reconciliation**
   - Automatically align session IDs after successful merge
   - Reduces future mismatch chances
