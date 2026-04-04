/// Output of StressCorrelator. Ordered low → critical so values can be
/// compared with >= and <= (e.g. riskLevel >= RiskLevel.high).
enum RiskLevel { low, moderate, high, critical }

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
