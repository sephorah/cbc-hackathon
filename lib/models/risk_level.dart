/// Risk level computed by StressCorrelator from work + health signals.
/// Claude receives this as an input — it never decides the level itself.
enum RiskLevel {
  low,
  moderate,
  high,
  critical,
}

extension RiskLevelLabel on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.moderate:
        return 'Moderate';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }
}
