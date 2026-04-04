import 'package:flutter/material.dart';
import '../core/stress_correlator.dart';
import '../core/service_locator.dart';
import '../models/health_signal.dart';
import '../models/risk_level.dart';
import '../models/work_signal.dart';
import '../services/mock/mock_claude_service.dart';
import '../services/mock/mock_health_service.dart';
import '../services/mock/mock_rootly_service.dart';
import '../services/rootly_service.dart';
import '../services/notification_service.dart';

enum _State { idle, loading, done, error }

/// Issue #26: Main dashboard — trigger analysis, display results.
///
/// Issue #27: shows a loading spinner while fetching data + calling Claude.
/// Issue #28: shows an error state if all services fail, with a retry button.
///
/// Mock fallback flow (issue #28):
///   1. Try live HealthService + RootlyService
///   2. If either throws → fall back to MockHealthService + MockRootlyService
///   3. Try live ClaudeService
///   4. If it throws → fall back to MockClaudeService
///   5. If even mocks throw → show error state
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _State _state = _State.idle;
  RiskLevel? _riskLevel;
  String? _recommendation;
  WorkSignal? _workSignal;
  HealthSignal? _healthSignal;
  String? _errorMessage;
  bool _usedMockFallback = false;

  Future<void> _runAnalysis() async {
    setState(() {
      _state = _State.loading;
      _errorMessage = null;
      // Health data is always mocked (HealthKit requires a paid Apple
      // Developer account). The banner is shown regardless of whether
      // Rootly and Claude succeed with live data.
      _usedMockFallback = true;
    });

    try {
      debugPrint('[ProductV1] Starting analysis...');

      // --- Step 1: fetch signals ---
      // Health: always mock (HealthKit requires paid Apple Developer account).
      debugPrint('[ProductV1] Using mock sleep data (HealthKit unavailable on free team)...');
      final health = await MockHealthService.fetch();
      debugPrint('[ProductV1] Health signal: sleep=${health.totalSleepDuration.inMinutes}min fragmentation=${health.fragmentationCount}');

      // Work: live Rootly for incident counts + on-call status.
      // afterHoursCount uses mock (live after-hours detection is unreliable).
      WorkSignal work;
      try {
        debugPrint('[ProductV1] Fetching Rootly work signal (live mode)...');
        final liveWork = await RootlyService.fetch();
        final mockWork = await MockRootlyService.fetch();
        work = WorkSignal(
          windowStart: liveWork.windowStart,
          windowEnd: liveWork.windowEnd,
          totalIncidents: liveWork.totalIncidents,
          criticalCount: liveWork.criticalCount,
          highCount: liveWork.highCount,
          afterHoursCount: mockWork.afterHoursCount,
          isOnCall: liveWork.isOnCall,
        );
        debugPrint('[ProductV1] Work signal: total=${work.totalIncidents} critical=${work.criticalCount} high=${work.highCount} afterHours=${work.afterHoursCount}(mock) onCall=${work.isOnCall}');
      } catch (e) {
        debugPrint('[ProductV1] Rootly live fetch failed: $e — falling back to mock work data');
        work = await MockRootlyService.fetch();
        debugPrint('[ProductV1] Mock work signal: total=${work.totalIncidents} onCall=${work.isOnCall}');
        _usedMockFallback = true;
      }

      // --- Step 2: deterministic correlation (never let Claude decide risk) ---
      debugPrint('[ProductV1] Running StressCorrelator...');
      final risk = StressCorrelator.compute(work, health);
      debugPrint('[ProductV1] Risk level computed: ${risk.name.toUpperCase()}');

      // --- Step 3: get recommendation text (mock fallback if Claude fails) ---
      String recommendation;
      try {
        debugPrint('[ProductV1] Calling Claude API for recommendation...');
        recommendation =
            await ServiceLocator.getRecommendation(risk, work, health);
        debugPrint('[ProductV1] Claude response received (${recommendation.length} chars)');
      } catch (e) {
        debugPrint('[ProductV1] Claude API failed: $e — using mock recommendation');
        recommendation = await MockClaudeService.getRecommendation(risk, work, health);
        _usedMockFallback = true;
      }

      // --- Step 4: send notification (mirrors to Apple Watch automatically) ---
      debugPrint('[ProductV1] Sending notification (isCritical=${risk == RiskLevel.critical})...');
      await NotificationService.send(
        title: 'ProductV1 — ${risk.label} Risk',
        body: recommendation,
        isCritical: risk == RiskLevel.critical,
      );
      debugPrint('[ProductV1] Notification sent.');

      if (!mounted) return;
      setState(() {
        _state = _State.done;
        _riskLevel = risk;
        _recommendation = recommendation;
        _workSignal = work;
        _healthSignal = health;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _State.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              Expanded(child: _buildBody()),
              _buildTriggerButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'ProductV1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        if (_usedMockFallback)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF5C3A1A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DEMO DATA',
              style: TextStyle(
                color: Color(0xFFE8A045),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _State.idle:
        return _buildIdle();
      case _State.loading:
        return _buildLoading(); // issue #27
      case _State.done:
        return _buildResult();
      case _State.error:
        return _buildError(); // issue #28
    }
  }

  // --- Idle ---

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: Colors.white.withValues(alpha:0.2),
            size: 72,
          ),
          const SizedBox(height: 20),
          Text(
            'Tap below to check in',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reads your sleep + incident data and sends\na recommendation to your Apple Watch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.3),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Loading (issue #27) ---

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 28),
          const Text(
            'Analysing…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching sleep + incident data\nand computing your risk level',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Result ---

  Widget _buildResult() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _riskBadge(_riskLevel!),
          const SizedBox(height: 20),
          if (_workSignal != null && _healthSignal != null)
            _signalSummary(_workSignal!, _healthSignal!),
          const SizedBox(height: 20),
          _recommendationCard(_recommendation!),
          const SizedBox(height: 14),
          _watchRow(),
          if (_usedMockFallback) ...[
            const SizedBox(height: 10),
            _mockRow(),
          ],
        ],
      ),
    );
  }

  Widget _riskBadge(RiskLevel risk) {
    final color = _colorFor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            '${risk.label} Risk',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalSummary(WorkSignal work, HealthSignal health) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15152A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIGNALS USED',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                Icons.bedtime_outlined,
                '${(health.totalSleepDuration.inMinutes / 60.0).toStringAsFixed(1)}h sleep',
              ),
              _chip(Icons.bolt_outlined, '${work.totalIncidents} incidents'),
              _chip(
                Icons.nights_stay_outlined,
                '${work.afterHoursCount} after-hours',
              ),
              if (work.isOnCall)
                _chip(Icons.phone_in_talk_outlined, 'On call'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _recommendationCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15152A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha:0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF6C63FF),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'AI Recommendation',
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchRow() {
    return Row(
      children: [
        const Icon(Icons.watch_outlined, color: Color(0xFF2ECC71), size: 14),
        const SizedBox(width: 7),
        Text(
          'Notification sent — check your Apple Watch',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.45),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _mockRow() {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Colors.white.withValues(alpha:0.25),
          size: 13,
        ),
        const SizedBox(width: 6),
        Text(
          'Live APIs unavailable — showing demo data',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.25),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // --- Error (issue #28) ---

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.withValues(alpha:0.6),
            size: 52,
          ),
          const SizedBox(height: 18),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.45),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: _runAnalysis,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFF6C63FF), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // --- Trigger button ---

  Widget _buildTriggerButton() {
    final busy = _state == _State.loading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : _runAnalysis,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha:0.35),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          busy ? 'Analysing…' : 'Check in now',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  Color _colorFor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.low:
        return const Color(0xFF2ECC71);
      case RiskLevel.moderate:
        return const Color(0xFFF39C12);
      case RiskLevel.high:
        return const Color(0xFFE67E22);
      case RiskLevel.critical:
        return const Color(0xFFE74C3C);
    }
  }
}
