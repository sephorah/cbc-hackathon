# Code Review Fixes Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all issues found in the code review of issues #15–17, #20, #22–31. Three critical fixes (prevent build/demo), four important fixes (correctness), two minor fixes (cleanup).

**Architecture:** No new files. All fixes are targeted edits to existing files. Fixes are ordered by severity — do them in order.

---

## File map

| Action | Path | Fix |
|--------|------|-----|
| Modify | `lib/services/notification_service.dart` | Fix v21 API (critical) |
| Modify | `test/widget_test.dart` | Remove stale test (critical) |
| Modify | `lib/services/claude_service.dart` | Static-only + prompt text |
| Modify | `lib/core/service_locator.dart` | Wire live ClaudeService |
| Modify | `lib/screens/home_screen.dart` | Use ServiceLocator + fix Retry button |
| Modify | `lib/services/mock/mock_claude_service.dart` | Align signature |
| Modify | `lib/services/rootly_service.dart` | Remove duplicate import |
| Modify | `issues_backlog.md` | Mark issues done |
| Modify | `lib/screens/home_screen.dart` | withOpacity → withValues |
| Modify | `lib/screens/onboarding_screen.dart` | withOpacity → withValues |

---

## Fix 1 — NotificationService compile errors (CRITICAL)

**File:** `lib/services/notification_service.dart`

`flutter_local_notifications` v21 switched `initialize()` and `show()` from positional to named parameters. The app cannot build until this is fixed.

- [ ] **Step 1.1: Fix `initialize` call (line 34)**

Change:
```dart
await _plugin.initialize(initSettings);
```
To:
```dart
await _plugin.initialize(settings: initSettings);
```

- [ ] **Step 1.2: Fix `show` call (lines 60–65)**

Change:
```dart
await _plugin.show(
  0,
  title,
  safeBody,
  details,
);
```
To:
```dart
await _plugin.show(
  id: 0,
  title: title,
  body: safeBody,
  notificationDetails: details,
);
```

- [ ] **Step 1.3: Verify and commit**

```bash
flutter analyze lib/services/notification_service.dart
```
Expected: no errors on this file.

```bash
git add lib/services/notification_service.dart
git commit -m "fix: update flutter_local_notifications v21 API calls in NotificationService"
```

---

## Fix 2 — widget_test.dart stale test (CRITICAL)

**File:** `test/widget_test.dart`

References `const MyApp()` which no longer exists (renamed to `OnCallHelperApp`). This causes a compile error in `flutter test`.

- [ ] **Step 2.1: Replace file content**

Replace the entire file with:
```dart
// Default counter-app scaffold removed — ProductV1 replaced it.
// End-to-end tests tracked in issues_backlog.md (#32, #33).
void main() {}
```

- [ ] **Step 2.2: Run tests and commit**

```bash
flutter test
```
Expected: all tests pass (no failures).

```bash
git add test/widget_test.dart
git commit -m "fix: remove stale widget_test referencing deleted MyApp counter scaffold"
```

---

## Fix 3 — ClaudeService static-only + ServiceLocator wired + HomeScreen (CRITICAL)

**Files:** `lib/services/claude_service.dart`, `lib/core/service_locator.dart`, `lib/screens/home_screen.dart`

This fix groups three related changes that must be done together: making ClaudeService static (so ServiceLocator can call it), wiring ServiceLocator, and updating HomeScreen to use ServiceLocator.

- [ ] **Step 3.1: Make ClaudeService static-only**

In `lib/services/claude_service.dart`:

Add `const ClaudeService._();` after `class ClaudeService {`.

Change the `getRecommendation` method signature (line ~47) from:
```dart
  Future<String> getRecommendation(
```
to:
```dart
  static Future<String> getRecommendation(
```

Change the `_buildPrompt` method signature (line ~80) from:
```dart
  String _buildPrompt(
```
to:
```dart
  static String _buildPrompt(
```

- [ ] **Step 3.2: Wire ServiceLocator to ClaudeService**

In `lib/core/service_locator.dart`:

Add import after the existing rootly_service import:
```dart
import 'package:productv1/services/claude_service.dart';
```

Replace the `getRecommendation` method and the `_liveClaudeNotImplemented` stub with:
```dart
  static Future<String> getRecommendation(
    RiskLevel risk,
    WorkSignal work,
    HealthSignal health,
  ) =>
      useMocks
          ? MockClaudeService.getRecommendation(risk, work, health)
          : ClaudeService.getRecommendation(risk, work, health);
```

Remove the comment `// --- Stub for live ClaudeService (replaced in issue #15) ---` and the `_liveClaudeNotImplemented` method.

- [ ] **Step 3.3: Update HomeScreen to use ServiceLocator**

In `lib/screens/home_screen.dart`:

Remove these 3 imports:
```dart
import '../services/claude_service.dart';
import '../services/health_service.dart';
import '../services/rootly_service.dart';
```

Add this import:
```dart
import '../core/service_locator.dart';
```

In `_runAnalysis()`, change the Step 1 try-catch block from:
```dart
        work = await RootlyService.fetch();
        health = await HealthService.fetch();
```
to:
```dart
        work = await ServiceLocator.fetchWork();
        health = await ServiceLocator.fetchHealth();
```

Change the Step 3 try-catch block from:
```dart
        recommendation =
            await ClaudeService().getRecommendation(risk, work, health);
```
to:
```dart
        recommendation =
            await ServiceLocator.getRecommendation(risk, work, health);
```

Also fix the Step 3 fallback from:
```dart
        recommendation = await MockClaudeService.getRecommendation(risk);
```
to:
```dart
        recommendation = await MockClaudeService.getRecommendation(risk, work, health);
```

