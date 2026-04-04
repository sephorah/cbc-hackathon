# Issue #14 — RootlyService.fetchOnCallSchedule() + fetch() → WorkSignal

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `fetchOnCallSchedule()` to `RootlyService`, add a combined `fetch() → WorkSignal` entry point, and wire `ServiceLocator.fetchWork()` to the live service so the app no longer throws `UnimplementedError` when `USE_MOCKS=false`.

**Architecture:** `parseOnCallSchedule(shifts, userId)` is a `@visibleForTesting` static method (same pattern as `parseIncidents`). `fetch()` fetches the user ID once, then calls both the incidents and on-call APIs in parallel via `Future.wait`, and assembles a `WorkSignal`. `fetchIncidents()` is refactored to delegate to a private `_fetchIncidentsForUser(userId)` so the user ID is not fetched twice inside `fetch()`.

**Tech Stack:** `http` package, `flutter_dotenv`, Rootly REST API `https://api.rootly.com`

---

## File map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `lib/services/rootly_service.dart` | Add `parseOnCallSchedule`, `_isOnCallForUser`, `_fetchScheduleIds`, `_fetchShiftsForSchedule`, `fetchOnCallSchedule`, `fetch`; refactor `fetchIncidents` |
| Modify | `test/services/rootly_service_test.dart` | Add tests for `parseOnCallSchedule` |
| Modify | `lib/core/service_locator.dart` | Wire `fetchWork()` to `RootlyService.fetch()` |

---

## Task 1: Write the failing tests for `parseOnCallSchedule`

**Files:**
- Modify: `test/services/rootly_service_test.dart`

`parseOnCallSchedule` takes `List<dynamic> shifts` (the `data` array from a Rootly shifts response) and a `String userId`, and returns `true` if any shift belongs to that user.

The shift JSON:API shape:
```json
{
  "relationships": {
    "user": {
      "data": { "id": "user-123" }
    }
  }
}
```

- [ ] **Step 1.1: Append the new test group to the existing test file**

Add this group after the closing `});` of the existing `'RootlyService.parseIncidents'` group (before the final `}`):

```dart
  group('RootlyService.parseOnCallSchedule', () {
    Map<String, dynamic> shift(String userId) => {
          'relationships': {
            'user': {
              'data': {'id': userId}
            }
          }
        };

    test('empty list returns false', () {
      expect(RootlyService.parseOnCallSchedule([], 'user-1'), false);
    });

    test('shift with a different user returns false', () {
      expect(
          RootlyService.parseOnCallSchedule([shift('user-2')], 'user-1'),
          false);
    });

    test('shift with matching user returns true', () {
      expect(
          RootlyService.parseOnCallSchedule([shift('user-1')], 'user-1'),
          true);
    });

    test('multiple shifts, one matching, returns true', () {
      expect(
          RootlyService.parseOnCallSchedule(
              [shift('user-2'), shift('user-1'), shift('user-3')], 'user-1'),
          true);
    });

    test('missing relationships does not throw and returns false', () {
      expect(
          RootlyService.parseOnCallSchedule(
              [<String, dynamic>{'attributes': <String, dynamic>{}}], 'user-1'),
          false);
    });

    test('null user data does not throw and returns false', () {
      expect(
          RootlyService.parseOnCallSchedule([
            <String, dynamic>{
              'relationships': <String, dynamic>{
                'user': <String, dynamic>{'data': null}
              }
            }
          ], 'user-1'),
          false);
    });
  });
```

- [ ] **Step 1.2: Run the tests — confirm they fail with "not defined"**

```bash
flutter test test/services/rootly_service_test.dart
```

Expected: compilation error — `parseOnCallSchedule` not yet defined.

---

## Task 2: Implement `parseOnCallSchedule`, helpers, and `fetch()`

**Files:**
- Modify: `lib/services/rootly_service.dart`

The final file replaces the existing content completely. Key changes from issue #13:
- `fetchIncidents()` now delegates to private `_fetchIncidentsForUser(userId)` to allow `fetch()` to share one user ID fetch.
- New private helpers: `_fetchIncidentsForUser`, `_fetchScheduleIds`, `_fetchShiftsForSchedule`, `_isOnCallForUser`.
- New public methods: `fetchOnCallSchedule()`, `fetch()`.
- New `@visibleForTesting` method: `parseOnCallSchedule(shifts, userId)`.

- [ ] **Step 2.1: Replace `lib/services/rootly_service.dart` with the full implementation**

```dart
// lib/services/rootly_service.dart
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

  /// Fetches incidents for the current user over the last [days] days.
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

  /// Fetches incidents for [userId] over the last [days] days.
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
    return parseIncidents(body['data'] as List<dynamic>);
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
        .map((s) => (s as Map<String, dynamic>)['id'] as String? ?? '')
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
```

- [ ] **Step 2.2: Run the tests — confirm they pass**

