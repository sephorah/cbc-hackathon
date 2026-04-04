import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:health/health.dart';
import 'package:oncallbalance/models/health_signal.dart';

/// Live implementation that fetches sleep data from HealthKit.
///
/// [fetch] requests authorization, pulls [days] days of sleep data, and
/// returns a [HealthSignal] summarising the full window.
///
/// totalSleepDuration = sum of all SLEEP_ASLEEP + SLEEP_LIGHT + SLEEP_DEEP
///   + SLEEP_REM segments.
/// fragmentationCount = number of distinct SLEEP_AWAKE data points (null if none).
///
/// Throws [HealthPermissionDeniedException] if the user denies HealthKit access.
/// Throws [HealthDataUnavailableException] if no sleep stage data exists for
///   the window. Callers (ServiceLocator) fall back to MockHealthService on any
///   exception.
class HealthService {
  const HealthService._();

  static final Health _health = Health();

  /// Sleep stage types that contribute to total sleep duration.
  static const _sleepStageTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  /// All types fetched — sleep stages + awakenings.
  static const _allSleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
  ];

  // Default is 1 day (last night) so totalSleepDuration maps directly to the
  // per-night thresholds in StressCorrelator (7h adequate, 6h mild, 5h severe).
  // A 7-day sum would always exceed those thresholds and neutralise the sleep signal.
  static Future<HealthSignal> fetch({int days = 1}) async {
    await _health.configure();

    final authorized = await _health.requestAuthorization(_allSleepTypes);
    if (!authorized) throw const HealthPermissionDeniedException();

    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    final points = await _health.getHealthDataFromTypes(
      types: _allSleepTypes,
      startTime: start,
      endTime: end,
    );

    return aggregate(points);
  }

  /// Aggregates raw HealthKit sleep points into a single [HealthSignal].
  ///
  /// totalSleepDuration: sum of durations of all SLEEP_ASLEEP, SLEEP_LIGHT,
  ///   SLEEP_DEEP, and SLEEP_REM segments.
  /// fragmentationCount: count of distinct SLEEP_AWAKE data points.
  ///   Null if no SLEEP_AWAKE points exist (watch not worn or no awakenings
  ///   recorded).
  ///
  /// Throws [HealthDataUnavailableException] if [points] has no sleep stage
  ///   data.
  @visibleForTesting
  static HealthSignal aggregate(List<HealthDataPoint> points) {
    Duration totalSleep = Duration.zero;
    int awakeCount = 0;
    bool hasSleepData = false;

    for (final point in points) {
      if (_sleepStageTypes.contains(point.type)) {
        final duration = point.dateTo.difference(point.dateFrom);
        if (duration <= Duration.zero) continue; // guard against malformed HealthKit data
        totalSleep += duration;
        hasSleepData = true;
      } else if (point.type == HealthDataType.SLEEP_AWAKE) {
        awakeCount++;
      }
    }

    if (!hasSleepData) throw const HealthDataUnavailableException();

    return HealthSignal(
      date: DateTime.now(),
      totalSleepDuration: totalSleep,
      fragmentationCount: awakeCount > 0 ? awakeCount : null,
    );
  }
}

class HealthPermissionDeniedException implements Exception {
  const HealthPermissionDeniedException();
  @override
  String toString() => 'HealthKit authorization was denied by the user.';
}

class HealthDataUnavailableException implements Exception {
  const HealthDataUnavailableException();
  @override
  String toString() => 'No sleep data found in HealthKit for the requested window.';
}
