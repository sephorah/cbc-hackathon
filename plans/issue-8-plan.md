# Issue #8 — Define `RiskLevel` enum

## What we're doing

Creating `lib/models/risk_level.dart` — a Dart enum representing the output of `StressCorrelator`. Four levels, ordered low → critical.

## File to create

`lib/models/risk_level.dart`

## Values

| Value | Meaning |
|-------|---------|
| `low` | No concerning signals — no action needed |
| `moderate` | Some signals present — gentle nudge |
| `high` | Multiple stress signals — recommend rest/intervention |
| `critical` | Severe combination — notification must include crisis resource link |

**Note on naming:** The backlog says "low / medium / high / critical" but CLAUDE.md and `docs/architecture.md` consistently use `LOW / MODERATE / HIGH / CRITICAL` (with `moderate` not `medium`). Using `moderate` — it's more precise language for a wellbeing context and matches the existing architecture docs.

## Implementation

```dart
enum RiskLevel { low, moderate, high, critical }
```

Dart enums are ordered by declaration — `RiskLevel.low.index == 0`, `RiskLevel.critical.index == 3`. `StressCorrelator` can use this ordering for threshold comparisons (`riskLevel >= RiskLevel.high`).

## What this does NOT cover

- Computing the risk level — issue #9 (`StressCorrelator`)
- Displaying it in the UI — issue #26 (`HomeScreen`)

## Verification

```bash
flutter analyze
```
