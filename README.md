# OnCallHelper

**Tagline:** "Your personal AI wellbeing companion that integrates work and health data — all private, all local."

## Product Vision

OnCallHelper is a privacy-first AI assistant for on-call engineers that integrates work data from Rootly MCP (incidents, schedules, on-call shifts) with personal health metrics from Apple Watch. Its purpose is to prevent burnout, promote positive mental health, and provide actionable resources — all while keeping sensitive data entirely under the user's control.

## Target Users

- On-call engineers carrying incident response responsibilities alongside regular engineering work.
- Users who want early signals on stress, sleep deficits, and workload patterns before burnout sets in.
- Users who value privacy-first mental health support and want personalized guidance without company oversight.

## Core Features

### Data Integration (Local Only)
- **Work data:** Rootly MCP — incidents, after-hours pages, on-call schedules, shift frequency.
- **Health data:** Apple Watch via HealthKit — sleep duration (MVP); additional metrics from other wellness apps in future versions.
- **Privacy guarantee:** All data stays on the device; no sharing with the company, ever.

### Deterministic Correlation Layer
Work and health signals are combined using explicit weighted thresholds — not a black box. The engineer can understand exactly why they received a particular risk level.

Example logic:
```
sleep < 6h AND incidents >= 3 AND after_hours_pages >= 2  →  HIGH risk
sleep < 7h AND incidents >= 5                             →  MEDIUM risk
otherwise                                                 →  LOW risk
```

### AI-Powered Recommendations
Claude API receives the risk level and raw signal values and returns a short, SRE-specific recommendation. The AI generates the output text — it does not make the decision.

Example output:
> "You've handled 4 incidents this week, two after midnight, and averaged 5.5h of sleep. That's a known burnout pattern for on-call engineers. Consider blocking tomorrow morning for recovery."

### Personalized Resource Recommendations
- Suggests context-appropriate resources: stress-relief activities, mindfulness, counseling apps, or professional support.
- If risk is critical, notification includes a link to a human resource or crisis line — not just wellness tips.
- Fully opt-in; no automatic sharing with management.

### Optional Trusted Support (V2)
- Users can choose to connect with trusted colleagues or mentors for guidance.
- OnCallHelper facilitates the connection without exposing sensitive health or work data.

### User Interface
- Push notification on iPhone with the AI recommendation — mirrors to Apple Watch automatically (no watchOS app required).
- Future: companion iPhone app for detailed summaries, trends, and resource access.

## Business Value & Company Integration

- Companies can sponsor or pay for OnCallHelper as part of their employee wellbeing programs.
- **Company perspective:** Demonstrates investment in mental health without ever accessing sensitive personal data.
- Employees retain full privacy but can opt into company-provided resources — wellness apps, coaching, or therapy vouchers.
- Positions the company as responsible and employee-focused, improving morale and retention.

## Architecture Overview (MVP)

```
[Apple Watch / HealthKit]     [Rootly MCP Server]
         |                            |
         └──────────┬─────────────────┘
                    |
          Deterministic Correlation
          (explicit weighted thresholds)
                    |
              Risk Level + Signals
                    |
               Claude API
          (recommendation text only)
                    |
         Local Push Notification
                    |
             Apple Watch (mirrored)
```

- All computation happens locally on device — no backend, no server.
- No database in MVP; local storage for trend tracking planned for V2.
- Mock data fallback available for all three integrations (demo reliability).

## Technical Considerations

- **AI model:** Claude API for recommendation text output only — deterministic layer makes the risk decision.
- **Data storage:** HealthKit (on-device); no additional database in MVP.
- **Privacy compliance:** PIPEDA (Canadian federal), PHIPA (Ontario health) — compliant by design. HIPAA-ready architecture for future US scaling.
- **Build pipeline:** Codemagic (cloud Mac builds from Linux).
- **Scalability:** Future versions may allow optional encrypted, anonymized aggregation for team insights — fully opt-in.

## Ethical and Privacy Commitments

- Fully user-controlled data → no risk of stigma or workplace bias.
- Prevention-focused → promotes wellbeing without performance evaluation.
- Crisis handoff exists for critical risk — engineer is never left with automated advice alone.
- Optional social support is always user-driven, never automatic.
- Correlation thresholds are transparent and explainable to any audience.

## Hackathon MVP Scope

- Pull Rootly MCP data: incident count, severity, after-hours pages, on-call schedule.
- Pull HealthKit sleep duration from Apple Watch.
- Compute risk level deterministically from combined signals.
- Send signals + risk level to Claude API; receive personalized recommendation text.
- Fire local push notification on iPhone, mirrored to Apple Watch.
- Crisis handoff path for critical risk.
- Onboarding screen explaining data collection and privacy.

## Impact

- Gives on-call engineers a private early warning system before burnout escalates.
- Empowers engineers to take ownership of their wellbeing without exposing data to their employer.
- Demonstrates responsible, transparent AI usage in mental health — AI communicates, it doesn't decide.
- Companies can invest in engineer wellbeing without compromising privacy, building trust and improving retention.
