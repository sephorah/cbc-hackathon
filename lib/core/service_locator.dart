import 'package:oncallhelper/models/health_signal.dart';
import 'package:oncallhelper/models/risk_level.dart';
import 'package:oncallhelper/models/work_signal.dart';
import 'package:oncallhelper/services/mock/mock_claude_service.dart';
import 'package:oncallhelper/services/mock/mock_health_service.dart';
import 'package:oncallhelper/services/mock/mock_rootly_service.dart';

/// Set to true to run the app with hardcoded mock data (demo safety / Linux dev).
/// Set to false once live services (issues #12–15) are implemented.
const bool useMocks = true;

/// Single source of service instances for the app.
///
/// All getters return Futures so callers are async-ready when live services land.
/// Real service getters will replace the mock branches in issues #12–15.
/// To swap a service, change the corresponding getter — callers are unaffected.
class ServiceLocator {
  const ServiceLocator._();

  static Future<HealthSignal> fetchHealth() =>
      useMocks ? MockHealthService.fetch() : _liveHealthNotImplemented();

  static Future<WorkSignal> fetchWork() =>
      useMocks ? MockRootlyService.fetch() : _liveWorkNotImplemented();

  static Future<String> getRecommendation(RiskLevel risk) => useMocks
      ? MockClaudeService.getRecommendation(risk)
      : _liveClaudeNotImplemented();

  // --- Stubs for live services (replaced in issues #12–15) ---

  static Future<HealthSignal> _liveHealthNotImplemented() =>
      Future<HealthSignal>.error(UnimplementedError('HealthService not yet implemented — set useMocks = true'));

  static Future<WorkSignal> _liveWorkNotImplemented() =>
      Future<WorkSignal>.error(UnimplementedError('RootlyService not yet implemented — set useMocks = true'));

  static Future<String> _liveClaudeNotImplemented() =>
      Future<String>.error(UnimplementedError('ClaudeService not yet implemented — set useMocks = true'));
}
