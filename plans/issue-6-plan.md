# Issue #6 — Define `HealthSignal` model

## What we're doing

Creating `lib/models/health_signal.dart` — a pure Dart data class that holds one night's sleep data from HealthKit. No logic, no network calls, just structured data.

## File to create

`lib/models/health_signal.dart`

## Fields

| Field | Type | Nullable | Meaning |
|-------|------|----------|---------|
| `date` | `DateTime` | no | The date of the sleep session (midnight of the night recorded) |
| `totalSleepDuration` | `Duration` | no | Total time spent asleep (excludes AWAKE periods within the sleep window) |
| `fragmentationCount` | `int?` | yes | Number of AWAKE segments detected within the sleep window. `null` means the Apple Watch was not worn that night — not zero awakenings, unknown |

**Why `Duration` over `double` hours?**  
`Duration` is Dart's native time type — it prevents unit confusion (hours vs minutes vs seconds) and makes comparisons against thresholds cleaner: `signal.totalSleepDuration < const Duration(hours: 6)` reads plainly. `StressCorrelator` will use this directly.

**Why `int?` for fragmentation?**  
`null` and `0` mean different things here: `0` = "wore watch, no awakenings detected" vs `null` = "no watch, no data." Conflating them would cause the correlator to treat "no data" as "perfect sleep," which is a silent bug.

## Implementation

```dart
class HealthSignal {
  final DateTime date;
  final Duration totalSleepDuration;
  final int? fragmentationCount;

  const HealthSignal({
    required this.date,
    required this.totalSleepDuration,
    this.fragmentationCount,
  });
}
```

No `fromJson`/`toJson` needed — all data stays on device, no serialization.  
No `copyWith` needed — models are immutable, created once by `HealthService`.

## What this does NOT cover

- Fetching data from HealthKit — that is issue #12 (`HealthService`)
- Mock data — that is issue #18 (`MockHealthService`)
- The `WorkSignal` and `RiskLevel` models — those are issues #7 and #8

## Verification

```bash
flutter analyze
```

`health_signal.dart` is a pure class with no imports — `flutter analyze` should pass with zero issues.
