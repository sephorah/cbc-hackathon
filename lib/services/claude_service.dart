import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/health_signal.dart';
import '../models/risk_level.dart';
import '../models/work_signal.dart';

/// Calls the Claude API to generate a short, personalized recommendation.
///
/// Key design constraint (issues #22–24):
///   - Claude generates *text only* — it never decides the risk level.
///   - The pre-computed RiskLevel is passed in as a fact, not a question.
///   - Raw signal values are included so the output is specific (issue #23).
///   - Crisis handoff is non-negotiable for CRITICAL risk (issue #24).
///
/// Issue #31: The only data that leaves the device here is the work + health
/// signal summary, sent over HTTPS to the Claude API. No device identifiers,
/// no account info, no raw HealthKit records.
class ClaudeService {
  const ClaudeService._();

  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

  // claude-haiku-4-5-20251001: fast, cheap, more than capable for short text
  static const _model = 'claude-haiku-4-5-20251001';
  static const _maxTokens = 300;

  // Issue #22: SRE-specific system prompt — NOT generic wellness advice.
  // Written to produce engineer-appropriate tone: direct, practical, peer-level.
  static const _systemPrompt = '''
You are a wellbeing companion for on-call software engineers (SREs).
Your job is to write a short, specific, actionable recommendation based on
their work stress signals and recent sleep data.

Rules:
1. Write 2–3 sentences maximum. Be direct — no filler, no fluff.
2. Address the engineer's actual situation using their specific numbers.
3. Use the tone of a trusted senior engineer who cares about people — not a wellness app.
4. NEVER diagnose, prescribe, or provide medical or psychological advice.
5. NEVER make the risk decision — the risk level is pre-computed and given to you as a fact.
6. NEVER tell the engineer to ignore an on-call alert.
7. If risk is CRITICAL: your final sentence MUST include this exact phrase —
   "If you are struggling, please reach out: Crisis Services Canada 1-833-456-4566."
8. End with one concrete action the engineer can take in the next 30 minutes.
''';

  /// Returns a 2–3 sentence recommendation string.
  /// Throws if the API call fails — caller should fall back to MockClaudeService.
  static Future<String> getRecommendation(
    RiskLevel riskLevel,
    WorkSignal work,
    HealthSignal health,
  ) async {
    final apiKey = dotenv.env['CLAUDE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('CLAUDE_API_KEY not found in .env');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': _systemPrompt,
        'messages': [
          {'role': 'user', 'content': _buildPrompt(riskLevel, work, health)},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Claude API ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  // Issue #23: include raw signal values so Claude's output is specific.
  // Issue #24: explicit crisis handoff instruction when CRITICAL.
  static String _buildPrompt(
    RiskLevel riskLevel,
    WorkSignal work,
    HealthSignal health,
  ) {
    final buf = StringBuffer();
    buf.writeln('Engineer wellbeing check — here are the signals:');
    buf.writeln();
    buf.writeln('RISK LEVEL (pre-computed, do not change): ${riskLevel.name.toUpperCase()}');
    buf.writeln();
    buf.writeln('WORK SIGNALS (past 30 days):');
    buf.writeln('  Total incidents: ${work.totalIncidents}');
    buf.writeln('  Critical incidents: ${work.criticalCount}');
    buf.writeln('  High-severity incidents: ${work.highCount}');
    buf.writeln('  After-hours pages: ${work.afterHoursCount}');
    buf.writeln('  Currently on call: ${work.isOnCall ? "Yes" : "No"}');
    buf.writeln();
    buf.writeln('HEALTH SIGNALS:');
    buf.writeln(
      '  Sleep last night: ${(health.totalSleepDuration.inMinutes / 60.0).toStringAsFixed(1)}h',
    );
    if (health.fragmentationCount != null) {
      buf.writeln('  Awakenings: ${health.fragmentationCount}');
    }
    buf.writeln();

    if (riskLevel == RiskLevel.critical) {
      // Issue #24: make crisis handoff explicit in the prompt, not just the system prompt
      buf.writeln(
        'SAFETY REQUIREMENT: Risk is CRITICAL. '
        'You MUST end with: '
        '"If you are struggling, please reach out: Crisis Services Canada 1-833-456-4566."',
      );
      buf.writeln();
    }

    buf.writeln(
      'Write a short, specific recommendation using their actual numbers.',
    );
    return buf.toString();
  }
}
