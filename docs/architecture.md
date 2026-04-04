# Architecture

## `lib/` structure

```
lib/
├── main.dart              # App entry point — currently a placeholder counter app, will be replaced by issues #25/#26
├── models/
│   ├── health_signal.dart # Total sleep duration + fragmentation count (nullable) from HealthKit (issue #6)
│   ├── work_signal.dart   # Incident count, severity, after-hours pages (issue #7)
│   └── risk_level.dart    # Enum: LOW / MODERATE / HIGH / CRITICAL (issue #8)
├── services/
│   ├── health_service.dart        # HealthKit via `health` package (issue #12)
│   ├── rootly_service.dart        # ✅ Rootly REST API — fetchIncidents() + fetch() → WorkSignal (issues #13, #14)
│   ├── claude_service.dart        # Claude API — recommendation text only (issue #15)
│   ├── notification_service.dart  # flutter_local_notifications (issue #15)
│   └── mock/                      # Drop-in mocks for demo fallback (issues #18–21)
│       ├── mock_health_service.dart
│       └── mock_rootly_service.dart
├── core/
│   └── stress_correlator.dart     # Deterministic scoring logic (issues #9–11)
└── screens/
    ├── onboarding_screen.dart     # One-time privacy explainer (issue #25)
    └── home_screen.dart           # Main dashboard + trigger button (issue #26)
```

### What each folder is for

**`models/`** — Pure data classes. No logic, no network calls. Just structured representations of data the app works with:
- `HealthSignal` holds "6.5 hours of sleep last night"
- `WorkSignal` holds "3 incidents, 1 critical, 2 after-hours pages"
- `RiskLevel` is an enum — the output of the correlation step

**`services/`** — Classes that talk to the outside world. Each service has one job: fetch or send data, then return a model. The app never calls a raw API directly — it always goes through a service.

The `mock/` subfolder contains identical interfaces with hardcoded realistic data. You can swap live → mock in one line during the demo if an API fails.

**`core/`** — Business logic that is neither a service nor a screen. `StressCorrelator` lives here: it takes a `HealthSignal` and a `WorkSignal`, applies explicit weighted thresholds, and returns a `RiskLevel`. It is deterministic, fully testable, and the part judges will ask you to walk through.

**`screens/`** — What the user sees. Each screen is a Flutter widget. Screens call services, pass data to `StressCorrelator`, and display results. They contain no business logic.

## Data flow

```
HealthService ──┐
                ├─→ StressCorrelator ──→ ClaudeService ──→ NotificationService
RootlyService ──┘   (deterministic)      (text only)       (push + Apple Watch)
```

`StressCorrelator` computes `RiskLevel` from raw signals using explicit weighted thresholds — no AI involved. `ClaudeService` receives the signals **and** the pre-computed `RiskLevel` and generates natural language only. It does not make the decision.

## Key implementation constraints

- All data stays on device — the only outbound HTTP calls are to Rootly REST API and the Claude API
- `StressCorrelator` thresholds must be named constants in `core/constants/thresholds.dart` — judges will ask "who decided these and why"
- `ClaudeService` prompt must be SRE-specific and include the pre-computed risk level — Claude never decides the risk
- `NotificationService` must include a crisis resource link in critical-risk notifications (non-negotiable ethical requirement)
