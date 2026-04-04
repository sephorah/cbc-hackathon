import 'package:productv1/models/health_signal.dart';
import 'package:productv1/models/risk_level.dart';
import 'package:productv1/models/work_signal.dart';
import 'package:productv1/services/health_service.dart';
import 'package:productv1/services/rootly_service.dart';
import 'package:productv1/services/claude_service.dart';
import 'package:productv1/services/mock/mock_claude_service.dart';
import 'package:productv1/services/mock/mock_health_service.dart';
import 'package:productv1/services/mock/mock_rootly_service.dart';

/// Controls whether the app uses hardcoded mock data or live services.
///
/// Defaults to true (mock mode) — safe for Linux dev, CI, and simulator.
/// To build with live services: flutter run --dart-define=USE_MOCKS=false
const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);

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

  static Future<String> getRecommendation(
    RiskLevel risk,
    WorkSignal work,
    HealthSignal health,
  ) =>
      useMocks
          ? MockClaudeService.getRecommendation(risk, work, health)
          : ClaudeService.getRecommendation(risk, work, health);
}
