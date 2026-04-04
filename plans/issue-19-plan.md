# Issue #19 — MockRootlyService

## What we're doing

One file: `lib/services/mock/mock_rootly_service.dart`

`MockRootlyService` returns hardcoded `WorkSignal` data representing a stressed on-call week.
It is a drop-in stand-in for the real `RootlyService` (issues #13, #14), which requires
Rootly MCP and a live API key.

Together with `MockHealthService` (issue #18), this mock must produce a combined score that
reaches `RiskLevel.high` or `RiskLevel.critical` — so the demo notification fires with a
meaningful result, not just `low`.

---

## Hardcoded signal values

Verify combined score against StressCorrelator formula:

| Signal | Value | Raw work pts |
|--------|-------|-------------|
| criticalCount | 1 | 5 |
| highCount | 2 | 4 |
| afterHoursCount | 2 | 4 |
| isOnCall | true | 2 |
| **rawWork total** | | **15 → clamped to 12 → normWork = 10** |

Mock health from issue #18: rawSleep = 4 (5h30m + frag=3), normSleep = 5.0

```
combined = 5.0 × 0.65 + 10 × 0.35 = 3.25 + 3.50 = 6.75 → RiskLevel.high
```

This confirms the claim in MockHealthService's doc comment.

Window: last 7 days from now (windowStart = DateTime.now() minus 7 days, windowEnd = DateTime.now()).

---

## File to create

```
lib/services/mock/mock_rootly_service.dart
```

```dart
import 'package:oncallbalance/models/work_signal.dart';

class MockRootlyService {
  const MockRootlyService._();

  static WorkSignal fetch() {
    final now = DateTime.now();
    return WorkSignal(
      windowStart: now.subtract(const Duration(days: 7)),
      windowEnd: now,
      totalIncidents: 3,
      criticalCount: 1,
      highCount: 2,
      afterHoursCount: 2,
      isOnCall: true,
    );
  }
}
```

---

## Verification

```bash
flutter analyze
```

No unit test needed — the combined score is already validated by running
`StressCorrelator.compute(MockRootlyService.fetch(), MockHealthService.fetch())`
which equals `RiskLevel.high` per the arithmetic above.
