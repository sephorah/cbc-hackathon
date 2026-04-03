import 'package:productv1/models/health_signal.dart';
import 'package:productv1/models/risk_level.dart';
import 'package:productv1/models/work_signal.dart';
import 'package:productv1/services/health_service.dart';
import 'package:productv1/services/rootly_service.dart';
import 'package:productv1/services/mock/mock_claude_service.dart';
import 'package:productv1/services/mock/mock_health_service.dart';
import 'package:productv1/services/mock/mock_rootly_service.dart';

/// Controls whether the app uses hardcoded mock data or live services.
///
/// Defaults to true (mock mode) — safe for Linux dev, CI, and simulator.
/// To build with live services: flutter run --dart-define=USE_MOCKS=false
const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

/// Single source of service instances for the app.
///
/// All getters return Futures so callers are async-ready when live services land.
/// To swap a service, change the corresponding getter — callers are unaffected.
class ServiceLocator {
  const ServiceLocator._();

  static Future<HealthSignal> fetchHealth() =>
      useMocks ? MockHealthService.fetch() : HealthService.fetch();

  static Future<WorkSignal> fetchWork() =>
      useMocks ? MockRootlyService.fetch() : RootlyService.fetch();

  static Future<String> getRecommendation(RiskLevel risk) => useMocks
      ? MockClaudeService.getRecommendation(risk)
      : _liveClaudeNotImplemented();

  // --- Stub for live ClaudeService (replaced in issue #15) ---

  static Future<String> _liveClaudeNotImplemented() =>
      Future<String>.error(UnimplementedError(
          'ClaudeService not yet implemented — build with --dart-define=USE_MOCKS=true'));
}
