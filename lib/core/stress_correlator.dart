import '../models/health_signal.dart';
import '../models/risk_level.dart';
import '../models/work_signal.dart';
import 'constants/thresholds.dart';

/// Deterministic correlation of work + health signals into a RiskLevel.
///
/// Design rationale: explicit weighted scoring rather than AI inference so
/// every decision is auditable. Judges can ask "why CRITICAL?" and we point
/// to exact thresholds with citations in thresholds.dart.
///
/// Scoring weights:
///   Sleep deficit      → up to 40 pts  (largest: sleep is the foundation)
///   Incident volume    → up to 30 pts
///   After-hours pages  → up to 20 pts
///   High-severity      → up to 10 pts
///   On-call multiplier → × 1.2 if currently on call
///
/// Score → RiskLevel:
///   0–29  → LOW
///   30–54 → MODERATE
///   55–74 → HIGH
///   75+   → CRITICAL
class StressCorrelator {
  static RiskLevel compute(WorkSignal work, HealthSignal health) {
    double score = 0;

    // --- Sleep component (0–40 pts) ---
    // < 5h → 40 pts (critical deficit)
    // 5–7h → linear 0–25 pts (moderate to severe deficit)
    // ≥ 7h → 0 pts (optimal)
    if (health.avgSleepHours < Thresholds.sleepCriticalMin) {
      score += 40;
    } else if (health.avgSleepHours < Thresholds.sleepOptimalMin) {
      final deficit =
          Thresholds.sleepOptimalMin - health.avgSleepHours;
      final window =
          Thresholds.sleepOptimalMin - Thresholds.sleepCriticalMin;
      score += (deficit / window) * 25;
    }

    // --- Incident volume component (0–30 pts) ---
    if (work.incidentCount >= Thresholds.incidentCritical) {
      score += 30;
    } else if (work.incidentCount >= Thresholds.incidentHigh) {
      score += 20;
    } else if (work.incidentCount >= Thresholds.incidentModerate) {
      score += 10;
    }

    // --- After-hours disruption component (0–20 pts) ---
    if (work.afterHoursPagesCount >= Thresholds.afterHoursCritical) {
      score += 20;
    } else if (work.afterHoursPagesCount >= Thresholds.afterHoursModerate) {
      score += 10;
    }

    // --- High-severity incidents component (0–10 pts) ---
    if (work.highSeverityCount >= Thresholds.highSeverityCritical) {
      score += 10;
    } else if (work.highSeverityCount >= Thresholds.highSeverityModerate) {
      score += 5;
    }

    // --- On-call multiplier ---
    // Being on call right now amplifies all stress signals by 20%.
    // Rationale: on-call engineers carry background cognitive load even
    // when not actively paged — sleep quality degrades even without pages.
    if (work.isCurrentlyOnCall) {
      score *= 1.2;
    }

    // --- Map score to RiskLevel ---
    if (score >= Thresholds.scoreCritical) return RiskLevel.critical;
    if (score >= Thresholds.scoreHigh) return RiskLevel.high;
    if (score >= Thresholds.scoreModerate) return RiskLevel.moderate;
    return RiskLevel.low;
  }
}
