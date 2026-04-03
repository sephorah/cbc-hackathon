# Issue #7 — Define `WorkSignal` model

## What we're doing

Creating `lib/models/work_signal.dart` — a pure Dart data class that holds the work-side signals for a given analysis window. Populated by `RootlyService` (issue #13), consumed by `StressCorrelator` (issue #9).

## What the Rootly API actually provides

From the live Rootly v1 API schema:

**Incident fields we use:**
- `severity.data.attributes.severity` → enum `critical | high | medium | low`
- `started_at` → ISO 8601 timestamp — we derive "after-hours" from this (no dedicated field in API)
- `status` → `investigating | identified | monitoring | resolved` — used to filter by window

**After-hours definition:** an incident whose started_at falls outside 09:00–18:00 local device time. This is a hardcoded proxy — the accurate definition would derive the window from the engineer's schedule endpoint, but that's V2. RootlyService computes this, stored as a count in WorkSignal.

**On-call status:** comes from a separate schedule endpoint (issue #14), not from the incident object.

## File to create

`lib/models/work_signal.dart`

## Fields

| Field | Type | Meaning |
|-------|------|---------|
| `windowStart` | `DateTime` | Start of the analysis window (typically 7 days ago) |
| `windowEnd` | `DateTime` | End of the analysis window (now) |
| `totalIncidents` | `int` | All incidents in the window regardless of severity |
| `criticalCount` | `int` | Incidents with severity == `critical` |
| `highCount` | `int` | Incidents with severity == `high` |
| `afterHoursCount` | `int` | Incidents whose `started_at` fell outside 09:00–18:00 local time |
| `isOnCall` | `bool` | Whether the engineer has an active on-call shift right now |

**Why per-severity counts instead of a single "highest severity"?**  
`StressCorrelator` needs to weight severity, not just know the worst case. Three medium incidents hit differently than one medium. Storing counts lets the correlator score: `(criticalCount × 4) + (highCount × 3) + ...`. A single "highest" field would lose that resolution.

**Why `isOnCall` as a bool?**  
For the MVP the relevant question is binary: is the engineer currently on call? On-call schedule detail (shift length, rotation name) belongs in V2. One bool is defensible and explainable in 30 seconds.

## Implementation

```dart
class WorkSignal {
  final DateTime windowStart;
  final DateTime windowEnd;
  final int totalIncidents;
  final int criticalCount;
  final int highCount;
  final int afterHoursCount;
  final bool isOnCall;

  const WorkSignal({
    required this.windowStart,
    required this.windowEnd,
    required this.totalIncidents,
    required this.criticalCount,
    required this.highCount,
    required this.afterHoursCount,
    required this.isOnCall,
  });
}
```

No `fromJson` — `RootlyService` maps the API response directly to this model.  
No `mediumCount`/`lowCount` — `StressCorrelator` only needs the high-stress signals; medium/low count doesn't move the needle in MVP thresholds.

## What this does NOT cover

- Fetching from Rootly API — issue #13 (`RootlyService`)
- Mock data — issue #19 (`MockRootlyService`)
- The scoring logic that uses these fields — issue #9 (`StressCorrelator`)

## Verification

```bash
flutter analyze
```

Pure class, no imports — should pass with zero issues.
