# Live Activities & Profile Photo Setup Guide

## What Was Implemented

### ✅ Profile Photo Feature
- **Circular Photo Editor**: Users can upload photos and crop them with pinch-to-zoom and drag gestures
- **Storage**: Photos are saved locally in the app's Documents directory
- **Display**: Profile icon on Home Screen shows the user's photo (falls back to text initials if no photo)
- **Management**: Users can upload, edit, or remove their profile photo from the Profile screen

### ✅ Live Activities for Active Rounds

#### iPhone (iOS 17.0+)
- **Dynamic Island** (iPhone 14 Pro/Pro Max, iPhone 15 Pro/Pro Max):
  - **Compact Leading**: User profile photo
  - **Compact Trailing**: Score vs par (e.g., "+1", "E", "-2")
  - **Minimal**: Score vs par only
  - **Expanded**: Full details with user photo, score, "thru X" text, and course name

- **Lock Screen Widget**: 
  - User profile photo (or golf flag emoji if no photo)
  - Course name
  - Score vs par badge with color coding (red = over par, green = under par, white = even)
  - "thru X" text showing holes completed

#### Apple Watch
- **Enhanced Complication**: Shows score vs par and current hole number with color coding
- Automatically updates via App Groups data sharing

### ✅ Automatic Activity Management
- **Start**: Live Activity begins automatically when a round is started
- **Update**: Updates after each hole is saved with current score and hole number
- **End**: Automatically ends when the round is completed

## Setup Instructions

### 1. Regenerate Xcode Project

Since a new widget extension target was added, you need to regenerate the Xcode project:

```bash
cd /path/to/GolfLab
xcodegen generate
```

Alternatively, if you don't have XcodeGen installed:

```bash
brew install xcodegen
cd /path/to/GolfLab
xcodegen generate
```

### 2. Configure Code Signing

After regenerating the project, open `GolfLab.xcodeproj` in Xcode and:

1. Select the `GolfLabWidgets` target
2. Go to **Signing & Capabilities**
3. Set your Development Team
4. Verify the App Groups capability shows `group.com.nathanhamilton.golflab`

### 3. Test on Device

Live Activities require a physical device (simulator support is limited):

1. Build and run on your iPhone
2. Start a round
3. Lock your phone to see the Lock Screen widget
4. If you have iPhone 14 Pro or later, you'll see the Dynamic Island

### 4. Enable Live Activities Permission

When the app first attempts to start a Live Activity, iOS will prompt the user for permission. Make sure to allow Live Activities for the full experience.

## File Structure

```
GolfLab/
├── Models/
│   └── RoundLiveActivityAttributes.swift   # ActivityKit attributes
├── Services/
│   └── LiveActivityManager.swift           # Activity lifecycle manager
├── Utilities/
│   └── ProfilePhotoStorage.swift           # Photo save/load utility
├── Views/
│   └── Components/
│       └── CircularPhotoEditor.swift       # Photo crop editor
└── GolfLab.entitlements                    # Updated with App Groups

GolfLabWidgets/                              # NEW: Widget extension
├── RoundLiveActivityWidget.swift           # Live Activity views
├── GolfLabWidgets.entitlements
└── Info.plist

Shared/
└── WatchComplicationStore.swift            # Enhanced with score data
```

## Architecture

### Data Flow
```
RoundStore (active round state)
    ↓
LiveActivityManager.startActivity()
    ↓
ActivityKit framework
    ↓
System displays on Dynamic Island/Lock Screen
```

### App Groups Data Sharing
```
RoundStore → App Group Container → Widget/Watch reads data
```

## Color Coding Logic

The score vs par uses color coding across all surfaces:
- **Red**: Over par (positive score)
- **Green**: Under par (negative score)
- **White**: Even par (0)

## Troubleshooting

### Live Activities not showing?
1. Check that you're running on iOS 17.0+ device
2. Verify Live Activities are enabled in Settings → GolfLab
3. Make sure the round is active (not just setup)

### Profile photo not displaying?
1. Check ProfileView console logs for any save errors
2. Verify the photo was successfully uploaded
3. Try removing and re-uploading the photo

### Watch complication not updating?
1. Ensure App Groups entitlement is properly configured
2. Verify both phone and watch are on same Apple ID
3. Check that WatchConnectivity is functioning

### Widget extension build errors?
1. Run `xcodegen generate` again
2. Clean build folder (Cmd+Shift+K)
3. Verify all entitlements are properly set

## Manual Widget Target Setup (If XcodeGen Fails)

If you prefer not to use XcodeGen, you can manually add the widget extension:

1. In Xcode, go to **File → New → Target**
2. Choose **Widget Extension**
3. Name it `GolfLabWidgets`
4. Set Bundle Identifier to `com.nathanhamilton.golflab.widgets`
5. Add the `GolfLabWidgets` folder to the target
6. Add `Shared` folder to the target
7. In **Signing & Capabilities**, add **App Groups** capability
8. Add `group.com.nathanhamilton.golflab` to App Groups
9. Embed the widget extension in the main GolfLab target

## Next Steps

### Potential Enhancements
- [ ] Sync profile photos via iCloud (CloudKit CKAsset)
- [ ] Add grass texture background to widgets
- [ ] Support for multiple profile photos
- [ ] Live Activity push notifications for remote updates
- [ ] Enhanced animations for score changes
- [ ] Support for older iOS versions (graceful degradation)

## API Requirements

### iOS Version Requirements
- **Profile Photo**: iOS 16.0+ (PhotosPicker)
- **Live Activities**: iOS 17.0+ (ActivityKit)
- **Dynamic Island**: iPhone 14 Pro or later

### Capabilities Required
- App Groups: `group.com.nathanhamilton.golflab`
- CloudKit (already configured)
