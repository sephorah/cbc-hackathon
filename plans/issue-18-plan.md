# Issue #18 — MockHealthService

## What we're doing

One file: `lib/services/mock/mock_health_service.dart`

`MockHealthService` returns a hardcoded `HealthSignal` that exercises a realistic demo
scenario: a sleep-deprived on-call engineer. It is a drop-in stand-in for the real
`HealthService` (issue #12), which requires HealthKit on a physical iPhone/Apple Watch.

The mock exists for two reasons:
1. **Demo safety**: if HealthKit is unavailable (simulator, no Apple Watch), the app still runs
2. **Linux development**: the real service cannot be tested on Linux — the mock lets us wire up the full pipeline and test `StressCorrelator` end-to-end before meeting the Mac teammate

---

## Hardcoded signal values

| Field | Value | Why |
|-------|-------|-----|
| `totalSleepDuration` | `Duration(hours: 5, minutes: 30)` | Significant deficit (5–6h band = 3 pts) — drives moderate risk without work stress, drives high/critical when combined with incidents |
| `fragmentationCount` | `3` | Mildly elevated (≥3 = +1 pt) — realistic for on-call engineer woken by a page |
| `date` | `DateTime.now()` | Matches today — no hardcoded date that expires |

Sleep choice is intentional for demo: 5h30m + fragmentation=3 pushes the combined score into
`moderate` territory even on a quiet work week, and into `high`/`critical` when combined with
mock work data from issue #19. Judges can see the correlation formula fire.

---

## File to create

```
lib/services/mock/mock_health_service.dart
```

No abstract interface yet (that's fine — the environment flag in issue #21 will wire them
together). For now, `MockHealthService` is a plain class with a single static method.

```dart
import 'package:oncallhelper/models/health_signal.dart';

class MockHealthService {
  const MockHealthService._();

  static HealthSignal fetch() => HealthSignal(
        date: DateTime.now(),
        totalSleepDuration: const Duration(hours: 5, minutes: 30),
        fragmentationCount: 3,
      );
}
```

---

## Verification

```bash
flutter analyze
```

No unit test needed for this file — there is no logic to verify, only a constant value.
The mock's correctness is validated indirectly by the `StressCorrelator` tests that
already run against the same signal shape.
