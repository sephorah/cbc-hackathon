# ProductV1

## What we're building
A privacy-first Flutter iOS app for on-call engineers that correlates 
work data (Rootly MCP) with personal health data (Apple Watch via 
HealthKit) to detect stress, sleep deficits, and workload patterns — 
delivering a personalized AI recommendation as a push notification 
mirrored to Apple Watch.

Tagline: "Your personal AI wellbeing companion that integrates work 
and health data — all private, all local."

## Target users
On-call engineers with high workload and on-call responsibilities who 
want early insights into stress, sleep, and work-life balance without 
company oversight.

## Stack
- Flutter (iOS only for demo)
- HealthKit via `health` package for sleep duration from Apple Watch
- Rootly MCP Server for incidents, schedules, on-call shifts
- Claude API for personalized recommendation text
- Local push notifications mirrored to Apple Watch automatically

## Architecture decisions
- No database in MVP: live data pulled on demand, no persistence needed
- Database in V2: to track patterns over time, identify trends, 
  compare week-over-week workload and sleep correlation
- No watchOS app: push notifications mirror to Apple Watch automatically
- No backend server: all computation happens locally on device
- Flutter over native Swift: cross-platform, Linux development, 
  `health` package available
- Local-only: PIPEDA/PHIPA compliant by design, no server attack surface
- Deterministic correlation layer: work and health signals correlated 
  with clear rules, Claude API only generates natural language output
- Claude API for recommendation text only: AI communicates the result, 
  does not make the decision

## MVP scope (strict)
1. Pull Rootly MCP data: incident count, severity, after-hours pages, 
   on-call schedule
2. Pull HealthKit sleep duration from Apple Watch
3. Correlate work and health signals deterministically to detect stress, 
   sleep deficits, and workload patterns
4. Send signals + correlation result to Claude API
5. Claude API returns short personalized recommendation text
6. Push notification fires on iPhone, mirrors to Apple Watch

## V2 scope (post-hackathon)
- Local database to store daily signals and track patterns over time
- Week-over-week trend analysis
- Heart rate variability as additional health signal
- Optional encrypted anonymized aggregation for team insights (opt-in)
- Trusted colleague or mentor connection feature

## Hackathon context
- Event: Claude Builders Hackathon at McGill, April 4th 2026
- Track: Neuroscience & Mental Health
- Sub-challenge: Rootly Sub-Challenge (Engineer Wellbeing)
- Team size: 3 people
- Pre-building started April 1st
- Submission deadline: 4:00 PM on April 4th
- Demo: 5 min presentation + 2 min Q&A

## Judging criteria
- Technical Execution (30%): Does it work? Is it well-built? Does it 
  use AI effectively?
- Real-World Impact (25%): Does it solve a real problem? Who benefits 
  and how? Could it scale?
- Ethical Alignment (25%): Does it center human dignity? Does it 
  address potential harms? Does it expand access equitably?
- Presentation Quality (20%): Can you clearly explain what you built 
  and why it matters?

⚠️ CRITICAL: Must be able to explain every technical decision. 
Using AI coding tools is encouraged but we own the project.

## Three mandatory pitch questions
- Who are we building this for, and why do they need it?
- What could go wrong, and what would we do about it?
- How does this help people rather than make decisions for them?

## Track-specific ethical considerations to address
- Crisis situations: when does someone need immediate human 
  intervention?
- Privacy and stigma around mental health data
- Avoiding harm through bad psychological advice
- Transparency about what AI can and cannot do
- Not replacing human connection when it is needed

## Rootly sub-challenge requirements
Using Rootly MCP Server: 99 tools covering incidents, schedules, 
escalation policies, on-call shifts. Must address a real problem in 
engineer health, incident response, or team operations.

## Key statistics from SRE Report 2025 (Catchpoint, n=301)
Use these in the pitch to justify the problem:

ON INCIDENTS:
- 40% of SREs responded to 1-5 incidents in the last 30 days
- 23% responded to 6-10 incidents per month — load described as 
  "even more challenging when compounded by other responsibilities"
- Higher-level managers are just as involved in incidents as individual 
  contributors, if not more

ON STRESS AFTER INCIDENTS:
- 14% of respondents reported higher stress AFTER incidents than during
- Support drops from 55% (during incidents) to 44% (after incidents)
- Post-incident gap is explicitly named: "once an incident is resolved, 
  all the work is done" is a false assumption

