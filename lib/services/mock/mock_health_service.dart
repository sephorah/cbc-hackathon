import '../../models/health_signal.dart';

/// Issue #18: Hardcoded sleep signal for demo fallback.
///
/// Represents a stressed engineer: 5.5h average sleep over 7 days.
/// This scenario produces a HIGH or CRITICAL risk score combined with
/// the mock work signal, making the demo compelling.
class MockHealthService {
  Future<HealthSignal> fetchSleepDuration({int days = 7}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return HealthSignal(
      avgSleepHours: 5.5,
      windowDays: days,
      fetchedAt: DateTime.now(),
    );
  }
}
