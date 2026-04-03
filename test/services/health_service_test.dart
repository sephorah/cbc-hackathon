// test/services/health_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:productv1/services/health_service.dart';

HealthDataPoint _makePoint(HealthDataType type, DateTime from, DateTime to) =>
    HealthDataPoint(
      uuid: '${type.name}-${from.millisecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: 0), // overridden by constructor for sleep types
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'test-device',
      sourceId: 'com.apple.health',
      sourceName: 'Apple Watch',
    );

void main() {
  group('HealthService.aggregate', () {
    test('empty list throws HealthDataUnavailableException', () {
      expect(
        () => HealthService.aggregate([]),
        throwsA(isA<HealthDataUnavailableException>()),
      );
    });

    test('SLEEP_AWAKE only (no sleep stages) throws HealthDataUnavailableException', () {
      expect(
        () => HealthService.aggregate([
          _makePoint(HealthDataType.SLEEP_AWAKE,
              DateTime(2026, 4, 3, 2, 0), DateTime(2026, 4, 3, 2, 15)),
        ]),
        throwsA(isA<HealthDataUnavailableException>()),
      );
    });

    test('SLEEP_ASLEEP 7h → totalSleepDuration=7h, fragmentationCount=null', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 6, 0)),
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 7));
      expect(signal.fragmentationCount, isNull);
    });

    test('all four sleep stages summed: 3h LIGHT + 2h DEEP + 1h REM + 30m ASLEEP = 6h30m', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_LIGHT,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 2, 0)),  // 3h
        _makePoint(HealthDataType.SLEEP_DEEP,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 4, 0)),  // 2h
        _makePoint(HealthDataType.SLEEP_REM,
            DateTime(2026, 4, 3,  4, 0), DateTime(2026, 4, 3, 5, 0)),  // 1h
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 3,  5, 0), DateTime(2026, 4, 3, 5, 30)), // 30m
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 6, minutes: 30));
    });

    test('fragmentationCount equals the count of distinct SLEEP_AWAKE points', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 7, 0)),
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 2, 15)),
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  4, 0), DateTime(2026, 4, 3, 4, 10)),
      ]);
      expect(signal.fragmentationCount, 2);
    });

    test('SLEEP_AWAKE does not contribute to totalSleepDuration', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 23, 0), DateTime(2026, 4, 3, 5, 0)), // 6h
        _makePoint(HealthDataType.SLEEP_AWAKE,
            DateTime(2026, 4, 3,  2, 0), DateTime(2026, 4, 3, 2, 30)), // 30m — not counted
      ]);
      expect(signal.totalSleepDuration, const Duration(hours: 6));
    });

    test('no SLEEP_AWAKE points → fragmentationCount is null', () {
      final signal = HealthService.aggregate([
        _makePoint(HealthDataType.SLEEP_ASLEEP,
            DateTime(2026, 4, 2, 22, 0), DateTime(2026, 4, 3, 6, 0)),
      ]);
      expect(signal.fragmentationCount, isNull);
    });
  });
}
