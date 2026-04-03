import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:productv1/models/work_signal.dart';

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

/// Calls the Rootly REST API to fetch incident data for the current user.
///
/// Authentication uses [ROOTLY_API_TOKEN] from the `.env` file.
/// Base URL: https://api.rootly.com
///
/// [fetchIncidents] is the public entry point. [parseIncidents] is exposed
/// for testing only — it does not make network calls.
///
/// Note: results are not paginated. For MVP (30-day window, typical SRE load)
/// the default page size (25) may truncate. Pagination is a V2 task.
class RootlyService {
  const RootlyService._();

  static const String _baseUrl = 'https://api.rootly.com';

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${dotenv.env['ROOTLY_API_TOKEN'] ?? ''}',
        'Content-Type': 'application/vnd.api+json',
      };

  /// Fetches the current user's Rootly ID.
  ///
  /// Throws [RootlyApiException] on non-200 response.
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
      throw const RootlyApiException('GET /v1/users/me: missing data.id in response');
    }
    return id;
  }

  /// Fetches incidents for the current user over the last [days] days.
  ///
  /// Returns an [IncidentCounts] with total, critical, high, and after-hours counts.
  /// After-hours = incident [started_at] (or [created_at]) outside 09:00–18:00 local time.
  ///
  /// Throws [RootlyApiException] on non-200 response.
  static Future<IncidentCounts> fetchIncidents({int days = 30}) async {
    final userId = await _fetchUserId();
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
    return parseIncidents(body['data'] as List<dynamic>);
  }

  /// Parses a Rootly JSON:API [data] array into [IncidentCounts].
  ///
  /// Each item must have an `attributes` map with optional `severity`,
  /// `started_at`, and `created_at` keys. Items without a parseable
  /// timestamp are counted in total/severity but not in afterHours.
  @visibleForTesting
  static IncidentCounts parseIncidents(List<dynamic> data) {
    int total = 0;
    int critical = 0;
    int high = 0;
    int afterHours = 0;

    for (final item in data) {
      final attrs = (item as Map<String, dynamic>)['attributes']
          as Map<String, dynamic>?;
      if (attrs == null) continue;
      final severity = attrs['severity'] as String? ?? '';

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

  /// Convenience wrapper that fetches incidents and returns a [WorkSignal].
  ///
  /// [isOnCall] defaults to false — V2 will derive this from the schedule endpoint.
  static Future<WorkSignal> fetchWorkSignal({int days = 7}) async {
    final counts = await fetchIncidents(days: days);
    final now = DateTime.now();
    return WorkSignal(
      windowStart: now.subtract(Duration(days: days)),
      windowEnd: now,
      totalIncidents: counts.total,
      criticalCount: counts.critical,
      highCount: counts.high,
      afterHoursCount: counts.afterHours,
      isOnCall: false, // V2: derive from /v1/schedules endpoint
    );
  }
}

/// Thrown when the Rootly API returns a non-200 status.
class RootlyApiException implements Exception {
  final String message;
  const RootlyApiException(this.message);

  @override
  String toString() => 'RootlyApiException: $message';
}
