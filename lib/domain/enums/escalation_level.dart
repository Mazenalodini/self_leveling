/// Escalation levels for the behavioral intervention system.
///
/// This is the Flutter-facing display enum for the canonical
/// `InterventionStage` runtime contract.
enum EscalationLevel {
  s0(
    name: 'Monitoring',
    description: 'System observing behavior without intervention',
    xpPenalty: 0,
    durationMinutes: 0,
    canDismiss: true,
  ),
  s1(
    name: 'Warning',
    description: 'Distraction detected — first native warning',
    xpPenalty: 0,
    durationMinutes: 0,
    canDismiss: true,
  ),
  s2(
    name: 'Reminder',
    description: 'Sustained distraction — stronger reminder',
    xpPenalty: 0,
    durationMinutes: 0,
    canDismiss: true,
  ),
  s3(
    name: 'Temporary Block',
    description: 'Timed native overlay block',
    xpPenalty: 0,
    durationMinutes: 15,
    canDismiss: false,
  ),
  s4(
    name: 'Limited Re-entry',
    description: 'Timed monitored re-entry window',
    xpPenalty: 0,
    durationMinutes: 15,
    canDismiss: false,
  ),
  s5(
    name: 'Hard Lock',
    description: 'Strong lockout + XP penalty',
    xpPenalty: 10,
    durationMinutes: 60,
    canDismiss: false,
  );

  final String name;
  final String description;
  final int xpPenalty;
  final int durationMinutes;
  final bool canDismiss;

  const EscalationLevel({
    required this.name,
    required this.description,
    required this.xpPenalty,
    required this.durationMinutes,
    required this.canDismiss,
  });

  /// Whether this level represents a native-policy timed state.
  bool get isTimedLock => durationMinutes > 0;

  /// Whether this level is a severe intervention (S3+).
  bool get isSevere => index >= EscalationLevel.s3.index;

  /// Get the next escalation level (capped at S5).
  EscalationLevel get next {
    final nextIndex = index + 1;
    if (nextIndex >= EscalationLevel.values.length) return this;
    return EscalationLevel.values[nextIndex];
  }

  /// Get the previous de-escalation level (capped at S0).
  EscalationLevel get previous {
    final prevIndex = index - 1;
    if (prevIndex < 0) return this;
    return EscalationLevel.values[prevIndex];
  }
}
