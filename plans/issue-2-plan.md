# Issue #2 — Add dependencies

## What we're adding

Four packages, then a `.env` file setup.

| Package | Purpose |
|---------|---------|
| `health` | Reads HealthKit data (sleep duration) from Apple Watch via iOS Health app |
| `flutter_local_notifications` | Fires push notifications on iPhone, auto-mirrored to Apple Watch |
| `http` | Makes HTTP requests to Rootly MCP and Claude API |
| `flutter_dotenv` | Loads `CLAUDE_API_KEY` from a `.env` file bundled with the app |

## Commands

Use `flutter pub add` instead of editing `pubspec.yaml` by hand — it fetches the latest stable version and writes the correct constraint automatically.

```bash
flutter pub add health
flutter pub add flutter_local_notifications
flutter pub add http
flutter pub add flutter_dotenv
```

## Manual edits after `flutter pub add`

### 1. `pubspec.yaml` — bundle the `.env` file

`flutter_dotenv` requires the `.env` file to be declared as a Flutter asset so it gets bundled into the app. Add under the `flutter:` section:

```yaml
flutter:
  assets:
    - .env
```

### 2. `.env` (new file at repo root — never committed)

```
CLAUDE_API_KEY=your_key_here
```

### 3. `.env.example` (new file at repo root — committed)

```
CLAUDE_API_KEY=
```

This tells teammates which variables are required without exposing the real key.

### 4. `.gitignore` — verify `.env` is excluded

The Flutter scaffold already adds `.env` to `.gitignore`. Confirm the line exists:

```
.env
```

If it's missing, add it manually.

## Verification

```bash
flutter analyze   # no new errors or warnings
```

Also confirm `pubspec.lock` has been updated (new packages appear in the lock file).

---

## Packages explained

### `health`
A Flutter plugin that reads from HealthKit on iOS (and Google Health Connect on Android — iOS-only for our demo). It asks the user for permission to access specific data types — in our case `HealthDataType.SLEEP_ASLEEP`. The actual data lives on the device inside the iOS Health app, synced from Apple Watch. We never upload it anywhere.

HealthKit requires two keys in `ios/Runner/Info.plist` (added in issue #3) — `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`. Without them, the app crashes the moment it requests permission.

Basic usage pattern:
```dart
final health = Health();
await health.configure();
await health.requestAuthorization([HealthDataType.SLEEP_ASLEEP]);
final data = await health.getHealthDataFromTypes(
  types: [HealthDataType.SLEEP_ASLEEP],
  startTime: sevenDaysAgo,
  endTime: now,
);
```

### `flutter_local_notifications`
Schedules and fires local push notifications on the device — no server, no APNs token needed for local triggers. When a notification fires on iPhone, iOS automatically forwards it to a paired Apple Watch if the phone is face-down or the watch is on wrist. This is how we get Apple Watch delivery with zero watchOS code.

### `http`
Dart's standard HTTP client. Used for exactly two outbound calls:
- `POST` to Rootly MCP endpoint (fetches incidents and on-call schedule)
- `POST` to Claude API (sends signals + risk level, receives recommendation text)

No other network traffic. Everything else stays on device.

### `flutter_dotenv`
Loads a `.env` file that is bundled into the app binary at build time. In `main.dart`, call `await dotenv.load()` before `runApp()`. Then anywhere: `dotenv.env['CLAUDE_API_KEY']`.

The `.env` file is listed under `flutter: assets:` so Flutter includes it in the IPA. The key lives inside the binary — acceptable for a hackathon demo, not for App Store distribution.

Usage:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

// Elsewhere:
final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
```
