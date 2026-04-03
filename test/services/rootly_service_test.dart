// test/services/rootly_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:productv1/services/rootly_service.dart';

void main() {
  // Generate timezone-safe timestamps at test runtime.
  // Converting local DateTime → UTC → back to local yields the same hour,
  // so tests pass on any machine regardless of timezone offset.
  final now = DateTime.now();

  // 02:00 local time → hour=2 → always before 09:00 → after hours
  final afterHoursIso =
      DateTime(now.year, now.month, now.day, 2).toUtc().toIso8601String();

  // 12:00 local time → hour=12 → always within 09:00–18:00 → business hours
  final businessHoursIso =
      DateTime(now.year, now.month, now.day, 12).toUtc().toIso8601String();

  Map<String, dynamic> incident(String severity, String startedAt) => {
        'attributes': {
          'severity': severity,
          'started_at': startedAt,
        }
      };

  group('RootlyService.parseIncidents', () {
    test('empty list returns all-zero counts', () {
      final result = RootlyService.parseIncidents([]);
      expect(result.total, 0);
      expect(result.critical, 0);
      expect(result.high, 0);
      expect(result.afterHours, 0);
    });

    test('one critical incident during business hours', () {
      final result = RootlyService.parseIncidents([
        incident('critical', businessHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 1);
      expect(result.high, 0);
      expect(result.afterHours, 0);
    });

    test('one high incident after hours', () {
      final result = RootlyService.parseIncidents([
        incident('high', afterHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 0);
      expect(result.high, 1);
      expect(result.afterHours, 1);
    });

    test('critical after hours counts in both critical and afterHours', () {
      final result = RootlyService.parseIncidents([
        incident('critical', afterHoursIso),
      ]);
      expect(result.critical, 1);
      expect(result.afterHours, 1);
    });

    test('unknown severity counts in total only', () {
      final result = RootlyService.parseIncidents([
        incident('low', businessHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 0);
      expect(result.high, 0);
    });

    test('mixed batch: 1 critical after-hours + 2 high business-hours', () {
      final result = RootlyService.parseIncidents([
        incident('critical', afterHoursIso),
        incident('high', businessHoursIso),
        incident('high', businessHoursIso),
      ]);
      expect(result.total, 3);
      expect(result.critical, 1);
      expect(result.high, 2);
      expect(result.afterHours, 1);
    });

    test('missing started_at falls back to created_at', () {
      final result = RootlyService.parseIncidents([
        {
          'attributes': {
            'severity': 'high',
            'created_at': afterHoursIso,
            // no started_at key
          }
        }
      ]);
      expect(result.afterHours, 1);
    });

    test('missing both timestamps does not throw and does not count after-hours', () {
      final result = RootlyService.parseIncidents([
        {'attributes': {'severity': 'critical'}},
      ]);
      expect(result.total, 1);
      expect(result.critical, 1);
      expect(result.afterHours, 0);
    });
  });
}
