import 'package:productv1/core/constants/crisis_resources.dart';
import 'package:productv1/models/risk_level.dart';

/// Drop-in stand-in for the real ClaudeService (issue #15).
///
/// Returns hardcoded SRE-specific recommendation strings per risk level.
/// The critical string MUST include a human resource link — non-negotiable
/// ethical requirement (issue #24, #29). Crisis text sourced from CrisisResources.
class MockClaudeService {
  const MockClaudeService._();

  static Future<String> getRecommendation(RiskLevel risk) async {
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
            'trusted colleague, your manager, or a professional resource. '
            '${CrisisResources.criticalHandoff}';
    }
  }
}
