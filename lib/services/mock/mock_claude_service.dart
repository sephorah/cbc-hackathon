import '../../models/health_signal.dart';
import '../../models/risk_level.dart';
import '../../models/work_signal.dart';

/// Issue #20: Mock Claude service for demo safety.
///
/// Returns hardcoded, realistic recommendation strings per risk level.
/// Drop-in replacement for ClaudeService — identical method signature.
/// Used when ClaudeService throws (API down, key missing, no network).
class MockClaudeService {
  Future<String> getRecommendation(
    RiskLevel riskLevel,
    WorkSignal work,
    HealthSignal health,
  ) async {
    // Simulate realistic network latency so the demo feels authentic
    await Future.delayed(const Duration(milliseconds: 800));

    switch (riskLevel) {
      case RiskLevel.low:
        return 'Your workload is manageable and sleep looks solid at '
            '${health.avgSleepHours.toStringAsFixed(1)}h average. '
            'Take 10 minutes after your shift to disconnect from Slack — '
            'it helps your brain shift out of on-call mode.';

      case RiskLevel.moderate:
        return 'With ${work.incidentCount} incidents this week and '
            '${health.avgSleepHours.toStringAsFixed(1)}h average sleep, '
            "you're carrying a moderate load. "
            'Before your next on-call shift, block 30 minutes to write down '
            'the three biggest open loops — getting them out of your head '
            'reduces cortisol and improves sleep quality.';

      case RiskLevel.high:
        return '${work.afterHoursPagesCount} after-hours pages plus '
            '${health.avgSleepHours.toStringAsFixed(1)}h sleep is a '
            'combination that builds invisible burnout fast. '
            'Flag this to your team lead today — not as a complaint, as data: '
            '${work.incidentCount} incidents in 7 days is a workload problem, '
            'not a you problem. '
            'Take your full lunch break away from screens.';

      case RiskLevel.critical:
        return 'You have had ${work.highSeverityCount} high-severity incidents, '
            '${work.afterHoursPagesCount} after-hours pages, and only '
            '${health.avgSleepHours.toStringAsFixed(1)}h average sleep — '
            'this combination is serious and you should not be carrying it alone. '
            'Tell someone on your team right now that you need coverage today. '
            'If you are struggling, please reach out: '
            'Crisis Services Canada 1-833-456-4566.';
    }
  }
}
