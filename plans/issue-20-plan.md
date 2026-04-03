# Issue #20 — MockClaudeService

## What we're doing

One file: `lib/services/mock/mock_claude_service.dart`

`MockClaudeService` returns hardcoded recommendation strings, one per `RiskLevel`.
It is a drop-in stand-in for the real `ClaudeService` (issue #15), which requires the
Claude API key and a live HTTP call.

The strings must be SRE-specific (not generic wellness advice) and the critical-level
string MUST include a human resource link — this is a non-negotiable ethical requirement
from the project's ethics checklist.

---

## Recommendation strings

These are the exact strings the mock will return. They are written to look like real Claude
output so the demo notification reads naturally.

### low
```
Your signals look balanced this week — sleep is solid and the incident queue is quiet.
Good time to recharge before the next rotation.
```

### moderate
```
You're carrying some sleep debt alongside a moderate incident load. Block 30 minutes
today to decompress — a short walk or a few minutes away from screens can reset your
stress response before it compounds.
```

### high
```
This has been a demanding week: active on-call, multiple incidents, and disrupted sleep.
Your body is running a deficit. Protect tonight's sleep as a priority — even one full
night significantly restores cognitive function. Consider flagging your load to your
team lead if the pace continues.
```

### critical
```
Your signals indicate a high-stress week with significant sleep disruption. This level
of sustained load carries real burnout risk. Please reach out to a trusted colleague,
your manager, or a professional resource. If you're feeling overwhelmed, the
Employee Assistance Program (EAP) or Crisis Services Canada (1-833-456-4566) are
available 24/7. You don't have to manage this alone.
```

The critical string includes a real crisis line (Crisis Services Canada, 1-833-456-4566),
satisfying the ethical requirement for human resource handoff at critical risk.

---

## File to create

```
lib/services/mock/mock_claude_service.dart
```

```dart
import 'package:productv1/models/risk_level.dart';

class MockClaudeService {
  const MockClaudeService._();

  static String getRecommendation(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low:
        return 'Your signals look balanced this week — sleep is solid and the incident '
            'queue is quiet. Good time to recharge before the next rotation.';
      case RiskLevel.moderate:
        return 'You\'re carrying some sleep debt alongside a moderate incident load. '
            'Block 30 minutes today to decompress — a short walk or a few minutes away '
            'from screens can reset your stress response before it compounds.';
      case RiskLevel.high:
        return 'This has been a demanding week: active on-call, multiple incidents, and '
            'disrupted sleep. Your body is running a deficit. Protect tonight\'s sleep as '
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
```

---

## Verification

```bash
flutter analyze
```

No unit test needed — the method is a pure switch on an exhaustive enum.
Dart's exhaustiveness check guarantees all cases are covered at compile time.
