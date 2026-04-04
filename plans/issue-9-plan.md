# Issue #9 — Implement `StressCorrelator`
*(also covers issue #10: `core/constants/thresholds.dart`)*

## What we're doing

Two files:
1. `lib/core/constants/thresholds.dart` — named constants, single source of truth
2. `lib/core/stress_correlator.dart` — static `compute(WorkSignal, HealthSignal) → RiskLevel`

These are implemented together because `StressCorrelator` has no meaning without named constants — the constants are the explainability story for judges.

---

## Why we align with Rootly's scoring methodology

Rootly's open-source on-call-health repo uses a validated, research-backed burnout model. We adopt their 65/35 weighting (sleep/recovery 65%, work burden 35%) and their exact 0–10 risk thresholds.

**Evidence for 65/35 from their demo data** (`https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/mock_data_helpers/mock_analysis_data.json`):

| Member | Incidents | After-hours | OCH Score | Risk |
|--------|-----------|-------------|-----------|------|
| Marcus Thompson | 27 | 25.9% | 94.06 | High |
| Maya Fernandez | 28 | 7.1% | 66.75 | High |
| Jamal Williams | 11 | 0% | 54.24 | Moderate |

Marcus and Maya have nearly identical incident counts — but Marcus scores 94 vs Maya's 67 purely because of after-hours activity (25.9% vs 7.1%). OnCallBalance patterns, not incident count, drive the score. This directly justifies 65% weight on the sleep/recovery side.

**Where we differ:** Rootly proxies sleep from after-hours incident disruption — they have no real sleep data. We plug in actual HealthKit `totalSleepDuration` and `fragmentationCount`. Same model, better data.

**Known simplification:** In Rootly's model, after-hours activity is a personal burnout factor (weight 0.462 within the 65% dimension) — not a work factor. We place it on the work side (35%) because shifting it to the personal side would require normalizing it separately to prevent it from dominating the sleep score (after-hours counts are unbounded; sleep points are capped at 8). The 65/35 split and all other thresholds are preserved verbatim. Judge answer if asked: *"Rootly treats after-hours as a personal burnout signal — we kept it on the work side for simplicity since real sleep data already fills the personal dimension."*

---

## How to explain the score to judges (plain language)

### "How do you correlate work and health metrics? Show me the formula."

The formula has four steps:

**Step 1 — Count what actually causes burnout on the work side.**
Not all incidents are equal. A critical (SEV0) incident at 3am is far more damaging than a low-severity ticket during business hours. So we score each incident by type:
- Each critical incident (SEV0): +5 points
- Each high incident (SEV1): +2 points
- Each after-hours incident (any severity, outside 09:00–18:00): +2 points
- Being on-call at all, even with zero incidents: +2 points flat

We do **not** count total incidents. Rootly's own data shows two engineers with 27 vs 28 incidents scored 94 vs 67 — the difference was entirely that one had 25.9% after-hours vs 7.1%. Raw count is noise.

**Step 2 — Score sleep deficit.**
We use the NSF adult sleep recommendation (7–9h) and Van Dongen et al. 2003 (below 5h = cognitive impairment equivalent to 24h awake):
- 7h or more: 0 points (adequate recovery)
- 6–7h: +1 point (mild deficit)
- 5–6h: +3 points (significant deficit)
- Under 5h: +6 points (severe — equivalent to pulling an all-nighter)

The scale is intentionally non-linear: the cognitive cost of sleep loss accelerates sharply below 6h (Van Dongen et al. 2003). Going from 7h to 6h has a small effect; going from 6h to 5h has a much larger one; below 5h is the cliff.

If the Apple Watch was worn, we add fragmentation (awakenings):
- 5+ awakenings: +2 points (severely fragmented)
- 3–4 awakenings: +1 point (mildly fragmented)

**Step 3 — Normalize both scores to the same 0–10 scale.**
The work score and sleep score use different raw units. To combine them fairly, we scale each to 0–10:
- Work: divide by 12 (the worst realistic scenario: 2 critical incidents + on-call = 12 raw points), multiply by 10
- Sleep: divide by 8 (the worst case: under 5h + 5+ awakenings = 8 raw points), multiply by 10

Both scores now live on the same scale. A 10/10 work score and a 10/10 sleep score are equally "full stress" in their respective dimensions.

**Step 4 — Combine with 65/35 weighting.**
```
combined = sleepScore × 0.65 + workScore × 0.35
```
Sleep/recovery gets 65% of the weight, work burden gets 35%. This reflects Rootly's core finding: it is not the number of incidents that predicts burnout — it is whether you recovered from them. An engineer who handles 3 critical incidents but sleeps 8h scores moderate. An engineer who handles 1 critical incident but slept 4h scores high.

**Final step — Map combined score to RiskLevel.**
Thresholds taken directly from Rootly's `burnout_config.py RISK_THRESHOLDS`:
- 7.5–10 → CRITICAL
- 5.5–7.5 → HIGH
- 3.0–5.5 → MODERATE
- 0–3.0 → LOW

---

### "Who decided the thresholds and why?"

Three sources, all citable:

| Threshold | Source |
|-----------|--------|
| `criticalCount × 5`, `highCount × 2` | Rootly `burnout_config.py`: SEV0=15.0, SEV1=12.0 are internal severity weights (not OCH scores). Both values are judgment calls: SEV0 carries a "PTSD risk" comment justifying strong separation; critical is intentionally 2.5× higher than high |
| `afterHoursCount × 2` | Rootly `och_config.py`: after-hours activity weight = 0.462, the single highest-weighted personal burnout factor in their model. The ×2 is a judgment call based on that signal |
| `isOnCall + 2` | Rootly `burnout_config.py`: on-call base stress weekly_rotation = 20.0. The +2 is a judgment call based on that signal |
| Sleep duration thresholds (7h, 6h, 5h) | National Sleep Foundation adult recommendation + Van Dongen et al. 2003 |
| Risk cutoffs (3.0 / 5.5 / 7.5) | Rootly `burnout_config.py RISK_THRESHOLDS`, verbatim |
| 65/35 weighting | Rootly `burnout_config.py OCH_WEIGHTS`: personal_burnout=0.65, work_related_burnout=0.35, explicitly in source |

---

### "Why is `isOnCall` a flat +2 and not a multiplier?"

Being on-call is a constant background stressor regardless of whether incidents happen. You sleep with your phone, you stay alert, your rest quality drops even on quiet nights. Rootly assigns a base stress cost to weekly rotation (`ON_CALL_BURDEN.base_stress.weekly_rotation = 20.0`) in their config. The +2 is our judgment call based on that signal. It does not multiply — it adds — because it represents the ambient anxiety of availability, not the impact of actual incidents.

### "Why do you ignore total incident count?"

Because Rootly's data proves it is not predictive on its own. See Marcus vs Maya above. What matters is severity (did it require real cognitive load?) and timing (did it disrupt recovery?). A busy day of low-severity tickets during business hours should not push an engineer toward burnout — and it doesn't in our model.

### "What if the Apple Watch wasn't worn?"

`totalSleepDuration` can come from multiple sources — Apple Watch, iPhone motion sensors, or manual input. The `health` package aggregates all available sources, so sleep duration is available even without a watch.

`fragmentationCount` (awakening count) is watch-specific and is nullable. If it is null — whether because the watch wasn't worn or because the data source doesn't provide it — we skip the fragmentation penalty and score on duration alone. The model degrades gracefully: less precise on sleep quality, but not broken.

---

## Algorithm

### Step 1: Raw work score

```
rawWork = criticalCount × 5
        + highCount      × 2
        + afterHoursCount × 2
        + (isOnCall ? 2 : 0)
```

| Signal | Weight | Derivation |
|--------|--------|------------|
| `criticalCount` | ×5 | `SEV0 = 15.0` is an internal severity weight in Rootly's incident scoring, not a final OCH score — `convert_och_to_risk_scale` does not apply. The value 5 is a judgment call: SEV0 is the highest-weighted severity and carries a "PTSD risk" comment in source, justifying strong separation |
| `highCount` | ×2 | Same — `SEV1 = 12.0` is an internal weight, not an OCH score. The value 2 is a judgment call: SEV1 is meaningfully lower than SEV0 (12 vs 15), so critical is intentionally weighted 2.5× higher |
| `afterHoursCount` | ×2 | `och_config.py`: `after_hours_activity.weight = 0.462` is the highest-weighted personal burnout factor in Rootly's model. The ×2 is our own judgment call based on that signal — not mathematically derived from 0.462 |
| `isOnCall` | +2 | `ON_CALL_BURDEN.base_stress.weekly_rotation = 20.0` — Rootly assigns a meaningful base stress cost to being on weekly rotation. The +2 is a judgment call reflecting that signal; `convert_och_to_risk_scale` only applies to final OCH scores, not intermediate component values |

`totalIncidents` is not weighted — only the high-stress severity bands matter.

Sources:

- `burnout_config.py` (severity weights, on-call burden, OCH↔risk conversion function, risk thresholds): https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/burnout_config.py
- `och_config.py` (after-hours as top personal burnout factor, weight = 0.462): https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/och_config.py

### Step 2: Raw sleep score

Rootly proxies sleep from incident disruption. We use real HealthKit data in the same slot.

**Duration** (NSF adult sleep recommendation: 7–9h; Van Dongen et al. 2003 for < 5h):

| Sleep duration | Points |
|----------------|--------|
| < 5h | 6 |
| 5–6h | 3 |
| 6–7h | 1 |
| ≥ 7h | 0 |

**Fragmentation** (only if `fragmentationCount != null` — awakening data available):

| Awakenings | Points |
|------------|--------|
| ≥ 5 | +2 |
| 3–4 | +1 |
| < 3 | 0 |

Note: polysomnography studies show healthy adults experience ~5 brief arousals per night, but most last under 10 seconds and are not remembered (AASM; Journal of Clinical Sleep Medicine reference norms). Apple Watch does not detect micro-arousals — it detects sustained wake periods requiring ~4–5 minutes of continuous wakefulness to register. So `fragmentationCount` counts meaningful, disruptive awakenings only. < 3 sustained awakenings is normal; 3–4 is mildly elevated; 5+ is clinically significant fragmentation.

Sources:
- [Reference Data for Polysomnography-Measured and Subjective Sleep in Healthy Adults — Journal of Clinical Sleep Medicine](https://jcsm.aasm.org/doi/10.5664/jcsm.7036)
- [EEG Arousal Norms by Age — PMC/NIH](https://pmc.ncbi.nlm.nih.gov/articles/PMC2564772/)
- [Impact of Sleep Fragmentation on Cognition and Fatigue — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC9740245/)
- [Minimum duration of actigraphy-defined nocturnal awakenings necessary for morning recall — PubMed](https://pubmed.ncbi.nlm.nih.gov/23746600/)

### Step 3: Normalize both to 0–10

Both raw scores use different units and ranges. Normalization brings them onto the same 0–10 scale so they can be combined fairly with 65/35 weighting.

```
workScaleMax  = 12.0   // normalization ceiling for work score
sleepScaleMax =  8.0   // normalization ceiling for sleep score

normalizedWork  = clamp(rawWork  / workScaleMax,  0.0, 1.0) × 10
normalizedSleep = clamp(rawSleep / sleepScaleMax, 0.0, 1.0) × 10
```

**workScaleMax = 12.0**
Defined as the realistic worst-case work scenario: 2 critical incidents (2×5=10) + on-call (+2) = 12.
Any rawWork ≥ 12 is clamped to 10/10 — meaning "this bad or worse = full work stress."
2 critical was chosen over 3 because SEV0 incidents are extremely rare in practice (Rootly's mock org had only 3 SEV0 across 45 engineers over 30 days — less than 1 per engineer per month). 2 critical in a single window is already a severe scenario. The ceiling is a normalization anchor, not a cap — 3 critical would clamp to 10/10 anyway via the clamp.

**sleepScaleMax = 8.0**
Defined as the worst possible sleep score: severe duration deficit (<5h = 6 points) + severe fragmentation (≥5 awakenings = 2 points) = 8.
Any rawSleep ≥ 8 is clamped to 10/10 — meaning "this bad or worse = full sleep stress."

### Step 4: Combine with 65/35 → RiskLevel

```
combined = normalizedSleep × 0.65 + normalizedWork × 0.35
```

Thresholds directly from `burnout_config.py` `RISK_THRESHOLDS`:

```
combined ≥ 7.5 → critical
combined ≥ 5.5 → high
combined ≥ 3.0 → moderate
combined <  3.0 → low
```

### Worked examples (for judge demo)

| Scenario | rawWork | rawSleep | normWork | normSleep | combined | Level |
|----------|---------|----------|----------|-----------|---------|-------|
| Quiet week, slept 8h | 0 | 0 | 0.0 | 0.0 | 0.0 | low |
| Slept 4h, quiet week | 0 | 6 | 0.0 | 7.5 | 4.9 | moderate |
| Not on-call, 2 high, 2 after-hours, slept 5.5h | 8 | 3 | 6.7 | 3.75 | 4.8 | moderate |
| On-call, 1 critical, 2 after-hours, slept 5.5h | 11 | 3 | 9.2 | 3.75 | 5.7 | high |
| On-call, 2 critical, 3 after-hours, slept 4.5h | 18 | 6 | 10.0 | 7.5 | 8.4 | critical |
| 3 critical, slept 8h | 15 | 0 | 10.0 | 0.0 | 3.5 | moderate |

**Reading the examples against Rootly's philosophy:**

- **Last row (3 critical, slept 8h → moderate)** is the most important. 3 SEV0 incidents with full recovery = only moderate risk. OnCallBalance is what prevents burnout, not the absence of incidents. This is Rootly's core finding — use this row if a judge asks "show me the formula."

- **Row 2 (no incidents, slept 4h → moderate, 4.9)** shows that sleep deprivation alone drives risk. Even a quiet on-call week accumulates burnout if you're not recovering. This is the 65% sleep weight working as intended.

- **Row 2 vs Row 3** — no incidents + 4h sleep (4.9) scores nearly the same as a significant work week + 5.5h sleep (4.8). A judge may push back: *"you score almost as high doing nothing as having a busy week?"* The answer: yes, because 4h sleep is severe deprivation regardless of cause. Defend it with the 65/35 weighting and Van Dongen et al. 2003.

- **Row 3 vs Row 4** — same sleep, same after-hours count, but adding on-call + critical pushes moderate → high. Shows severity and on-call status matter, not raw volume.

---

## Files to create

### `lib/core/constants/thresholds.dart`

```dart
/// Named threshold constants for StressCorrelator.
///
/// Work signal weights grounded in Rootly's open-source on-call-health repo:
///
/// - pointsPerCritical=5, pointsPerHigh=2:
///   https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/burnout_config.py#L74
///   SEV0=15.0, SEV1=12.0 are internal severity weights in Rootly's incident
///   scoring, not final OCH scores. They cannot be converted via convert_och_to_risk_scale.
///   The values 5 and 2 are judgment calls: SEV0 is weighted higher than SEV1 (15 vs 12),
///   and the "SEV0/SEV1=PTSD risk" comment justifies giving critical incidents
///   significantly stronger weight. The specific values 5 and 2 are our own choice.
///
/// - pointsPerAfterHours=2:
///   https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/och_config.py#L49
///   after_hours_activity.weight=0.462 — highest-weighted personal burnout factor.
///   The value 2 is a judgment call based on that signal; not derived from 0.462.
///
/// - pointsOnCall=2:
///   https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/burnout_config.py#L90
///   ON_CALL_BURDEN base_stress weekly_rotation=20.0 — Rootly assigns a meaningful
///   base stress cost to being on weekly rotation. The value 2 is a judgment call
///   reflecting that signal; convert_och_to_risk_scale only applies to final OCH
///   scores, not intermediate component values like this one.
///
/// - weightSleep=0.65, weightWork=0.35:
///   https://github.com/Rootly-AI-Labs/on-call-health/blob/b14b9263c3ea3907d867edca7e0074aededf85f2/backend/app/core/burnout_config.py#L20
///   OCH_WEIGHTS: personal_burnout=0.65, work_related_burnout=0.35. Explicitly in source.
///
/// - scoreCritical/High/Moderate:
///   Same file, RISK_THRESHOLDS on 0–10 scale.
///
/// Sleep thresholds from published research:
/// - NSF adult sleep recommendation: 7–9h
/// - Van Dongen et al. 2003: < 5h ≈ cognitive impairment equivalent to 24h awake
///
/// Fragmentation thresholds (fragmentationSevere=5, fragmentationMild=3):
///   Apple Watch detects sustained wake periods (~4–5 min), not micro-arousals.
///   < 3 = normal; 3–4 = mildly elevated; 5+ = clinically significant.
///   Sources: https://jcsm.aasm.org/doi/10.5664/jcsm.7036
///            https://pmc.ncbi.nlm.nih.gov/articles/PMC2564772/
class Thresholds {
  Thresholds._();

  // --- Sleep duration thresholds ---
  static const Duration sleepAdequate = Duration(hours: 7);
  static const Duration sleepMild = Duration(hours: 6);
  static const Duration sleepSevere = Duration(hours: 5);

  // --- Fragmentation thresholds (awakenings per night) ---
  static const int fragmentationSevere = 5;
  static const int fragmentationMild = 3;

  // --- Work signal weights (raw, before normalization) ---
  static const int pointsPerCritical = 5;
  static const int pointsPerHigh = 2;
  static const int pointsPerAfterHours = 2;
  static const int pointsOnCall = 2;

  // --- Normalization scale maxima ("full stress" scenario) ---
  static const double workScaleMax = 12.0;   // 2 critical + on-call
  static const double sleepScaleMax = 8.0;   // severe duration + severe fragmentation

  // --- Sleep deficit scores (raw) ---
  static const int sleepScoreSevere = 6;
  static const int sleepScoreSignificant = 3;
  static const int sleepScoreMild = 1;
  static const int fragmentationScoreSevere = 2;
  static const int fragmentationScoreMild = 1;

  // --- OCH dimension weights (Rootly methodology) ---
  static const double weightSleep = 0.65;
  static const double weightWork = 0.35;

  // --- Risk level cutoffs on 0–10 scale (burnout_config.py RISK_THRESHOLDS) ---
  static const double scoreCritical = 7.5;
  static const double scoreHigh = 5.5;
  static const double scoreModerate = 3.0;
}
```

### `lib/core/stress_correlator.dart`

```dart
import '../models/health_signal.dart';
import '../models/work_signal.dart';
import '../models/risk_level.dart';
import 'constants/thresholds.dart';

/// Deterministic burnout-risk correlator.
///
/// Follows Rootly's OCH model: work and sleep scores are normalized to 0–10,
/// combined with 65/35 weighting (sleep/recovery at 65%, work burden at 35%),
/// and compared against Rootly's RISK_THRESHOLDS. No AI involved —
/// ClaudeService receives this result and generates natural language only.
class StressCorrelator {
  const StressCorrelator._();

  static RiskLevel compute(WorkSignal work, HealthSignal health) {
    final double normWork = _normalizedWorkScore(work);
    final double normSleep = _normalizedSleepScore(health);
    final double combined =
        normSleep * Thresholds.weightSleep + normWork * Thresholds.weightWork;

    if (combined >= Thresholds.scoreCritical) return RiskLevel.critical;
    if (combined >= Thresholds.scoreHigh) return RiskLevel.high;
    if (combined >= Thresholds.scoreModerate) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  static double _normalizedWorkScore(WorkSignal w) {
    final int raw =
        w.criticalCount * Thresholds.pointsPerCritical +
        w.highCount * Thresholds.pointsPerHigh +
        w.afterHoursCount * Thresholds.pointsPerAfterHours +
        (w.isOnCall ? Thresholds.pointsOnCall : 0);
    return (raw / Thresholds.workScaleMax).clamp(0.0, 1.0) * 10.0;
  }

  static double _normalizedSleepScore(HealthSignal h) {
    int raw = 0;

    if (h.totalSleepDuration < Thresholds.sleepSevere) {
      raw += Thresholds.sleepScoreSevere;
    } else if (h.totalSleepDuration < Thresholds.sleepMild) {
      raw += Thresholds.sleepScoreSignificant;
    } else if (h.totalSleepDuration < Thresholds.sleepAdequate) {
      raw += Thresholds.sleepScoreMild;
    }

    final frag = h.fragmentationCount;
    if (frag != null) {
      if (frag >= Thresholds.fragmentationSevere) {
        raw += Thresholds.fragmentationScoreSevere;
      } else if (frag >= Thresholds.fragmentationMild) {
        raw += Thresholds.fragmentationScoreMild;
      }
    }

    return (raw / Thresholds.sleepScaleMax).clamp(0.0, 1.0) * 10.0;
  }
}
```

---

## What this does NOT cover

- Unit tests — issue #11
- Using the result to call Claude — issue #15
- Mock data for demos — issues #18–#19

## Verification

```bash
flutter analyze
```

Both files have no external dependencies beyond the three model files already committed.