ON TOIL:
- Operational toil rose to 30% median from 25% — first rise in 5 years
- Operations work is encroaching on time for proactive engineering

ON ORGANIZATIONAL PRESSURE:
- 41% of SREs feel pressured "often" or "always" to prioritize release 
  schedules over reliability
- 57% describe organizational priorities as stable — but that stability 
  breaks under production pressure

ON AI SENTIMENT:
- 37% of SREs want technical training to use AI effectively
- 46% of individual contributors approach AI with caution vs 30% of 
  managers — shows engineers are skeptical, meaning trust is earned, 
  not assumed. ProductV1 must be transparent.

ON LEARNING:
- Most SREs don't have enough time for technical learning
- 1 in 5 organizations provides no paid technical training support

PITCH ANGLE FROM REPORT:
"Incidents don't end when they're over" (Sergey Katsev, VP Engineering)
— this is the human cost ProductV1 addresses.

## Limits and drawbacks to address before submission
- Crisis handoff missing: if risk is critical, notification MUST point 
  to a human resource or crisis line — not just mindfulness tips
- No onboarding: add one screen explaining what data is collected, 
  why, and that it never leaves the device
- Demo risk: 3 live APIs in 5 minutes is risky — have mock data 
  fallback ready if any API fails
- Recommendation text could feel generic: Claude prompt must be 
  specific to SRE context, not generic wellness advice
- Shallow wrapper risk: deterministic correlation layer is what 
  defends against this — must be explainable
- Scaling story: answer is "each engineer installs individually, 
  no backend, no infrastructure cost"
- Opt-in sharing: any manager sharing must be explicitly opt-in, 
  never automatic
- Correlation transparency: must be able to explain exactly how 
  work and health signals are combined and why
- Single health metric risk: sleep alone is a weak signal — if time 
  allows, add heart rate from HealthKit
- No evidence of user demand: ask Rootly representative casually 
  what engineers told them when building On-Call Health
- AI skepticism among engineers: 46% approach AI with caution — 
  transparency about what the app does and doesn't do is essential 
  to build trust

## Judge questions to be ready for
- Walk me through exactly what happens when the notification fires
- Why Flutter over a native or web app?
- How do you correlate work and health metrics? Show me the formula
- What happens if Rootly MCP returns no data?
- Why no database in MVP?
- What would a V2 with a database look like?
- What happens if an engineer gets a critical risk notification and 
  is in genuine distress?
- Can the employer ever see this data? How do you guarantee that?
- Who decided the correlation thresholds and why?
- Is this empowering the engineer or surveilling them?
- Show me a real engineer using this — walk me through their day
- Why would an engineer trust this app?
- No evidence engineers actually want this — did you talk to any?

## Ethical requirements (non-negotiable)
- Crisis handoff: critical risk notification must point to a human 
  resource
- Data never leaves device
- Sharing with manager always opt-in, never automatic
- App explicitly states it does not replace human support
- Correlation thresholds must be explainable and defensible
- Engineer owns their data, not the employer

## Privacy compliance
- PIPEDA: Canadian federal privacy law — local-only architecture 
  compliant by design
- PHIPA: Ontario health privacy law — engineer controls all health 
  data, no third-party access
- HIPAA: US only, not applicable

## Research backing for pitch
- 70% of IT professionals have poor sleep quality, statistically 
  linked to burnout (PMC)
- 14% of SREs report higher stress after incidents than during 
  (SRE Report 2025, Catchpoint)
- Post-incident support drops from 55% to 44% after incident closes 
  (SRE Report 2025, Catchpoint)
- 41% of SREs often or always pressured to prioritize speed over 
  reliability (SRE Report 2025, Catchpoint)
- Operational toil rose to 30% from 25%, first rise in five years 
  (SRE Report 2025, Catchpoint)
- Average on-call engineer receives ~50 alerts/week, only 2-5% 
  require action (PagerDuty 2025)
- On-call rotations don't respect sleep cycles — sleep debt builds 
  invisible burnout (Rootly On-Call Health blog)
- 46% of individual contributors approach AI with caution — trust 
  must be earned through transparency (SRE Report 2025, Catchpoint)

## What judges do NOT want to see
- Projects we can't explain technically
- Shallow wrappers around Claude API with no added value
- Harmful applications or ethical violations
- Copy-paste solutions where we didn't maintain engineering ownership