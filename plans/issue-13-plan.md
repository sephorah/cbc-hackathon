# Issue #13 — RootlyService.fetchIncidents() Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `RootlyService.fetchIncidents()` which calls the Rootly REST API to count incidents over the last 30 days (total, critical, high, after-hours) and return an `IncidentCounts` record.

**Architecture:** A static-only service class following the same pattern as `HealthService`. HTTP is called in `fetchIncidents()`; parsing is extracted into a `@visibleForTesting` static method `parseIncidents()` so it can be unit-tested without a live network. Issue #14 will add `fetchOnCallSchedule()` and combine both into a `fetch() → WorkSignal` method; `ServiceLocator` is **not** modified in this issue.

**Tech Stack:** `http` package (already in pubspec), `flutter_dotenv` (already wired), Rootly REST API `https://api.rootly.com`

---

## File map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/services/rootly_service.dart` | `RootlyService` static class + `IncidentCounts` data class + `RootlyApiException` |
| Create | `test/services/rootly_service_test.dart` | Unit tests for `parseIncidents()` |

`ServiceLocator` and `WorkSignal` are **not touched** in this issue.

---

## Task 1: Write the failing tests for `parseIncidents`

**Files:**
- Create: `test/services/rootly_service_test.dart`

`parseIncidents` takes a `List<dynamic>` (the `data` array from Rootly's JSON:API response) and returns an `IncidentCounts` with four counts: `total`, `critical`, `high`, `afterHours`.

After-hours definition: the incident's `started_at` timestamp, converted to local time, has an hour outside `09:00–18:00` (i.e., `hour < 9 || hour >= 18`).

To make after-hours tests timezone-safe, timestamps are generated from the local clock rather than hardcoded UTC strings.

- [ ] **Step 1.1: Create the test file**

```dart
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

  Map<String, dynamic> _incident(String severity, String startedAt) => {
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
        _incident('critical', businessHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 1);
      expect(result.high, 0);
      expect(result.afterHours, 0);
    });

    test('one high incident after hours', () {
      final result = RootlyService.parseIncidents([
        _incident('high', afterHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 0);
      expect(result.high, 1);
      expect(result.afterHours, 1);
    });

    test('critical after hours counts in both critical and afterHours', () {
      final result = RootlyService.parseIncidents([
        _incident('critical', afterHoursIso),
      ]);
      expect(result.critical, 1);
      expect(result.afterHours, 1);
    });

    test('unknown severity counts in total only', () {
      final result = RootlyService.parseIncidents([
        _incident('low', businessHoursIso),
      ]);
      expect(result.total, 1);
      expect(result.critical, 0);
      expect(result.high, 0);
    });

    test('mixed batch: 1 critical after-hours + 2 high business-hours', () {
      final result = RootlyService.parseIncidents([
        _incident('critical', afterHoursIso),
        _incident('high', businessHoursIso),
        _incident('high', businessHoursIso),
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
```

- [ ] **Step 1.2: Run the tests — confirm they fail with "not defined"**

```bash
flutter test test/services/rootly_service_test.dart
```

Expected output: compilation error — `RootlyService` not yet defined.

---

## Task 2: Implement `RootlyService`

**Files:**
- Create: `lib/services/rootly_service.dart`

- [ ] **Step 2.1: Create the service file**

```dart
// lib/services/rootly_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    return body['data']['id'] as String;
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
          as Map<String, dynamic>;
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
}

/// Thrown when the Rootly API returns a non-200 status.
class RootlyApiException implements Exception {
  final String message;
  const RootlyApiException(this.message);

  @override
  String toString() => 'RootlyApiException: $message';
}
```

- [ ] **Step 2.2: Run the tests — confirm they pass**

```bash
flutter test test/services/rootly_service_test.dart
```

Expected: all 8 tests pass, 0 failures.

- [ ] **Step 2.3: Run static analysis — confirm no issues**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2.4: Commit**

```bash
git add lib/services/rootly_service.dart test/services/rootly_service_test.dart
git commit -m "feat: implement RootlyService.fetchIncidents() with parseIncidents unit tests (issue #13)"
```

---

## Task 3: Mark issue done and update architecture doc

- [ ] **Step 3.1: Mark issue #13 done in `issues_backlog.md`**

Change:

```markdown
| 13 | Implement `RootlyService.fetchIncidents()` ... | P0 | M | |
```

To:

```markdown
| 13 | Implement `RootlyService.fetchIncidents()` ... | P0 | M | ✅ |
```

- [ ] **Step 3.2: Update `docs/architecture.md` — add `rootly_service.dart` to the lib/ tree**

In `docs/architecture.md`, the services section currently lists `rootly_service.dart` as a planned file. Update its line to show it as implemented:

```markdown
│   ├── rootly_service.dart        # ✅ Rootly REST API — fetchIncidents() (issue #13)
```

- [ ] **Step 3.3: Commit**

```bash
git add issues_backlog.md docs/architecture.md
git commit -m "docs: mark issue #13 done, update architecture doc"
```

---

## What is NOT in this issue

- `fetchOnCallSchedule()` — issue #14
- `fetch() → WorkSignal` (combining incidents + on-call) — issue #14
- Wiring `ServiceLocator.fetchWork()` to the live service — issue #14
- Pagination of incident results — V2

---

## Notes for judges

- **After-hours proxy:** `started_at` (or `created_at`) converted to device local time, `hour < 9 || hour >= 18`. The accurate approach (comparing against the engineer's actual shift schedule) is a V2 improvement noted in `WorkSignal.afterHoursCount`.
- **Weights source:** `RootlyService` doesn't decide risk; it feeds raw counts to `StressCorrelator` which applies the weighted thresholds documented in `core/constants/thresholds.dart`.
- **No pagination:** MVP assumes < 25 incidents in 30 days. The Rootly default page size is 25. Engineers with very high incident loads may see truncated counts — acceptable for demo, noted as V2 work.
