import 'package:productv1/models/work_signal.dart';

/// Drop-in stand-in for the real RootlyService (issues #13, #14).
///
/// Returns a hardcoded signal representing a stressed on-call month:
/// - 1 critical incident (5 pts), 2 high (4 pts), 2 after-hours (4 pts), on-call (2 pts)
/// - rawWork = 15 → (15/12) clamped to 1.0 → normWork = 10
///
/// Combined with MockHealthService (normSleep=5.0):
///   combined = 5.0 × 0.65 + 10 × 0.35 = 6.75 → RiskLevel.high
class MockRootlyService {
  const MockRootlyService._();

  static Future<WorkSignal> fetch() async {
    final now = DateTime.now();
    return WorkSignal(
      windowStart: now.subtract(const Duration(days: 30)),
      windowEnd: now,
      totalIncidents: 3,
      criticalCount: 1,
      highCount: 2,
      afterHoursCount: 2,
      isOnCall: true,
    );
  }
}
