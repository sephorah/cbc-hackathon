# Issue #3 — Configure iOS Info.plist with HealthKit permissions

## What we're doing

Adding two required keys to `ios/Runner/Info.plist` so HealthKit doesn't crash the app on the first permission request.

Apple requires every iOS app that uses HealthKit to declare **why** it needs access. Without these keys, the OS throws an exception the moment we call `health.requestAuthorization(...)` — the app crashes before it can do anything. There is no workaround.

## File to edit

`ios/Runner/Info.plist`

## Keys to add

```xml
<key>NSHealthShareUsageDescription</key>
<string>ProductV1 reads your sleep duration from Apple Health to detect sleep deficits that may compound on-call stress. This data never leaves your device.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>ProductV1 does not write health data. This permission is required by HealthKit but will not be used.</string>
```

**Why two keys?**
- `NSHealthShareUsageDescription` — shown to the user when the app asks to **read** health data. This is the one that matters.
- `NSHealthUpdateUsageDescription` — required by App Store / HealthKit API even if you never write data. Omitting it causes a build warning and potential App Store rejection. We declare it honestly: we don't write.

**Placement:** Insert before the closing `</dict>` tag, after the existing `UISupportedInterfaceOrientations~ipad` block.

## Why these specific description strings

- Mentions **sleep duration specifically** — HealthKit permission dialogs show the exact string to the user, so vague text ("health data") erodes trust. We name what we read.
- States **"never leaves your device"** — directly addresses the privacy concern engineers have. This matches our PIPEDA/PHIPA compliance story.
- Honest about write permission — judges will ask about this. We don't hide it.

## Verification

No `flutter analyze` check needed (plist changes are iOS-native, not Dart). Verification happens at runtime on a real device or simulator:

```bash
flutter run
# Tap "Check my wellbeing" → iOS should show the HealthKit permission dialog
# If it crashes instead → plist keys are wrong or missing
```

On a simulator without HealthKit data, the permission dialog still appears — that's the confirmation this works.

## What this does NOT cover

- `NSUserNotificationsUsageDescription` for push notifications — `flutter_local_notifications` handles its own permission prompt in Dart code, no plist key required for local notifications.
- Any Entitlements file changes — HealthKit entitlements are already enabled in the Flutter scaffold's `Runner.entitlements` (added automatically by the `health` package setup in issue #2).
