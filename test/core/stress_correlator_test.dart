import 'package:flutter_test/flutter_test.dart';
import 'package:productv1/core/stress_correlator.dart';
import 'package:productv1/models/health_signal.dart';
import 'package:productv1/models/risk_level.dart';
import 'package:productv1/models/work_signal.dart';

void main() {
  WorkSignal work({
    int critical = 0,
    int high = 0,
    int afterHours = 0,
    bool onCall = false,
  }) =>
      WorkSignal(
        windowStart: DateTime(2026, 4, 1),
        windowEnd: DateTime(2026, 4, 7),
        totalIncidents: critical + high,
        criticalCount: critical,
        highCount: high,
        afterHoursCount: afterHours,
        isOnCall: onCall,
      );

  HealthSignal health({
    required Duration sleep,
    int? fragmentation,
  }) =>
      HealthSignal(
        date: DateTime(2026, 4, 7),
        totalSleepDuration: sleep,
        fragmentationCount: fragmentation,
      );

  group('RiskLevel.low', () {
    test('quiet week, 8h sleep', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 8))),
        RiskLevel.low,
      );
    });

    test('exactly 7h sleep, no incidents', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 7))),
        RiskLevel.low,
      );
    });
  });

  group('RiskLevel.moderate', () {
    test('severe sleep deficit alone (4h, no incidents) — combined=4.875', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 4))),
        RiskLevel.moderate,
      );
    });

    test('high work load with full recovery (3 critical, 8h) — combined=3.5', () {
      // rawWork=15 → (15/12) clamped to 1.0 → normWork=10, rawSleep=0
      // combined = 0×0.65 + 10×0.35 = 3.5
      expect(
        StressCorrelator.compute(
          work(critical: 3),
          health(sleep: const Duration(hours: 8)),
        ),
        RiskLevel.moderate,
      );
    });

    test('moderate work + moderate sleep deficit (2 high, 2 after-hours, 5.5h) — combined=4.77', () {
      // rawWork=8, rawSleep=3 → normWork=6.67, normSleep=3.75
      // combined = 3.75×0.65 + 6.67×0.35 = 4.77
      expect(
        StressCorrelator.compute(
          work(high: 2, afterHours: 2),
          health(sleep: const Duration(hours: 5, minutes: 30)),
        ),
        RiskLevel.moderate,
      );
    });
  });

  group('RiskLevel.high', () {
    test('on-call + 1 critical + 2 after-hours, 5.5h sleep — combined=5.65', () {
      // rawWork=11, rawSleep=3 → normWork=9.17, normSleep=3.75
      // combined = 3.75×0.65 + 9.17×0.35 = 5.65
      expect(
        StressCorrelator.compute(
          work(critical: 1, afterHours: 2, onCall: true),
          health(sleep: const Duration(hours: 5, minutes: 30)),
        ),
        RiskLevel.high,
      );
    });
  });

  group('RiskLevel.critical', () {
    test('on-call + 2 critical + 3 after-hours, 4.5h sleep — combined=8.375', () {
      // rawWork=18 → clamped → normWork=10, rawSleep=6 → normSleep=7.5
      // combined = 7.5×0.65 + 10×0.35 = 8.375
      expect(
        StressCorrelator.compute(
          work(critical: 2, afterHours: 3, onCall: true),
          health(sleep: const Duration(hours: 4, minutes: 30)),
        ),
        RiskLevel.critical,
      );
    });
  });

  group('sleep duration boundaries', () {
    test('exactly 7h → 0 points (adequate)', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 7))),
        RiskLevel.low,
      );
    });

    test('6h59m → 1 point (mild)', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 6, minutes: 59))),
        RiskLevel.low,
      );
    });

    test('exactly 6h → 1 point (mild, not significant — 6h is not < sleepMild(6h))', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 6))),
        RiskLevel.low,
      );
    });

    test('5h59m → 3 points (significant)', () {
      // normSleep=3.75, combined=2.44 → low (below moderate threshold of 3.0)
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 5, minutes: 59))),
        RiskLevel.low,
      );
    });

    test('exactly 5h → 3 points (significant, not severe — 5h is not < sleepSevere(5h))', () {
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 5))),
        RiskLevel.low,
      );
    });

    test('4h59m → 6 points (severe) → moderate with no work', () {
      // normSleep=7.5, combined=4.875 → moderate
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 4, minutes: 59))),
        RiskLevel.moderate,
      );
    });
  });

  group('fragmentation (sleep fixed at 5h30m, rawSleep=3 before fragmentation)', () {
    test('null → no fragmentation penalty', () {
      // combined=2.44 → low
      expect(
        StressCorrelator.compute(work(), health(sleep: const Duration(hours: 5, minutes: 30))),
        RiskLevel.low,
      );
    });

    test('fragmentation=2 → no penalty (below mild threshold of 3)', () {
      expect(
        StressCorrelator.compute(
          work(),
          health(sleep: const Duration(hours: 5, minutes: 30), fragmentation: 2),
        ),
        RiskLevel.low,
      );
    });

    test('fragmentation=3 → +1 point (mild) — combined=3.25 → moderate', () {
      // rawSleep=4, normSleep=5.0, combined=5.0×0.65=3.25
      expect(
        StressCorrelator.compute(
          work(),
          health(sleep: const Duration(hours: 5, minutes: 30), fragmentation: 3),
        ),
        RiskLevel.moderate,
      );
    });

    test('fragmentation=4 → +1 point (mild)', () {
      expect(
        StressCorrelator.compute(
          work(),
          health(sleep: const Duration(hours: 5, minutes: 30), fragmentation: 4),
        ),
        RiskLevel.moderate,
      );
    });

    test('fragmentation=5 → +2 points (severe) — combined=4.06 → moderate', () {
      // rawSleep=5, normSleep=6.25, combined=6.25×0.65=4.06
      expect(
        StressCorrelator.compute(
          work(),
          health(sleep: const Duration(hours: 5, minutes: 30), fragmentation: 5),
        ),
        RiskLevel.moderate,
      );
    });
  });

  group('work score clamping', () {
    test('5 critical (rawWork=25) clamped to same level as 3 critical (both moderate with 8h sleep)', () {
      final fiveCritical = StressCorrelator.compute(
        work(critical: 5),
        health(sleep: const Duration(hours: 8)),
      );
      final threeCritical = StressCorrelator.compute(
        work(critical: 3),
        health(sleep: const Duration(hours: 8)),
      );
      expect(fiveCritical, threeCritical);
      expect(fiveCritical, RiskLevel.moderate);
    });
  });

  group('isOnCall', () {
    test('on-call only, no incidents, 8h sleep → low (flat +2 is additive, not a multiplier)', () {
      // rawWork=2, normWork=1.67, combined=0.58 → low
      expect(
        StressCorrelator.compute(
          work(onCall: true),
          health(sleep: const Duration(hours: 8)),
        ),
        RiskLevel.low,
      );
    });
  });
}