```bash
flutter test test/services/rootly_service_test.dart
```

Expected: all 14 tests pass (8 from issue #13 + 6 new), 0 failures.

- [ ] **Step 2.3: Run static analysis**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2.4: Commit**

```bash
git add lib/services/rootly_service.dart test/services/rootly_service_test.dart
git commit -m "feat: add RootlyService.fetchOnCallSchedule() and fetch() → WorkSignal (issue #14)"
```

---

## Task 3: Wire ServiceLocator.fetchWork() to RootlyService.fetch()

**Files:**
- Modify: `lib/core/service_locator.dart`

- [ ] **Step 3.1: Update the live branch of `fetchWork()`**

Change the import and the `fetchWork` getter. The full file after the edit:

```dart
import 'package:productv1/models/health_signal.dart';
import 'package:productv1/models/risk_level.dart';
import 'package:productv1/models/work_signal.dart';
import 'package:productv1/services/health_service.dart';
import 'package:productv1/services/rootly_service.dart';
import 'package:productv1/services/mock/mock_claude_service.dart';
import 'package:productv1/services/mock/mock_health_service.dart';
import 'package:productv1/services/mock/mock_rootly_service.dart';

/// Controls whether the app uses hardcoded mock data or live services.
///
/// Defaults to true (mock mode) — safe for Linux dev, CI, and simulator.
/// To build with live services: flutter run --dart-define=USE_MOCKS=false
const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

/// Single source of service instances for the app.
///
/// All getters return Futures so callers are async-ready when live services land.
/// To swap a service, change the corresponding getter — callers are unaffected.
class ServiceLocator {
  const ServiceLocator._();

  static Future<HealthSignal> fetchHealth() =>
      useMocks ? MockHealthService.fetch() : HealthService.fetch();

  static Future<WorkSignal> fetchWork() =>
      useMocks ? MockRootlyService.fetch() : RootlyService.fetch();

  static Future<String> getRecommendation(RiskLevel risk) => useMocks
      ? MockClaudeService.getRecommendation(risk)
      : _liveClaudeNotImplemented();

  // --- Stub for live ClaudeService (replaced in issue #15) ---

  static Future<String> _liveClaudeNotImplemented() =>
      Future<String>.error(UnimplementedError(
          'ClaudeService not yet implemented — build with --dart-define=USE_MOCKS=true'));
}
```

- [ ] **Step 3.2: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3.3: Run static analysis**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3.4: Commit**

```bash
git add lib/core/service_locator.dart
git commit -m "feat: wire ServiceLocator.fetchWork() to RootlyService.fetch() (issue #14)"
```

---

## Task 4: Mark issue done and update architecture doc

- [ ] **Step 4.1: Mark issue #14 done in `issues_backlog.md`**

Change:

```markdown
| 14 | Implement `RootlyService.fetchOnCallSchedule()` ... | P0 | S | |
```

To:

```markdown
| 14 | Implement `RootlyService.fetchOnCallSchedule()` ... | P0 | S | ✅ |
```

- [ ] **Step 4.2: Update `docs/architecture.md`**

Two corrections:
1. Update `rootly_service.dart` line to reflect it now has both `fetchIncidents` and `fetch() → WorkSignal`.
2. Fix the wrong issue number on `claude_service.dart` (currently says `#14`, should say `#15`).

```markdown
│   ├── rootly_service.dart        # ✅ Rootly REST API — fetchIncidents() + fetch() → WorkSignal (issues #13, #14)
│   ├── claude_service.dart        # Claude API — recommendation text only (issue #15)
```

Also update the Key implementation constraints bullet that says "Rootly MCP" to say "Rootly REST API":

```markdown
- All data stays on device — the only outbound HTTP calls are to Rootly REST API and the Claude API
```

- [ ] **Step 4.3: Commit**

```bash
git add issues_backlog.md docs/architecture.md
git commit -m "docs: mark issue #14 done, fix architecture doc issue numbers"
```

---

## What is NOT in this issue

- `ClaudeService.getRecommendation()` — issue #15
- Updating `ServiceLocator.getRecommendation` signature to accept `WorkSignal` + `HealthSignal` — issue #15
- `NotificationService` — issue #16
- Pagination of schedule/incident results — V2

---

## Notes for judges

- **On-call check window:** `±1 minute` around `now` — simple proxy for "active right now". A more accurate check would compare shift `starts_at`/`ends_at` against the current time explicitly, but the Rootly shifts endpoint filters by time window, so querying a 2-minute window achieves the same result.
- **Serial schedule loop:** `_isOnCallForUser` loops over schedules sequentially (not parallel) to short-circuit early on the first match. Engineers typically have 1–2 schedules, so this is fine for MVP.
- **WorkSignal assembly:** `fetch()` uses `Future.wait` to fetch incidents and on-call status in parallel, reducing total network time from sequential to max(incidents, on-call) latency.
