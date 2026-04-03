# Issue #21 — Environment flag to switch between live and mock services

## What we're doing

One file: `lib/core/service_locator.dart`

Provides a single place to get the active service instances. A boolean constant
`useMocks` controls whether the app uses live or mock services. Setting it to
`true` enables demo mode — no live APIs required.

This is not a dependency injection framework. It is the simplest pattern that
works for MVP: a static class with factory getters. Judges can read it in 10
seconds and understand exactly what it does.

---

## Design

```dart
// Set to true to run with hardcoded mock data (demo safety / Linux dev).
// Set to false to use live HealthKit + Rootly MCP + Claude API.
const bool useMocks = true;
```

The flag is a top-level `const bool` — it is a compile-time constant, which
means the Dart compiler dead-strips the unused branch. No runtime overhead.

Because the real services (HealthService, RootlyService, ClaudeService) do not
exist yet, the locator only exposes mock getters for now. Real service getters
will be added in issues #12–15. The file is structured to make that addition obvious.

---

## File to create

```
lib/core/service_locator.dart
```

```dart
import 'package:oncallhelper/models/health_signal.dart';
import 'package:oncallhelper/models/risk_level.dart';
import 'package:oncallhelper/models/work_signal.dart';
import 'package:oncallhelper/services/mock/mock_claude_service.dart';
import 'package:oncallhelper/services/mock/mock_health_service.dart';
import 'package:oncallhelper/services/mock/mock_rootly_service.dart';

/// Set to true to run the app with hardcoded mock data.
/// Set to false once live services (issues #12–15) are implemented.
const bool useMocks = true;

/// Single source of service instances for the app.
///
/// Real service getters will replace the mock branches in issues #12–15.
/// To swap a service, change the corresponding getter — callers are unaffected.
class ServiceLocator {
  const ServiceLocator._();

  static HealthSignal fetchHealth() =>
      useMocks ? MockHealthService.fetch() : _liveHealthNotImplemented();

  static WorkSignal fetchWork() =>
      useMocks ? MockRootlyService.fetch() : _liveWorkNotImplemented();

  static String getRecommendation(RiskLevel risk) => useMocks
      ? MockClaudeService.getRecommendation(risk)
      : _liveClaudeNotImplemented();

  // --- Stubs for live services (replaced in issues #12–15) ---

  static HealthSignal _liveHealthNotImplemented() =>
      throw UnimplementedError('HealthService not yet implemented — set useMocks = true');

  static WorkSignal _liveWorkNotImplemented() =>
      throw UnimplementedError('RootlyService not yet implemented — set useMocks = true');

  static String _liveClaudeNotImplemented() =>
      throw UnimplementedError('ClaudeService not yet implemented — set useMocks = true');
}
```

---

## Why not an interface / abstract class pattern?

The backlog has 6 hours left on the demo clock. An abstract class + factory pattern
adds 3 extra files and requires the real services to implement an interface that
doesn't exist yet. The `const bool useMocks` toggle is readable, debuggable, and
judges can understand it without knowing Flutter. The interface pattern can be
introduced in V2 when the real services are built.

---

## Verification

```bash
flutter analyze
```
