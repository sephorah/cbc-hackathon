/// Incident and on-call data fetched from Rootly MCP.
class WorkSignal {
  /// Total incidents in the past 7 days.
  final int incidentCount;

  /// Pages received outside 9am–6pm in the past 7 days.
  final int afterHoursPagesCount;

  /// P0/P1 (high-severity) incidents in the past 7 days.
  final int highSeverityCount;

  /// Whether the engineer is currently on the active on-call rotation.
  final bool isCurrentlyOnCall;

  final DateTime fetchedAt;

  const WorkSignal({
    required this.incidentCount,
    required this.afterHoursPagesCount,
    required this.highSeverityCount,
    required this.isCurrentlyOnCall,
    required this.fetchedAt,
  });
}
