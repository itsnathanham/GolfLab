# Profile photo and Live Activities

The Xcode project already contains the `GolfLabWidgets` extension and the new source files. Archive the `GolfLab` scheme. You do not need to run XcodeGen for this branch. `project.yml` matches the committed project, including the watch complication target and team `LVN484T28R`, if you regenerate later.

## Before the first archive

Automatic signing has to register one new App ID: `com.nathanhamilton.golflab.widgets`. Use the same team as the iPhone app. The extension’s entitlements file is empty on purpose. Do not add the App Group to the iPhone target. That capability is not on the current iPhone provisioning profile, and the widget never reads the phone’s documents directory.

`NSSupportsLiveActivities` is set on the iPhone app. Without it, `Activity.request` fails and nothing appears.

## What ships

Profile photos are cropped in a circle, saved as a square JPEG in the app’s Documents directory, and shown on Home and Profile. Initials stay when there is no photo.

An active round starts a Live Activity:

- Dynamic Island, compact: photo (or initials) on the left, score versus par and `thru N` on the right. `thru 2` means two holes are saved and the next hole is not.
- Lock Screen: the same facts, on the app-icon green.
- Before any hole is saved the score is an em dash, not `E`.
- The activity ends when the round is saved or discarded, including when the watch ends it. Relaunch adopts an in-progress round and clears a stale activity when nothing is in progress.

The watch complication still gets its data from the watch, not the phone. App Group defaults do not cross devices. After at least one saved hole it shows score versus par over the hole number, using the watch palette. Before that it shows the hole number, as before.

watchOS 11 mirrors the iPhone Live Activity into the Smart Stack using that lock-screen layout. There is no separate watch Live Activity target. A custom watch layout (`supplementalActivityFamilies`) needs the iOS 18 SDK, and this project still deploys to iOS 17.

## On device

1. Confirm the profile photo survives a relaunch and replaces the initials on Home.
2. Start a round. Lock the phone. Confirm the banner, then save a hole and confirm `thru` and the score.
3. On iPhone 14 Pro or later, confirm the compact island shows the photo, the score, and `thru`.
4. Force-quit and reopen during a round. The activity should come back. Discard or save, and it should leave.
5. On the watch, save a hole and confirm the circular complication shows the score rather than `E` before any hole is saved.
