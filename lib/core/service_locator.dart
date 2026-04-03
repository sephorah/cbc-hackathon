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
/// Real service getters will replace the mock branches in issues #12–15.
/// To swap a service, change the corresponding getter — callers are unaffected.
class ServiceLocator {
  const ServiceLocator._();

  static HealthSignal fetchHealth() =>
      useMocks ? MockHealthService.fetch() : _liveHealthNotImplemented();

  static WorkSignal fetchWork() =>
      useMocks ? MockRootlyService.fetch() : _liveWorkNotImplemented();

  static String getRecommendation(RiskLevel risk) => useMocks
      ? MockClaudeService.getRecommendation(risk)
      : _liveClaudeNotImplemented();

  // --- Stubs for live services (replaced in issues #12–15) ---

  static HealthSignal _liveHealthNotImplemented() =>
      throw UnimplementedError('HealthService not yet implemented — set useMocks = true');

  static WorkSignal _liveWorkNotImplemented() =>
      throw UnimplementedError('RootlyService not yet implemented — set useMocks = true');

  static String _liveClaudeNotImplemented() =>
      throw UnimplementedError('ClaudeService not yet implemented — set useMocks = true');
}
