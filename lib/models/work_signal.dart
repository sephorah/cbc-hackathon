class WorkSignal {
  final DateTime windowStart;
  final DateTime windowEnd;
  final int totalIncidents;

  /// Incidents with Rootly severity == "critical"
  final int criticalCount;

  /// Incidents with Rootly severity == "high"
  final int highCount;

  /// Incidents whose started_at fell outside 09:00–18:00 local time.
  /// Hardcoded proxy — accurate definition would derive the window from the
  /// engineer's schedule endpoint, but that's V2.
  final int afterHoursCount;

  /// Whether the engineer has an active on-call shift right now
  final bool isOnCall;

  const WorkSignal({
    required this.windowStart,
    required this.windowEnd,
    required this.totalIncidents,
    required this.criticalCount,
    required this.highCount,
    required this.afterHoursCount,
    required this.isOnCall,
  });
}
