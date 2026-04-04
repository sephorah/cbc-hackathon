import 'package:flutter/material.dart';
import 'home_screen.dart';

/// Issue #25: One-time privacy explainer shown on first launch.
///
/// Covers:
///   - What data is collected and why
///   - Issue #31: explicit statement that data never leaves the device
///   - Issue #30: disclaimer that the app does not replace human support
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

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
              const Spacer(),
              _header(),
              const SizedBox(height: 32),
              _dataSection(),
              const SizedBox(height: 24),
              _privacyGuarantee(), // issue #31
              const SizedBox(height: 20),
              _disclaimer(), // issue #30
              const Spacer(),
              _continueButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OnCallBalance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your private wellbeing companion.',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.6),
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  Widget _dataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this app reads',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),
        _dataRow(
          icon: Icons.bedtime_outlined,
          title: 'Sleep duration',
          subtitle:
              'Average hours per night over 7 days, from Apple Watch via HealthKit.',
        ),
        const SizedBox(height: 14),
        _dataRow(
          icon: Icons.bolt_outlined,
          title: 'Incident data',
          subtitle:
              'Incident count, severity, after-hours pages, and on-call schedule from Rootly.',
        ),
      ],
    );
  }

  Widget _dataRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.55),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Issue #31: confirm no data leaves device
  Widget _privacyGuarantee() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2ECC71).withValues(alpha:0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF2ECC71), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data never leaves this device',
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'All analysis runs on-device. The only outbound calls are to '
                  'Rootly (reads your incidents) and Claude API (generates recommendation text). '
                  'No health data is ever transmitted. Your employer cannot see this app or its results.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.6),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Issue #30: disclaimer — app does not replace human support
  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1410),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.08),
        ),
      ),
      child: Text(
        'This app does not replace professional mental health support or human '
        'connection. If you are in distress, please reach out to a real person. '
        'Crisis Services Canada: 1-833-456-4566.',
        style: TextStyle(
          color: Colors.white.withValues(alpha:0.4),
          fontSize: 11,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _continueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Get started',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
