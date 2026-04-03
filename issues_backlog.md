# Recover — Issues Backlog

## Legend
- **Priority:** P0 (blocker) · P1 (MVP required) · P2 (nice to have before demo) · P3 (V2)
- **Size:** S (< 1h) · M (1–3h) · L (3–6h)

---

## Setup

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 1 | Scaffold Flutter iOS project (`flutter create`) | P0 | S | ✅ |
| 2 | Add dependencies: `health`, `flutter_local_notifications`, `http`, `flutter_dotenv` | P0 | S | ✅ |
| 3 | Configure iOS `Info.plist` with HealthKit permissions (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) | P0 | S | ✅ |
| 4 | Set up Codemagic pipeline for cloud Mac builds from Linux | P0 | M | |
| 5 | Create `.env.example` with `CLAUDE_API_KEY` placeholder | P0 | S | ✅ |

---

## Core Models

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 6 | Define `HealthSignal` model (total sleep duration, fragmentation count — nullable if watch not worn, date) | P0 | S | ✅ |
| 7 | Define `WorkSignal` model (incident count, after-hours pages, on-call shifts, severity) | P0 | S | ✅ |
| 8 | Define `RiskLevel` enum (low / medium / high / critical) | P0 | S | |

---

## Deterministic Correlation Layer

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 9 | Implement `StressCorrelator.compute(WorkSignal, HealthSignal) → RiskLevel` with explicit weighted thresholds | P0 | M | |
| 10 | Define thresholds in `core/constants/thresholds.dart` (single source of truth) | P0 | S | |
| 11 | Write unit tests for `StressCorrelator` covering all risk levels and edge cases | P1 | M | |

---

## Services

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 12 | Implement `HealthService.fetchSleepDuration(days: 7)` via `health` package | P0 | M | |
| 13 | Implement `RootlyService.fetchIncidents()` via Rootly MCP | P0 | L | |
| 14 | Implement `RootlyService.fetchOnCallSchedule()` via Rootly MCP | P0 | M | |
| 15 | Implement `ClaudeService.getRecommendation(RiskLevel, WorkSignal, HealthSignal) → String` | P0 | M | |
| 16 | Implement `NotificationService.send(title, body)` via `flutter_local_notifications` | P0 | M | |
| 17 | Verify push notification mirrors to Apple Watch automatically | P0 | S | |

---

## Mock Data Fallback (Demo Safety)

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 18 | Create `MockHealthService` with hardcoded sleep signal (5.5h, 7 days) | P0 | S | |
| 19 | Create `MockRootlyService` with hardcoded incident + schedule data | P0 | S | |
| 20 | Create `MockClaudeService` with hardcoded recommendation strings per risk level | P0 | S | |
| 21 | Add environment flag to switch between live and mock services | P1 | S | |

---

## Claude Prompt

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 22 | Write Claude system prompt scoped to SRE context (not generic wellness) | P1 | M | |
| 23 | Include raw signal values in prompt (not just risk label) for specificity | P1 | S | |
| 24 | Add crisis handoff instruction to prompt: if critical, include human resource link in output | P0 | S | |

---

## Screens

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 25 | Build `OnboardingScreen`: what data is collected, why, privacy guarantee (data never leaves device) | P1 | M | |
| 26 | Build `HomeScreen`: trigger analysis button, display last risk level and recommendation | P1 | M | |
| 27 | Show loading state while fetching data and calling Claude API | P2 | S | |
| 28 | Show error state if any service fails (with fallback to mock data) | P2 | S | |

---

## Ethical & Safety Requirements

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 29 | Critical risk path: notification body includes link to human resource / crisis line | P0 | S | |
| 30 | Add disclaimer in app: "This app does not replace human support or professional help" | P1 | S | |
| 31 | Confirm no data leaves device (no analytics, no crash reporting that sends health data) | P0 | S | |

---

## Demo Prep

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 32 | End-to-end test: mock data → correlator → Claude API → push notification fires | P0 | M | |
| 33 | End-to-end test: live data (Rootly MCP + HealthKit) → push notification fires | P1 | L | |
| 34 | Prepare demo script: walk through exactly what happens when notification fires | P1 | M | |
| 35 | Prepare answer for "show me the correlation formula" (printout or slide) | P1 | S | |
| 36 | Test Apple Watch notification mirror on physical device | P0 | M | |

---

## V2 (Post-Hackathon)

| # | Title | Priority | Size | Done |
|---|-------|----------|------|------|
| 37 | Local SQLite database for daily signal history | P3 | L | |
| 38 | Week-over-week trend analysis screen | P3 | L | |
| 39 | Heart rate variability as additional HealthKit signal | P3 | M | |
| 40 | Optional trusted colleague connection feature | P3 | L | |
| 41 | Optional encrypted anonymized aggregation for team insights (opt-in) | P3 | L | |
| 42 | Company sponsorship / wellness resource integration | P3 | L | |
