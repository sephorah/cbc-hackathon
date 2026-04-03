/// Sleep data fetched from Apple Watch via HealthKit.
class HealthSignal {
  /// Average sleep duration per night over [windowDays] days.
  final double avgSleepHours;

  /// Number of days sampled (default 7).
  final int windowDays;

  final DateTime fetchedAt;

  const HealthSignal({
    required this.avgSleepHours,
    required this.windowDays,
    required this.fetchedAt,
  });
}
