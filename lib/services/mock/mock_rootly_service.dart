import '../../models/work_signal.dart';

/// Issue #19: Hardcoded work signal for demo fallback.
///
/// Represents a high-stress SRE scenario to make the demo compelling:
///   7 incidents, 4 after-hours pages, 2 high-severity, currently on call.
/// Combined with MockHealthService (5.5h sleep), StressCorrelator
/// produces a HIGH or CRITICAL risk level.
class MockRootlyService {
  Future<WorkSignal> fetchWorkSignal() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return WorkSignal(
      incidentCount: 7,
      afterHoursPagesCount: 4,
      highSeverityCount: 2,
      isCurrentlyOnCall: true,
      fetchedAt: DateTime.now(),
    );
  }
}
