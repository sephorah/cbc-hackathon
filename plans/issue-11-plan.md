# Issue #11 — Unit tests for `StressCorrelator`

## What we're doing

One file: `test/core/stress_correlator_test.dart`

`StressCorrelator` is the deterministic layer judges will interrogate most. Tests serve two purposes: verify correctness and document expected behaviour for every risk level, boundary, and edge case so we can answer "show me the formula" with running proof.

---

## Test helpers

Two factory functions at the top of `main()` to reduce boilerplate:

```dart
WorkSignal work({
  int critical = 0,
  int high = 0,
  int afterHours = 0,
  bool onCall = false,
}) => WorkSignal(
  windowStart: DateTime(2026, 4, 1),
  windowEnd: DateTime(2026, 4, 7),
  totalIncidents: critical + high,
  criticalCount: critical,
  highCount: high,
  afterHoursCount: afterHours,
  isOnCall: onCall,
);

HealthSignal health({
  required Duration sleep,
  int? fragmentation,
}) => HealthSignal(
  date: DateTime(2026, 4, 7),
  totalSleepDuration: sleep,
  fragmentationCount: fragmentation,
);
```

---

## Test groups and cases

### `RiskLevel.low`

| Scenario | rawWork | rawSleep | combined | Expected |
|----------|---------|----------|---------|----------|
| Quiet week, 8h sleep | 0 | 0 | 0.0 | low |
| Exactly 7h sleep, no incidents | 0 | 0 | 0.0 | low |

### `RiskLevel.moderate`

| Scenario | rawWork | rawSleep | combined | Expected |
|----------|---------|----------|---------|----------|
| 4h sleep, no incidents | 0 | 6 | 4.875 | moderate |
| 3 critical, 8h sleep | 15→clamped | 0 | 3.5 | moderate |
| 2 high + 2 after-hours, 5.5h | 8 | 3 | 4.77 | moderate |

### `RiskLevel.high`

| Scenario | rawWork | rawSleep | combined | Expected |
|----------|---------|----------|---------|----------|
| On-call + 1 critical + 2 after-hours, 5.5h | 11 | 3 | 5.65 | high |

### `RiskLevel.critical`

| Scenario | rawWork | rawSleep | combined | Expected |
|----------|---------|----------|---------|----------|
| On-call + 2 critical + 3 after-hours, 4.5h | 18→clamped | 6 | 8.375 | critical |

### Sleep duration boundaries

These verify the three `Duration` comparisons in `_normalizedSleepScore`. Note: Dart `Duration(hours: 6) < Duration(hours: 6)` is false — so exactly 6h is mild (1 pt), not significant.

| Input | Points | Expected level (no work) |
|-------|--------|--------------------------|
| `Duration(hours: 7)` | 0 | low |
| `Duration(hours: 6, minutes: 59)` | 1 | low |
| `Duration(hours: 6)` | 1 | low |
| `Duration(hours: 5, minutes: 59)` | 3 | low (combined=2.44) |
| `Duration(hours: 5)` | 3 | low (combined=2.44) |
| `Duration(hours: 4, minutes: 59)` | 6 | moderate (combined=4.875) |

### Fragmentation

Sleep fixed at 5h30m (rawSleep=3 before fragmentation) for all cases.

| fragmentationCount | Extra pts | rawSleep | normSleep | combined (no work) | Expected |
|-------------------|-----------|----------|-----------|-------------------|---------|
| `null` | 0 | 3 | 3.75 | 2.44 | low |
| 2 | 0 | 3 | 3.75 | 2.44 | low |
| 3 | +1 | 4 | 5.0 | 3.25 | moderate |
| 4 | +1 | 4 | 5.0 | 3.25 | moderate |
| 5 | +2 | 5 | 6.25 | 4.06 | moderate |

### Work score clamping

5 critical incidents → rawWork=25, clamped to 12 → normWork=10. With 8h sleep, combined=3.5 → moderate. Same result as 2 critical (rawWork=10→normWork=8.33 is different, but 3 critical=15 also clamps). Verify clamping works: 5 critical + 8h sleep must equal same level as 3 critical + 8h sleep.

### `isOnCall` flat penalty

On-call only, no incidents, 8h sleep:
- rawWork=2, normWork=1.67, rawSleep=0, combined=0.58 → **low**
- Verifies the flat +2 is additive, not a multiplier, and alone doesn't push risk up

---

## Arithmetic reference

Key formula:
```
combined = (rawSleep / 8.0).clamp(0,1) × 10 × 0.65
         + (rawWork  / 12.0).clamp(0,1) × 10 × 0.35
```

Sleep points (non-linear): `< 5h → 6`, `5–6h → 3`, `6–7h → 1`, `≥7h → 0`
Fragmentation: `≥5 → +2`, `3–4 → +1`, `<3 or null → 0`
Work: `critical×5 + high×2 + afterHours×2 + (onCall ? 2 : 0)`

---

## Verification

```bash
flutter test test/core/stress_correlator_test.dart
flutter analyze
```
