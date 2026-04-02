# Issue #1 — Scaffold Flutter iOS project

## Context
Run `flutter create` to produce the initial Flutter iOS project scaffold in the existing repo directory. The repo currently contains only `CLAUDE.md`, `README.md`, and `issues_backlog.md`. No Flutter files exist yet. This is a prerequisite for all subsequent issues.

## Command

```bash
flutter create . --org com.oncallhelper --project-name oncallhelper --platforms ios
```

## What gets generated
- `pubspec.yaml` — Flutter manifest (updated in issue #2)
- `lib/main.dart` — default counter app (replaced when screens are implemented)
- `ios/` — Xcode project including `ios/Runner/Info.plist` (HealthKit permissions added in issue #3)
- `test/widget_test.dart` — default test file
- Standard scaffolding: `.gitignore`, `analysis_options.yaml`, etc.

## Verification
- `flutter analyze` passes with no errors
- `ios/Runner/Info.plist` exists

---

## Generated files explained

### `pubspec.yaml` — the project manifest
Think of this as `package.json` for Flutter. It defines:
- **name:** `oncallhelper` — your app's identifier
- **version:** `1.0.0+1` — the `1.0.0` is user-visible, the `+1` is the iOS build number (CFBundleVersion)
- **dependencies:** packages your app needs at runtime. Right now just Flutter itself + `cupertino_icons` (iOS-style icons). Issue #2 adds `health`, `flutter_local_notifications`, `http`, `flutter_dotenv` here.
- **dev_dependencies:** tools only used during development (`flutter_lints` for code style checks, `flutter_test` for tests)

### `lib/main.dart` — the app entry point
This is a throwaway placeholder — the default counter app Flutter always generates. Replaced entirely when building real screens (issues #25/#26).

Key Flutter concepts visible here:
- `runApp()` — launches the app, takes a widget tree
- **Widget** — everything in Flutter is a widget (like React components). Widgets describe what to render.
- **StatelessWidget** — a widget with no changing state (e.g., a static label)
- **StatefulWidget** — a widget that can change over time (e.g., the counter). Has a separate `State` object that holds mutable data.
- `setState()` — tells Flutter "something changed, re-render this widget"
- `build()` — called every time Flutter needs to render the widget. Returns the UI tree.

### `ios/` — the Xcode project
The full iOS native project. Generally not touched directly except:
- `ios/Runner/Info.plist` — iOS app configuration. Issue #3 adds HealthKit permission strings here (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`).
- `ios/Runner.xcworkspace` — what Codemagic opens to build the app.

### `test/widget_test.dart` — default test
A placeholder test for the default counter app. Replaced when real tests are written (issue #11 for `StressCorrelator`).

### `analysis_options.yaml` — linter config
Enables `flutter_lints` — the standard Flutter style rules. `flutter analyze` uses this. No need to touch it.

### `.gitignore`
Flutter-generated. Correctly excludes build artifacts (`build/`, `.dart_tool/`), keeping the repo clean.
