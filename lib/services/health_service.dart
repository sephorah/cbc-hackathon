import '../models/health_signal.dart';

/// Reads sleep duration from Apple Watch via HealthKit.
/// Full implementation: issue #12.
class HealthService {
  Future<HealthSignal> fetchSleepDuration({int days = 7}) async {
    // TODO(issue-12): implement HealthKit integration via `health` package
    throw UnimplementedError(
      'HealthService not yet implemented — use MockHealthService for demo.',
    );
  }
}
