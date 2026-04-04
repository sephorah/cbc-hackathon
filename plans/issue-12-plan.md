# Issue #12: HealthService Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `HealthService.fetch({int days = 1})` that fetches last night's sleep data from HealthKit via the `health` package and returns a `HealthSignal`.

> **Note:** Default changed from `days=7` to `days=1` after plan approval. A 7-day sum would always exceed the StressCorrelator's per-night thresholds (7h/6h/5h), making the sleep signal ineffective. `days=1` maps directly to those thresholds.

**Architecture:** A single static service class with a pure `aggregate()` helper (exposed for testing via `@visibleForTesting`) that:
- Sums durations of all `SLEEP_ASLEEP + SLEEP_LIGHT + SLEEP_DEEP + SLEEP_REM` segments → `totalSleepDuration`
- Counts distinct `SLEEP_AWAKE` data points → `fragmentationCount`

No per-night grouping or averaging — a straight sum over the window. `ServiceLocator.fetchHealth()` is updated to call the live service when `useMocks=false`.

**Tech Stack:** `health: ^13.3.1` (`Health`, `HealthDataType`, `HealthDataPoint`, `HealthPlatformType`, `NumericHealthValue`), Flutter, Dart

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/services/health_service.dart` | Platform call + pure aggregation logic + exception types |
| Create | `test/services/health_service_test.dart` | Unit tests for `aggregate()` |
| Modify | `lib/core/service_locator.dart` | Wire live `HealthService.fetch()` into `fetchHealth()` |

---

## Task 1: Write failing tests for the aggregation logic

**Files:**
- Create: `test/services/health_service_test.dart`

`aggregate()` is a `@visibleForTesting` static method that takes `List<HealthDataPoint>` and returns `HealthSignal`.

- [x] **Step 1: Create the test file**

```dart
// test/services/health_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:productv1/services/health_service.dart';

HealthDataPoint _makePoint(HealthDataType type, DateTime from, DateTime to) =>
    HealthDataPoint(
      uuid: '${type.name}-${from.millisecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: 0), // overridden by constructor for sleep types
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'test-device',
      sourceId: 'com.apple.health',
      sourceName: 'Apple Watch',
    );

void main() {
  group('HealthService.aggregate', () {
    test('empty list throws HealthDataUnavailableException', () {
      expect(
        () => HealthService.aggregate([]),
        throwsA(isA<HealthDataUnavailableException>()),
      );
    });

    test('SLEEP_AWAKE only (no sleep stages) throws HealthDataUnavailableException', () {
      expect(
        () => HealthService.aggregate([
          _makePoint(HealthDataType.SLEEP_AWAKE,
              DateTime(2026, 4, 3, 2, 0), DateTime(2026, 4, 3, 2, 15)),
        ]),
        throwsA(isA<HealthDataUnavailableException>()),
      );
    });

    test('SLEEP_ASLEEP 7h → totalSleepDuration=7h, fragmentationCount=null', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 6, 0)),
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 7));
      expect(signal.fragmentationCount, isNull);
    });

    test('all four sleep stages summed: 3h LIGHT + 2h DEEP + 1h REM + 30m ASLEEP = 6h30m', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_LIGHT,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 2, 0)),  // 3h
        _makePoint(HealthDataType.SLEEP_DEEP,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 4, 0)),  // 2h
        _makePoint(HealthDataType.SLEEP_REM,
            DateTime(2026, 4, 3,  4, 0), DateTime(2026, 4, 3, 5, 0)),  // 1h
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 3,  5, 0), DateTime(2026, 4, 3, 5, 30)), // 30m
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 6, minutes: 30));
    });

    test('fragmentationCount equals the count of distinct SLEEP_AWAKE points', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 7, 0)),
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 2, 15)),
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  4, 0), DateTime(2026, 4, 3, 4, 10)),
      ]);
      expect(signal.fragmentationCount, 2);
    });

    test('SLEEP_AWAKE does not contribute to totalSleepDuration', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 5, 0)), // 6h
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 2, 30)), // 30m — not counted
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 6));
    });

    test('no SLEEP_AWAKE points → fragmentationCount is null', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 22, 0), DateTime(2026, 4, 3, 6, 0)),
      ]);
      expect(signal.fragmentationCount, isNull);
    });
  });
}
```

- [x] **Step 2: Run the test to confirm it fails (HealthService does not exist yet)**

```bash
flutter test test/services/health_service_test.dart
```

Expected: compilation error — `HealthService` and `HealthDataUnavailableException` not found.

---

## Task 2: Implement HealthService

**Files:**
- Create: `lib/services/health_service.dart`

- [x] **Step 3: Create the service file**

```dart
// lib/services/health_service.dart
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:health/health.dart';
import 'package:productv1/models/health_signal.dart';

/// Live implementation that fetches sleep data from HealthKit.
///
/// [fetch] requests authorization, pulls [days] days of sleep data,
/// and returns a [HealthSignal] summarising the full window.
///
/// totalSleepDuration = sum of all SLEEP_ASLEEP + SLEEP_LIGHT + SLEEP_DEEP + SLEEP_REM segments.
/// fragmentationCount = number of distinct SLEEP_AWAKE data points (null if none).
///
/// Throws [HealthPermissionDeniedException] if the user denies HealthKit access.
/// Throws [HealthDataUnavailableException] if no sleep stage data exists for the window.
/// Callers (ServiceLocator) fall back to MockHealthService on any exception.
class HealthService {
  const HealthService._();

