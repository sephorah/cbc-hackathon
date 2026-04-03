class HealthSignal {
  final DateTime date;
  final Duration totalSleepDuration;

  /// Number of AWAKE segments detected within the sleep window.
  /// Null means the Apple Watch was not worn — data unavailable, not zero awakenings.
  final int? fragmentationCount;

  const HealthSignal({
    required this.date,
    required this.totalSleepDuration,
    this.fragmentationCount,
  });
}