- [ ] **Step 3.4: Fix non-functional Retry button (in same file)**

In `_buildError()`, change:
```dart
          Text(
            'Retry',
            style: TextStyle(color: Color(0xFF6C63FF), fontSize: 15),
          ),
```
To:
```dart
          TextButton(
            onPressed: _runAnalysis,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFF6C63FF), fontSize: 15),
            ),
          ),
```

- [ ] **Step 3.5: Analyze and commit**

```bash
flutter analyze
```
Expected: no errors on these files.

```bash
git add lib/services/claude_service.dart lib/core/service_locator.dart lib/screens/home_screen.dart
git commit -m "feat: make ClaudeService static, wire ServiceLocator, fix HomeScreen to use ServiceLocator (issue #15)"
```

---

## Fix 4 — Align MockClaudeService signature (IMPORTANT)

**File:** `lib/services/mock/mock_claude_service.dart`

- [ ] **Step 4.1: Add imports and update signature**

Add these imports at the top of the file:
```dart
import 'package:productv1/models/health_signal.dart';
import 'package:productv1/models/work_signal.dart';
```

Change the `getRecommendation` signature from:
```dart
  static Future<String> getRecommendation(RiskLevel risk) async {
```
To:
```dart
  static Future<String> getRecommendation(
    RiskLevel risk,
    WorkSignal work,     // ignored — mock returns hardcoded strings
    HealthSignal health, // ignored — mock returns hardcoded strings
  ) async {
```

- [ ] **Step 4.2: Commit**

```bash
flutter analyze lib/services/mock/mock_claude_service.dart
```
Expected: no errors.

```bash
git add lib/services/mock/mock_claude_service.dart
git commit -m "fix: align MockClaudeService.getRecommendation signature with live ClaudeService"
```

---

## Fix 5 — Remove duplicate import in rootly_service.dart (IMPORTANT)

**File:** `lib/services/rootly_service.dart`

- [ ] **Step 5.1: Remove line 9**

Line 7 and line 9 both import `package:productv1/models/work_signal.dart`. Delete line 9 (the second one).

- [ ] **Step 5.2: Commit**

```bash
git add lib/services/rootly_service.dart
git commit -m "fix: remove duplicate work_signal.dart import in rootly_service.dart"
```

---

## Fix 6 — Fix prompt time window text (IMPORTANT)

**File:** `lib/services/claude_service.dart`

- [ ] **Step 6.1: Change "7 days" to "30 days" in `_buildPrompt`**

Find:
```dart
    buf.writeln('WORK SIGNALS (past 7 days):');
```
Change to:
```dart
    buf.writeln('WORK SIGNALS (past 30 days):');
```

- [ ] **Step 6.2: Commit**

```bash
git add lib/services/claude_service.dart
git commit -m "fix: correct work signal time window in Claude prompt (7 days → 30 days)"
```

---

## Fix 7 — Mark issues done in backlog (IMPORTANT)

**File:** `issues_backlog.md`

- [ ] **Step 7.1: Mark issues ✅**

For each of the following rows, change the trailing `| |` to `| ✅ |`:
- Issue #15 (`ClaudeService.getRecommendation`)
- Issue #16 (`NotificationService.send`)
- Issue #17 (Apple Watch mirror)
- Issue #22 (Claude system prompt)
- Issue #23 (Raw signals in prompt)
- Issue #24 (Crisis handoff in prompt)
- Issue #25 (OnboardingScreen)
- Issue #26 (HomeScreen)
- Issue #27 (Loading state)
- Issue #28 (Error state with fallback)
- Issue #29 (Crisis line in notification)
- Issue #30 (Disclaimer)
- Issue #31 (No data leaves device)

- [ ] **Step 7.2: Commit**

```bash
git add issues_backlog.md
git commit -m "docs: mark issues #15–17 and #22–31 done in backlog"
```

---

## Fix 8 — withOpacity deprecation warnings (MINOR)

**Files:** `lib/screens/home_screen.dart`, `lib/screens/onboarding_screen.dart`

22 instances of `.withOpacity(x)` should become `.withValues(alpha: x)`.

- [ ] **Step 8.1: Replace in home_screen.dart**

Use replace_all to change every `.withOpacity(` to `.withValues(alpha: ` in `home_screen.dart`.

Note: this changes `.withOpacity(0.12)` → `.withValues(alpha: 0.12)` etc. The closing `)` of `withOpacity` stays as `)`.

- [ ] **Step 8.2: Replace in onboarding_screen.dart**

Same replace_all on `onboarding_screen.dart`.

- [ ] **Step 8.3: Verify and commit**

```bash
flutter analyze
```
Expected: `No issues found!`

```bash
flutter test
```
Expected: all tests pass.

```bash
git add lib/screens/home_screen.dart lib/screens/onboarding_screen.dart
git commit -m "fix: replace deprecated withOpacity with withValues in screens"
```

---

## Final push

```bash
git push
```

---

## Code review

After all fixes and push, run the `superpowers:code-reviewer` agent on all modified files to confirm no regressions were introduced and the fixes are correctly applied.

Files to review:
- `lib/services/notification_service.dart`
- `lib/services/claude_service.dart`
- `lib/services/mock/mock_claude_service.dart`
- `lib/core/service_locator.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/onboarding_screen.dart`
- `lib/services/rootly_service.dart`
- `test/widget_test.dart`
- `issues_backlog.md`

---

## Verification summary

After all fixes, both commands must be clean:
```bash
flutter analyze   # No issues found!
flutter test      # All tests pass
```
