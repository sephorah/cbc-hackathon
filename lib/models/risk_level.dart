/// Output of StressCorrelator. Ordered low → critical so values can be
/// compared with >= and <= (e.g. riskLevel >= RiskLevel.high).
enum RiskLevel { low, moderate, high, critical }
