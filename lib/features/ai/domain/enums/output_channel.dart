/// Defines the visual surface/channel through which the message will be delivered.
enum OutputChannel {
  /// Simple system push notification (Requires extremely short, punchy logic)
  notification,
  
  /// Floating bubble/card visible over apps (Requires medium length, actionable tone)
  floatingCard,
  
  /// Fully blocking entire screen overlay (Allows full paragraph, stern or deeply reflective tone)
  fullOverlay,

  /// Scheduled local notification for a habit reminder
  habitReminder,

  /// Gentle nudge because pending habits remain
  missedHabitNudge
}