  static final Health _health = Health();

  /// Sleep stage types that contribute to total sleep duration.
  static const _sleepStageTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  /// All types fetched — sleep stages + awakenings.
  static const _allSleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
  ];

  // Default is 1 day (last night) so totalSleepDuration maps directly to the
  // per-night thresholds in StressCorrelator (7h adequate, 6h mild, 5h severe).
  // A 7-day sum would always exceed those thresholds and neutralise the sleep signal.
  static Future<HealthSignal> fetch({int days = 1}) async {
    await _health.configure();

    final authorized = await _health.requestAuthorization(_allSleepTypes);
    if (!authorized) throw const HealthPermissionDeniedException();

    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    final points = await _health.getHealthDataFromTypes(
      types: _allSleepTypes,
      startTime: start,
      endTime: end,
    );

    return aggregate(points);
  }

  /// Aggregates raw HealthKit sleep points into a single [HealthSignal].
  ///
  /// totalSleepDuration: sum of durations of all SLEEP_ASLEEP, SLEEP_LIGHT,
  ///   SLEEP_DEEP, and SLEEP_REM segments.
  /// fragmentationCount: count of distinct SLEEP_AWAKE data points.
  ///   Null if no SLEEP_AWAKE points exist (watch not worn or no awakenings recorded).
  ///
  /// Throws [HealthDataUnavailableException] if [points] has no sleep stage data.
  @visibleForTesting
  static HealthSignal aggregate(List<HealthDataPoint> points) {
    Duration totalSleep = Duration.zero;
    int awakeCount = 0;
    bool hasSleepData = false;

    for (final point in points) {
      if (_sleepStageTypes.contains(point.type)) {
        final duration = point.dateTo.difference(point.dateFrom);
        if (duration <= Duration.zero) continue; // guard against malformed HealthKit data
        totalSleep += duration;
        hasSleepData = true;
      } else if (point.type == HealthDataType.SLEEP_AWAKE) {
        awakeCount++;
      }
    }

    if (!hasSleepData) throw const HealthDataUnavailableException();

    return HealthSignal(
      date: DateTime.now(),
      totalSleepDuration: totalSleep,
      fragmentationCount: awakeCount > 0 ? awakeCount : null,
    );
  }
}

class HealthPermissionDeniedException implements Exception {
  const HealthPermissionDeniedException();
  @override
  String toString() => 'HealthKit authorization was denied by the user.';
}

class HealthDataUnavailableException implements Exception {
  const HealthDataUnavailableException();
  @override
  String toString() => 'No sleep data found in HealthKit for the requested window.';
}
```

- [x] **Step 4: Run the tests — all should pass**

```bash
flutter test test/services/health_service_test.dart
```

Expected: 6 tests pass.

- [x] **Step 5: Run flutter analyze — no issues**

```bash
flutter analyze
```

Expected: no errors or warnings.

- [x] **Step 6: Commit**

```bash
git add lib/services/health_service.dart test/services/health_service_test.dart
git commit -m "feat: implement HealthService with sleep aggregation and tests (issue #12)"
```

---

## Task 3: Wire HealthService into ServiceLocator

**Files:**
- Modify: `lib/core/service_locator.dart`

- [x] **Step 7: Update service_locator.dart**

Add the import after the existing imports:
```dart
import 'package:productv1/services/health_service.dart';
```

Replace the `fetchHealth()` getter:
```dart
static Future<HealthSignal> fetchHealth() =>
    useMocks ? MockHealthService.fetch() : HealthService.fetch();
```

Remove the `_liveHealthNotImplemented()` private method — it is now unused.

- [x] **Step 8: Run all tests**

```bash
flutter test
```

Expected: all tests pass (stress_correlator suite + new health_service suite).

- [x] **Step 9: Run flutter analyze**

```bash
flutter analyze
```

Expected: no issues.

- [x] **Step 10: Mark issue #12 done in issues_backlog.md**

In `issues_backlog.md`, change:
```
| 12 | Implement `HealthService.fetchSleepDuration(days: 7)` via `health` package | P0 | M | |
```
to:
```
| 12 | Implement `HealthService.fetchSleepDuration(days: 7)` via `health` package | P0 | M | ✅ |
```

- [x] **Step 11: Commit**

```bash
git add lib/core/service_locator.dart issues_backlog.md
git commit -m "feat: wire HealthService into ServiceLocator, mark issue #12 done"
```

---

## Verification

1. `flutter test` — all tests pass.
2. `flutter analyze` — no issues.
3. `flutter run --dart-define=USE_MOCKS=true` — uses MockHealthService, no HealthKit call (safe on Linux/simulator).
4. On physical iPhone + Apple Watch: `flutter run --dart-define=USE_MOCKS=false` — prompts for HealthKit permission, reads real sleep data.

**Edge cases covered by tests:**
- No data at all → `HealthDataUnavailableException`
- SLEEP_AWAKE only (no sleep stages) → `HealthDataUnavailableException`
- SLEEP_AWAKE duration not counted toward totalSleepDuration
- All four sleep stage types contribute to totalSleepDuration
- `fragmentationCount` is null when no SLEEP_AWAKE events exist
