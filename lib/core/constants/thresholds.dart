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
/// Sleep deficit scores are non-linear (0/1/3/6):
///   The cognitive cost of sleep loss accelerates below 6h. 7→6h = small penalty (1),
///   6→5h = larger penalty (3), below 5h = cliff (6). Linear spacing would underweight
///   the most dangerous range.
///   - NSF adult sleep recommendation: 7–9h
///   - Van Dongen et al. 2003: < 5h ≈ cognitive impairment equivalent to 24h awake
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
  static const double workScaleMax = 12.0; // 2 critical + on-call
  static const double sleepScaleMax = 8.0; // severe duration + severe fragmentation

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
