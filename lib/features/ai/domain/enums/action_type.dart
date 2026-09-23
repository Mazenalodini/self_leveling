/// The broad classification of the recommended best action.
enum ActionType {
  /// Complete a scheduled pending productive habit (e.g., Reading)
  pendingHabit,

  /// Break away and drop the phone entirely (Cooldown)
  stepAway,

  /// Start a timed focus session to lock out bad behavior securely
  startFocusSession,

  /// Micro-task specific to breaking the current distraction loop
  microPivot,

  /// Recovery flow action requested by the system itself
  systemRecovery
}
