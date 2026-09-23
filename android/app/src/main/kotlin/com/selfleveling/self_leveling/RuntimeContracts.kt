package com.selfleveling.self_leveling

/**
 * Phase 1 runtime contract definitions shared conceptually with Flutter.
 *
 * These types freeze the semantics at the Flutter/Native boundary before
 * broader local-data unification work in later phases.
 */
object RuntimeContract {
    const val VERSION = 3
    val focusModeSemantics = FocusModeSemantics.STRICTER_ESCALATION
}

object RuntimeChannels {
    const val METHOD = "com.selfleveling/system"
    const val STATE_STREAM = "com.selfleveling/state_stream"
}

object RuntimeMethods {
    const val HAS_USAGE_STATS_PERMISSION = "hasUsageStatsPermission"
    const val REQUEST_USAGE_STATS_PERMISSION = "requestUsageStatsPermission"
    const val GET_USAGE_STATS = "getUsageStats"
    const val REFRESH_USAGE_SNAPSHOT = "refreshUsageSnapshot"
    const val GET_CURRENT_APP = "getCurrentApp"
    const val START_ENGINE = "startEngine"
    const val STOP_ENGINE = "stopEngine"
    const val IS_ENGINE_RUNNING = "isEngineRunning"
    const val GET_RUNTIME_SNAPSHOT = "getRuntimeSnapshot"
    const val GET_RUNTIME_READINESS = "getRuntimeReadiness"
    const val HAS_OVERLAY_PERMISSION = "hasOverlayPermission"
    const val REQUEST_OVERLAY_PERMISSION = "requestOverlayPermission"
    const val HAS_ACCESSIBILITY_PERMISSION = "hasAccessibilityPermission"
    const val REQUEST_ACCESSIBILITY_PERMISSION = "requestAccessibilityPermission"
    const val SHOW_OVERLAY = "showOverlay"
    const val HIDE_OVERLAY = "hideOverlay"
    const val HAS_NOTIFICATION_PERMISSION = "hasNotificationPermission"
    const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
    const val REFRESH_POLICIES = "refreshPolicies"
    const val CLASSIFY_APP = "classifyApp"
    const val SET_FOCUS_MODE = "setFocusMode"
    const val GENERATE_INTERVENTION = "generateIntervention"
}

enum class AppCategory(val code: Int) {
    PRODUCTIVE(0),
    NEUTRAL(1),
    DISTRACTING(2),
    ESSENTIAL(3),
    USER_DEFINED(4);

    companion object {
        fun fromCode(code: Int): AppCategory =
            values().firstOrNull { it.code == code } ?: NEUTRAL
    }
}

enum class InterventionStage(val code: Int, val displayName: String) {
    MONITORING(0, "Monitoring"),
    WARNING(1, "Warning"),
    REMINDER(2, "Reminder"),
    TEMPORARY_BLOCK(3, "Temporary Block"),
    LIMITED_REENTRY(4, "Limited Re-entry"),
    HARD_LOCK(5, "Hard Lock");

    companion object {
        fun fromCode(code: Int): InterventionStage =
            values().firstOrNull { it.code == code } ?: MONITORING
    }
}

enum class FocusModeSemantics {
    STRICTER_ESCALATION,
}

enum class ReadinessState {
    UNAUTHENTICATED,
    UNONBOARDED,
    PERMISSIONS_MISSING,
    READY,
}

object RuntimeSettingKeys {
    const val SYSTEM_SENSITIVITY = "system_sensitivity"
    const val ESCALATION_STRENGTH = "escalation_strength"
    const val NOTIFICATIONS_ENABLED = "notifications_enabled"
}

data class LockStatePayload(
    val blockedAppPackage: String? = null,
    val remainingLockSeconds: Int = 0,
    val reentryCount: Int = 0,
    val isLimitedAccess: Boolean = false,
    val limitedAccessRemainingSeconds: Int = 0,
    val limitedAccessAppPackage: String? = null,
) {
    val isActive: Boolean
        get() = remainingLockSeconds > 0 ||
            isLimitedAccess ||
            limitedAccessRemainingSeconds > 0 ||
            blockedAppPackage != null ||
            limitedAccessAppPackage != null

    fun toMap(): Map<String, Any?> = mapOf(
        "blockedAppPackage" to blockedAppPackage,
        "remainingLockSeconds" to remainingLockSeconds,
        "reentryCount" to reentryCount,
        "isLimitedAccess" to isLimitedAccess,
        "limitedAccessRemainingSeconds" to limitedAccessRemainingSeconds,
        "limitedAccessAppPackage" to limitedAccessAppPackage,
    )
}

data class RuntimeReadinessSnapshot(
    val contractVersion: Int = RuntimeContract.VERSION,
    val usageStatsGranted: Boolean = false,
    val overlayGranted: Boolean = false,
    val accessibilityGranted: Boolean = false,
    val notificationGranted: Boolean = false,
    val activationRequested: Boolean = false,
    val engineRunning: Boolean = false,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "contractVersion" to contractVersion,
        "usageStatsGranted" to usageStatsGranted,
        "overlayGranted" to overlayGranted,
        "accessibilityGranted" to accessibilityGranted,
        "notificationGranted" to notificationGranted,
        "activationRequested" to activationRequested,
        "engineRunning" to engineRunning,
    )
}

data class RuntimeStateSnapshot(
    val contractVersion: Int = RuntimeContract.VERSION,
    val trackingActive: Boolean = false,
    val stage: InterventionStage = InterventionStage.MONITORING,
    val currentAppPackage: String? = null,
    val overlayVisible: Boolean = false,
    val riskScore: Double = 0.0,
    val focusModeActive: Boolean = false,
    val lockState: LockStatePayload = LockStatePayload(),
    val lastUpdatedAt: Long = System.currentTimeMillis(),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "contractVersion" to contractVersion,
        "trackingActive" to trackingActive,
        "stage" to stage.code,
        "currentAppPackage" to currentAppPackage,
        "overlayVisible" to overlayVisible,
        "riskScore" to riskScore,
        "focusModeActive" to focusModeActive,
        "lockState" to lockState.toMap(),
        "lastUpdatedAt" to lastUpdatedAt,
    )
}

data class InterventionEvent(
    val contractVersion: Int = RuntimeContract.VERSION,
    val stage: InterventionStage,
    val packageName: String,
    val reason: String,
    val riskScore: Double,
    val reentryCount: Int = 0,
    val timestamp: Long,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "contractVersion" to contractVersion,
        "stage" to stage.code,
        "packageName" to packageName,
        "reason" to reason,
        "riskScore" to riskScore,
        "reentryCount" to reentryCount,
        "timestamp" to timestamp,
    )
}
