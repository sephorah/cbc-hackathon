import 'package:oncallhelper/models/risk_level.dart';

/// Drop-in stand-in for the real ClaudeService (issue #15).
///
/// Returns hardcoded SRE-specific recommendation strings per risk level.
/// The critical string MUST include a human resource link — non-negotiable
/// ethical requirement (issue #24, #29).
class MockClaudeService {
  const MockClaudeService._();

  static String getRecommendation(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low:
        return 'Your signals look balanced this week — sleep is solid and the incident '
            'queue is quiet. Good time to recharge before the next rotation.';
      case RiskLevel.moderate:
        return "You're carrying some sleep debt alongside a moderate incident load. "
            'Block 30 minutes today to decompress — a short walk or a few minutes away '
            'from screens can reset your stress response before it compounds.';
      case RiskLevel.high:
        return "This has been a demanding week: active on-call, multiple incidents, and "
            "disrupted sleep. Your body is running a deficit. Protect tonight's sleep as "
            'a priority — even one full night significantly restores cognitive function. '
            'Consider flagging your load to your team lead if the pace continues.';
      case RiskLevel.critical:
        return 'Your signals indicate a high-stress week with significant sleep disruption. '
            'This level of sustained load carries real burnout risk. Please reach out to a '
            'trusted colleague, your manager, or a professional resource. If you\'re feeling '
            'overwhelmed, the Employee Assistance Program (EAP) or Crisis Services Canada '
            '(1-833-456-4566) are available 24/7. You don\'t have to manage this alone.';
    }
  }
}
