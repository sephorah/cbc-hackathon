import 'package:oncallhelper/models/health_signal.dart';
import 'package:oncallhelper/models/risk_level.dart';
import 'package:oncallhelper/models/work_signal.dart';
import 'package:oncallhelper/services/mock/mock_claude_service.dart';
import 'package:oncallhelper/services/mock/mock_health_service.dart';
import 'package:oncallhelper/services/mock/mock_rootly_service.dart';

/// Controls whether the app uses hardcoded mock data or live services.
///
/// Defaults to true (mock mode) — safe for Linux dev, CI, and simulator.
/// To build with live services: flutter run --dart-define=USE_MOCKS=false
const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

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
      Future<HealthSignal>.error(UnimplementedError('HealthService not yet implemented — build with --dart-define=USE_MOCKS=true'));

  static Future<WorkSignal> _liveWorkNotImplemented() =>
      Future<WorkSignal>.error(UnimplementedError('RootlyService not yet implemented — build with --dart-define=USE_MOCKS=true'));

  static Future<String> _liveClaudeNotImplemented() =>
      Future<String>.error(UnimplementedError('ClaudeService not yet implemented — build with --dart-define=USE_MOCKS=true'));
}
