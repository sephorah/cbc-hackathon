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
