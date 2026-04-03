import 'package:oncallhelper/models/health_signal.dart';

/// Drop-in stand-in for the real HealthService (issue #12).
///
/// Returns a hardcoded signal representing a sleep-deprived on-call engineer:
/// - 5h30m sleep: significant deficit (5–6h band = 3 pts in StressCorrelator)
/// - fragmentation=3: mildly elevated, realistic for someone woken by a page
///
/// This signal produces RiskLevel.moderate on a quiet work week and escalates
/// to RiskLevel.high or RiskLevel.critical when combined with mock work data.
class MockHealthService {
  const MockHealthService._();

  static Future<HealthSignal> fetch() async => HealthSignal(
        date: DateTime.now(),
        totalSleepDuration: const Duration(hours: 5, minutes: 30),
        fragmentationCount: 3,
      );
}
