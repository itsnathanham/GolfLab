# Watch Complication Background Issue - Debug Guide

## Status
The code **IS CORRECT** - background is set to green in `ActiveRoundComplicationWidget.swift`:

```swift
static let iconGreen = Color(red: 8 / 255, green: 86 / 255, blue: 46 / 255)
.containerBackground(Self.iconGreen, for: .widget)
```

But it's not showing green on the physical watch.

## Most Likely Causes

### 1. Widget Extension Not Deploying
The WatchKit Extension (which contains the widget) might not be rebuilding/deploying.

**Fix:**
```bash
# In Xcode:
1. Select "GolfLabWatch" scheme
2. Product → Clean Build Folder (Cmd+Shift+K)
3. Select the watch device/simulator
4. Build and run specifically the watch app target
```

### 2. Cached Widget Timeline
watchOS caches widget content aggressively and doesn't always refresh on rebuild.

**Fix:**
```bash
# On the watch:
1. Remove the complication from watch face
2. Restart the watch (hold side button → Power Off)
3. Rebuild and deploy from Xcode
4. Add complication back to watch face
```

### 3. Widget Kind Changed / Not Refreshing
The widget kind is `"ActiveRoundComplication"` - if this changed or isn't reloading properly.

**Fix - Force widget reload in code (temporary debug):**
Add to `WatchConnectivityService` or watch app init:
```swift
import WidgetKit

// Force reload on app launch
WidgetCenter.shared.reloadAllTimelines()
```

### 4. Color Space / Rendering Issue
The color might render differently on device vs simulator.

**Test:**
Try a more obvious color temporarily:
```swift
static let iconGreen = Color.red  // If this shows, it's a color rendering issue
```

### 5. Wrong Widget Bundle Being Used
Check if there are multiple widget targets or if the bundle ID is wrong.

**Verify in Xcode:**
- GolfLabWatchComplications target
- Check Bundle Identifier matches expected
- Check "Supported Platforms" includes watchOS
- Check deployment target matches your watch OS version

## Verification Steps

1. **Check if widget is actually running your code:**
   - Add a print statement in `ActiveRoundComplicationProvider.getTimeline`
   - Check Xcode console when widget refreshes

2. **Verify widget shows on watch face:**
   - Long press watch face → Edit → Complications
   - Look for "GolfLab" or "Current Hole"
   - Is it listed? Does it show content (hole number or icon)?

3. **Check scheme settings:**
   - In Xcode: Product → Scheme → Edit Scheme
   - Under "Run" → Info, make sure GolfLabWatch.app is selected
   - Under "Build", ensure GolfLabWatchComplications is checked

## Nuclear Option

If nothing works:

```bash
1. Delete app from watch completely
2. Clean derived data: rm -rf ~/Library/Developer/Xcode/DerivedData/*
3. Clean build folder in Xcode
4. Rebuild and redeploy
5. Add complication fresh
```

## Code Locations

- Widget definition: `GolfLabWatchComplications/ActiveRoundComplicationWidget.swift`
- Widget store: `Shared/WatchComplicationStore.swift`
- Widget kind: `"ActiveRoundComplication"`
- Background color: Line 46 of `ActiveRoundComplicationWidget.swift`

## Expected Behavior

The complication background should be dark green: `rgb(8, 86, 46)`

The icon/text should be white.

## Current Behavior Reported

Background is **not green** on physical watch, despite code being correct.
App icon IS correct (green background).
