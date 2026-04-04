// lib/services/rootly_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:oncallbalance/models/work_signal.dart';

/// Counts of incidents over a time window, returned by [RootlyService.fetchIncidents].
class IncidentCounts {
  final int total;
  final int critical;
  final int high;
  final int afterHours;

  const IncidentCounts({
    required this.total,
    required this.critical,
    required this.high,
    required this.afterHours,
  });
}

/// Calls the Rootly REST API to fetch incident and on-call data for the current user.
///
/// Authentication uses [ROOTLY_API_TOKEN] from the `.env` file.
/// Base URL: https://api.rootly.com
///
/// Public entry points:
/// - [fetch] — combined call returning a [WorkSignal] (use this from ServiceLocator)
/// - [fetchIncidents] — incidents only, returns [IncidentCounts]
/// - [fetchOnCallSchedule] — on-call check only, returns bool
///
/// [parseIncidents] and [parseOnCallSchedule] are exposed for testing only.
///
/// Note: results are not paginated. For MVP the default page size (25) may
/// truncate high-volume accounts. Pagination is a V2 task.
class RootlyService {
  const RootlyService._();

  static const String _baseUrl = 'https://api.rootly.com';

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${dotenv.env['ROOTLY_API_TOKEN'] ?? ''}',
        'Content-Type': 'application/vnd.api+json',
      };

  // ---------------------------------------------------------------------------
  // Public entry points
  // ---------------------------------------------------------------------------

  /// Fetches both incidents and on-call status for the current user and
  /// assembles them into a [WorkSignal].
  ///
  /// Fetches the user ID once, then calls the incidents API and on-call check
  /// in parallel. Use this from [ServiceLocator.fetchWork].
  ///
  /// Throws [RootlyApiException] on any non-200 response.
  static Future<WorkSignal> fetch({int days = 30}) async {
    final userId = await _fetchUserId();
    final windowEnd = DateTime.now();
    final windowStart = windowEnd.subtract(Duration(days: days));

    final results = await Future.wait([
      _fetchIncidentsForUser(userId, days: days),
      _isOnCallForUser(userId),
    ]);

    final counts = results[0] as IncidentCounts;
    final isOnCall = results[1] as bool;

    return WorkSignal(
      windowStart: windowStart,
      windowEnd: windowEnd,
      totalIncidents: counts.total,
      criticalCount: counts.critical,
      highCount: counts.high,
      afterHoursCount: counts.afterHours,
      isOnCall: isOnCall,
    );
  }

  /// Fetches incidents involving the current user over the last [days] days.
  ///
  /// Returns an [IncidentCounts] with total, critical, high, and after-hours counts.
  ///
  /// Throws [RootlyApiException] on non-200 response.
  static Future<IncidentCounts> fetchIncidents({int days = 30}) async {
    final userId = await _fetchUserId();
    return _fetchIncidentsForUser(userId, days: days);
  }

  /// Returns true if the current user has an active on-call shift right now.
  ///
  /// Checks all schedules; returns true as soon as one active shift is found.
  ///
  /// Throws [RootlyApiException] on non-200 response.
  static Future<bool> fetchOnCallSchedule() async {
    final userId = await _fetchUserId();
    return _isOnCallForUser(userId);
  }

  // ---------------------------------------------------------------------------
  // Testable parsers
  // ---------------------------------------------------------------------------

  /// Parses a Rootly JSON:API [data] array into [IncidentCounts].
  ///
  /// Counts all incidents in [data] — caller is responsible for server-side
  /// filtering (e.g. `filter[user_id]`) before passing data here.
  ///
  /// Severity path: `attributes.severity.data.attributes.severity`
  /// → `"critical"|"high"|"medium"|"low"`.
  /// A plain-string severity is also accepted for test fixtures.
  @visibleForTesting
  static IncidentCounts parseIncidents(List<dynamic> data) {
    int total = 0;
    int critical = 0;
    int high = 0;
    int afterHours = 0;

    for (final item in data) {
      final itemMap = item as Map<String, dynamic>?;
      if (itemMap == null) continue;

      final attrs = itemMap['attributes'] as Map<String, dynamic>?;
      if (attrs == null) continue;

      // Severity is a JSON:API nested object in the real API:
      //   attributes.severity.data.attributes.severity → "critical"|"high"|...
      // A plain string is also handled for test fixtures.
      final severityRaw = attrs['severity'];
      final String severity;
      if (severityRaw is String) {
        severity = severityRaw;
      } else if (severityRaw is Map<String, dynamic>) {
        final sevData = severityRaw['data'] as Map<String, dynamic>?;
        final sevAttrs = sevData?['attributes'] as Map<String, dynamic>?;
        severity = (sevAttrs?['severity'] as String?) ?? '';
      } else {
        severity = '';
      }

      total++;
      if (severity == 'critical') critical++;
      if (severity == 'high') high++;

      // Prefer started_at (when the incident began) over created_at.
      final timestampStr = (attrs['started_at'] as String?) ??
          (attrs['created_at'] as String?) ??
          '';
      if (timestampStr.isNotEmpty) {
        final local = DateTime.parse(timestampStr).toLocal();
        if (local.hour < 9 || local.hour >= 18) afterHours++;
      }
    }

    return IncidentCounts(
      total: total,
      critical: critical,
      high: high,
      afterHours: afterHours,
    );
  }

  /// Returns true if any shift in [shifts] belongs to [userId].
  ///
  /// Each shift is expected to have:
  ///   `relationships.user.data.id` — the Rootly user ID.
  /// Missing or null fields are treated as non-matching (does not throw).
  @visibleForTesting
  static bool parseOnCallSchedule(List<dynamic> shifts, String userId) {
    for (final shift in shifts) {
      final rel = (shift as Map<String, dynamic>)['relationships']
          as Map<String, dynamic>?;
      final user = rel?['user'] as Map<String, dynamic>?;
      final data = user?['data'] as Map<String, dynamic>?;
      final shiftUserId = data?['id'] as String?;
      if (shiftUserId == userId) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches the current user's Rootly ID from GET /v1/users/me.
  ///
  /// Throws [RootlyApiException] on non-200 response or missing data.id.
  static Future<String> _fetchUserId() async {
    final uri = Uri.parse('$_baseUrl/v1/users/me');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw RootlyApiException(
          'GET /v1/users/me returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final id = data?['id'] as String?;
    if (id == null) {
      throw const RootlyApiException(
          'GET /v1/users/me: missing data.id in response');
    }
    return id;
  }

  /// Fetches incidents involving [userId] over the last [days] days.
  static Future<IncidentCounts> _fetchIncidentsForUser(
    String userId, {
    int days = 30,
  }) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toUtc()
        .toIso8601String();
    final uri = Uri.parse(
      '$_baseUrl/v1/incidents'
      '?filter[user_id]=$userId'
      '&filter[created_at][gte]=$since',
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw RootlyApiException(
          'GET /v1/incidents returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return parseIncidents((body['data'] as List<dynamic>?) ?? []);
  }

  /// Returns true if [userId] has an active on-call shift right now across
  /// all schedules.
  static Future<bool> _isOnCallForUser(String userId) async {
    final scheduleIds = await _fetchScheduleIds();
    for (final scheduleId in scheduleIds) {
      final shifts = await _fetchShiftsForSchedule(scheduleId);
      if (parseOnCallSchedule(shifts, userId)) return true;
    }
    return false;
  }

  /// Fetches all schedule IDs from GET /v1/schedules.
  static Future<List<String>> _fetchScheduleIds() async {
    final uri = Uri.parse('$_baseUrl/v1/schedules');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw RootlyApiException(
          'GET /v1/schedules returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((s) => ((s as Map<String, dynamic>?)?['id']) as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Fetches shifts active right now for a single [scheduleId].
  ///
  /// Queries a ±1 minute window around the current time so that shifts
  /// starting or ending right now are included.
  static Future<List<dynamic>> _fetchShiftsForSchedule(
      String scheduleId) async {
    final now = DateTime.now().toUtc();
    final from =
        now.subtract(const Duration(minutes: 1)).toIso8601String();
    final to = now.add(const Duration(minutes: 1)).toIso8601String();
    final uri = Uri.parse(
        '$_baseUrl/v1/schedules/$scheduleId/shifts?from=$from&to=$to');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw RootlyApiException(
          'GET /v1/schedules/$scheduleId/shifts returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? [];
  }
}

/// Thrown when the Rootly API returns a non-200 status.
class RootlyApiException implements Exception {
  final String message;
  const RootlyApiException(this.message);

  @override
  String toString() => 'RootlyApiException: $message';
}
