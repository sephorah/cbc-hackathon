/// Human resource and crisis line references included in critical-risk notifications.
///
/// These strings appear verbatim in notification bodies and Claude prompts.
/// Centralised here so MockClaudeService and the real ClaudeService stay in sync.
class CrisisResources {
  CrisisResources._();

  /// Employee Assistance Program — company-provided confidential support.
  static const String eap = 'Employee Assistance Program (EAP)';

  /// Crisis Services Canada — 24/7 bilingual crisis support line.
  static const String crisisLine = 'Crisis Services Canada (1-833-456-4566)';

  /// Full sentence appended to critical-risk recommendations.
  static const String criticalHandoff =
      'If you\'re feeling overwhelmed, $eap or $crisisLine are available 24/7. '
      'You don\'t have to manage this alone.';
}
