package com.selfleveling.self_leveling

/**
 * Structured intervention payload — carries all the information needed
 * to render an S1 notification, S2 warning, S3/S5 overlay, or S4 notification.
 *
 * This is the output of the escalation engine's decision, consumed by:
 *   - InterventionNotifier (S1/S2 notifications, S4 persistent notification)
 *   - OverlayManager (S3/S5 lock overlays)
 *   - TrackingService (state broadcasting to Flutter)
 *
 * V2: Added context fields for behavior-aware messaging and S4 limited access.
 */
data class InterventionPayload(
    /** Canonical intervention stage code that triggered this intervention (0–5) */
    val stage: Int,

    /** Overlay visual mode. Maps to the overlay variant. */
    val mode: OverlayMode,

    /** Primary title shown to the user */
    val title: String,

    /** Main message body */
    val message: String,

    /** Name of the app that triggered escalation */
    val appName: String,

    /** Package name of the triggering app */
    val packageName: String,

    /** Human-readable reason for escalation */
    val reason: String,

    /** Lock/countdown duration in seconds (0 = no lock) */
    val durationSeconds: Int = 0,

    /** Whether the user can dismiss this intervention */
    val canDismiss: Boolean = true,

    /** Optional reminder text (identity/goals) */
    val reminderText: String? = null,

    /** Optional suggested action (habit/task/challenge) */
    val suggestedAction: String? = null,

    /** Re-entry count for context display */
    val reentryCount: Int = 0,

    /** XP penalty amount (if applicable) */
    val xpPenalty: Int = 0,

    /** Reset time text (e.g., "Lock expires in 14m 30s") */
    val resetText: String? = null,

    /** Current risk score from the assessor (0.0–1.0) */
    val distractionScore: Double = 0.0,

    // ═══ V2: Context Fields for Behavior-Aware Messaging ═══

    /** Relevant pending habit name from user's habit list */
    val contextHabit: String? = null,

    /** Time-of-day context: "morning", "day", "evening", "night" */
    val contextTimeOfDay: String? = null,

    /** How many S1/S2 warnings were ignored before this intervention */
    val contextIgnoredCount: Int = 0,

    // ═══ V3: Rich AI Generated Content ═══

    /** Generated headline */
    val headline: String? = null,

    /** Generated body message */
    val body: String? = null,
    
    /** Action label for buttons (e.g. "I will stop") */
    val actionLabel: String? = null,

    /** Whether the overlay should expose a direct exit-to-home action */
    val showExitAppAction: Boolean = false,
    
    /** Emotional tone of the message */
    val tone: String? = null,
    
    /** The language of this generated payload ('en' or 'ar') */
    val language: String? = null,
    
    /** Optional recommendation / Hint title */
    val recommendationTitle: String? = null,
    
    /** Optional recommendation / Hint body text */
    val recommendationText: String? = null,

    // ═══ V2: S4 Limited Access Fields ═══

    /** Whether this is a S4 limited-access payload (no overlay, notification only) */
    val isLimitedAccess: Boolean = false,

    /** Remaining S4 limited access time in seconds */
    val limitedAccessRemainingSec: Int = 0,

    /** Whether a near-end warning (2 min) should be shown for S4 */
    val s4WarningNeeded: Boolean = false,

    /** Whether a final warning (30 sec) should be shown for S4 */
    val s4FinalWarningNeeded: Boolean = false,
)

/**
 * Visual modes for the overlay system.
 * Each mode has different color, layout, and behavior characteristics.
 */
enum class OverlayMode {
    /** Usage-limit daily block (existing behavior) — red/danger */
    USAGE_LIMIT,

    /** S3 behavior-based warning overlay — amber/warning */
    BEHAVIOR_WARNING,

    /** S4 limited access / restricted window — blue/enforced (notification only in V2) */
    LIMITED_ACCESS,

    /** S5 hard lock / strong enforcement — deep red/punitive */
    HARD_LOCK,
}
