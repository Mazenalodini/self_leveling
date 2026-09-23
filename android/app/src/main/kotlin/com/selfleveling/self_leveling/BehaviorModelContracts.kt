package com.selfleveling.self_leveling

import org.json.JSONObject
import java.util.UUID

/**
 * Phase 10 behavior-model preparation contracts.
 *
 * These types explicitly separate:
 *   1. deterministic runtime/policy facts already known by the system
 *   2. canonical feature inputs derived from those facts
 *   3. inferred risk outputs produced by a scoring engine
 *   4. future feedback / label capture
 *
 * Current runtime continues to use rule-based scoring only.
 * Future model-backed assessors should plug into [BehaviorRiskEngine].
 */

enum class BehaviorAssessmentSource(val storageValue: String) {
    RULE_BASED("rule_based"),
    FUTURE_MODEL("future_model"),
    HYBRID("hybrid");
}

enum class BehaviorEffectivePolicy(val storageValue: String) {
    ESSENTIAL_ALLOW("essential_allow"),
    PRODUCTIVE_ALLOW("productive_allow"),
    NEUTRAL_MONITOR("neutral_monitor"),
    DISTRACTING_MONITOR("distracting_monitor"),
    MANUAL_LIMIT("manual_limit"),
    BLACKLIST("blacklist");
}

enum class BehaviorRiskClass(val storageValue: String) {
    NONE("none"),
    LOW("low"),
    MODERATE("moderate"),
    HIGH("high"),
    CRITICAL("critical");

    companion object {
        fun fromLegacy(level: BehaviorRiskAssessor.RiskLevel): BehaviorRiskClass = when (level) {
            BehaviorRiskAssessor.RiskLevel.NONE -> NONE
            BehaviorRiskAssessor.RiskLevel.LOW -> LOW
            BehaviorRiskAssessor.RiskLevel.MODERATE -> MODERATE
            BehaviorRiskAssessor.RiskLevel.HIGH -> HIGH
            BehaviorRiskAssessor.RiskLevel.CRITICAL -> CRITICAL
        }

        fun fromRiskScore(score: Double): BehaviorRiskClass = when {
            score < 0.12 -> NONE
            score < 0.25 -> LOW
            score < 0.40 -> MODERATE
            score < 0.60 -> HIGH
            else -> CRITICAL
        }
    }
}

enum class BehaviorLabelState(val storageValue: String) {
    UNLABELED("unlabeled"),
    LABELED("labeled"),
}

enum class BehaviorFeedbackType(val storageValue: String) {
    HELPFULNESS("helpfulness"),
    FALSE_POSITIVE("false_positive"),
    FALSE_NEGATIVE("false_negative"),
    CATEGORY_CORRECTION("category_correction"),
    OUTCOME("outcome");
}

/**
 * Deterministic facts the runtime already knows authoritatively.
 */
data class BehaviorDeterministicFacts(
    val packageName: String,
    val appName: String,
    val appCategoryCode: Int,
    val appCategoryName: String,
    val effectivePolicy: BehaviorEffectivePolicy,
    val currentStage: Int,
    val hasActiveLock: Boolean,
    val activeLockStage: Int?,
    val isLimitedAccessActive: Boolean,
    val limitedAccessTargetPackage: String?,
    val sessionSeconds: Long,
    val dailyDistractingSeconds: Long,
    val dailyProductiveSeconds: Long,
    val reentryCount: Int,
    val ignoredWarnings: Int,
    val postLockReturnCount: Int,
    val recentInterventionCount24h: Int,
    val isFocusModeActive: Boolean,
    val sensitivity: Double,
    val strength: Double,
    val hourOfDay: Int,
    val dayOfWeek: Int,
    val isManuallyLimited: Boolean,
    val isBlacklisted: Boolean,
) {
    fun toStorageJson(): String = JSONObject().apply {
        put("packageName", packageName)
        put("appName", appName)
        put("appCategoryCode", appCategoryCode)
        put("appCategoryName", appCategoryName)
        put("effectivePolicy", effectivePolicy.storageValue)
        put("currentStage", currentStage)
        put("hasActiveLock", hasActiveLock)
        put("activeLockStage", activeLockStage)
        put("isLimitedAccessActive", isLimitedAccessActive)
        put("limitedAccessTargetPackage", limitedAccessTargetPackage)
        put("sessionSeconds", sessionSeconds)
        put("dailyDistractingSeconds", dailyDistractingSeconds)
        put("dailyProductiveSeconds", dailyProductiveSeconds)
        put("reentryCount", reentryCount)
        put("ignoredWarnings", ignoredWarnings)
        put("postLockReturnCount", postLockReturnCount)
        put("recentInterventionCount24h", recentInterventionCount24h)
        put("isFocusModeActive", isFocusModeActive)
        put("sensitivity", sensitivity)
        put("strength", strength)
        put("hourOfDay", hourOfDay)
        put("dayOfWeek", dayOfWeek)
        put("isManuallyLimited", isManuallyLimited)
        put("isBlacklisted", isBlacklisted)
    }.toString()
}

/**
 * Canonical feature inputs derived from deterministic facts.
 *
 * These are future-model-friendly feature values, but they are still
 * entirely deterministic and locally derived.
 */
data class BehaviorFeatureSnapshot(
    val packageName: String,
    val appCategoryCode: Int,
    val currentStage: Int,
    val effectivePolicy: String,
    val appRiskTier: String,
    val hasActiveLock: Boolean,
    val isLimitedAccessActive: Boolean,
    val sessionSeconds: Long,
    val sessionMinutes: Double,
    val dailyDistractingSeconds: Long,
    val dailyProductiveSeconds: Long,
    val dailyTotalSeconds: Long,
    val dailyDistractingRatio: Double,
    val dailyProductiveRatio: Double,
    val reentryCount: Int,
    val ignoredWarnings: Int,
    val postLockReturnCount: Int,
    val recentInterventionCount24h: Int,
    val recentInterventionDensityPerHour: Double,
    val isFocusModeActive: Boolean,
    val sensitivity: Double,
    val strength: Double,
    val hourOfDay: Int,
    val dayOfWeek: Int,
    val hourOfDayNormalized: Double,
    val dayOfWeekNormalized: Double,
) {
    fun toStorageJson(): String = JSONObject().apply {
        put("packageName", packageName)
        put("appCategoryCode", appCategoryCode)
        put("currentStage", currentStage)
        put("effectivePolicy", effectivePolicy)
        put("appRiskTier", appRiskTier)
        put("hasActiveLock", hasActiveLock)
        put("isLimitedAccessActive", isLimitedAccessActive)
        put("sessionSeconds", sessionSeconds)
        put("sessionMinutes", sessionMinutes)
        put("dailyDistractingSeconds", dailyDistractingSeconds)
        put("dailyProductiveSeconds", dailyProductiveSeconds)
        put("dailyTotalSeconds", dailyTotalSeconds)
        put("dailyDistractingRatio", dailyDistractingRatio)
        put("dailyProductiveRatio", dailyProductiveRatio)
        put("reentryCount", reentryCount)
        put("ignoredWarnings", ignoredWarnings)
        put("postLockReturnCount", postLockReturnCount)
        put("recentInterventionCount24h", recentInterventionCount24h)
        put("recentInterventionDensityPerHour", recentInterventionDensityPerHour)
        put("isFocusModeActive", isFocusModeActive)
        put("sensitivity", sensitivity)
        put("strength", strength)
        put("hourOfDay", hourOfDay)
        put("dayOfWeek", dayOfWeek)
        put("hourOfDayNormalized", hourOfDayNormalized)
        put("dayOfWeekNormalized", dayOfWeekNormalized)
    }.toString()

    companion object {
        fun fromFacts(facts: BehaviorDeterministicFacts): BehaviorFeatureSnapshot {
            val dailyTotalSeconds = facts.dailyDistractingSeconds + facts.dailyProductiveSeconds
            val distractingRatio = if (dailyTotalSeconds > 0L) {
                facts.dailyDistractingSeconds.toDouble() / dailyTotalSeconds.toDouble()
            } else {
                0.0
            }
            val productiveRatio = if (dailyTotalSeconds > 0L) {
                facts.dailyProductiveSeconds.toDouble() / dailyTotalSeconds.toDouble()
            } else {
                0.0
            }
            val appRiskTier = BehaviorRiskAssessor
                .getAppRiskTier(facts.packageName, facts.appCategoryCode)
                .name
            return BehaviorFeatureSnapshot(
                packageName = facts.packageName,
                appCategoryCode = facts.appCategoryCode,
                currentStage = facts.currentStage,
                effectivePolicy = facts.effectivePolicy.storageValue,
                appRiskTier = appRiskTier,
                hasActiveLock = facts.hasActiveLock,
                isLimitedAccessActive = facts.isLimitedAccessActive,
                sessionSeconds = facts.sessionSeconds,
                sessionMinutes = facts.sessionSeconds / 60.0,
                dailyDistractingSeconds = facts.dailyDistractingSeconds,
                dailyProductiveSeconds = facts.dailyProductiveSeconds,
                dailyTotalSeconds = dailyTotalSeconds,
                dailyDistractingRatio = distractingRatio,
                dailyProductiveRatio = productiveRatio,
                reentryCount = facts.reentryCount,
                ignoredWarnings = facts.ignoredWarnings,
                postLockReturnCount = facts.postLockReturnCount,
                recentInterventionCount24h = facts.recentInterventionCount24h,
                recentInterventionDensityPerHour = facts.recentInterventionCount24h / 24.0,
                isFocusModeActive = facts.isFocusModeActive,
                sensitivity = facts.sensitivity,
                strength = facts.strength,
                hourOfDay = facts.hourOfDay,
                dayOfWeek = facts.dayOfWeek,
                hourOfDayNormalized = (facts.hourOfDay.coerceIn(0, 23)) / 23.0,
                dayOfWeekNormalized = ((facts.dayOfWeek - 1).coerceIn(0, 6)) / 6.0,
            )
        }
    }
}

data class BehaviorAssessmentInput(
    val facts: BehaviorDeterministicFacts,
    val features: BehaviorFeatureSnapshot,
)

/**
 * Inferred risk facts.
 *
 * These are explicitly separate from deterministic facts above.
 */
data class BehaviorRiskInference(
    val riskScore: Double,
    val riskClass: BehaviorRiskClass,
    val appRiskTier: BehaviorRiskAssessor.AppRiskTier,
    val confidence: Double? = null,
    val sessionFactor: Double = 0.0,
    val behavioralFactor: Double = 0.0,
    val reasoning: String = "",
    val predictedDistractionLikelihood: Double? = null,
) {
    fun toLegacyRiskAssessment(): BehaviorRiskAssessor.RiskAssessment =
        BehaviorRiskAssessor.RiskAssessment(
            riskScore = riskScore,
            riskLevel = when (riskClass) {
                BehaviorRiskClass.NONE -> BehaviorRiskAssessor.RiskLevel.NONE
                BehaviorRiskClass.LOW -> BehaviorRiskAssessor.RiskLevel.LOW
                BehaviorRiskClass.MODERATE -> BehaviorRiskAssessor.RiskLevel.MODERATE
                BehaviorRiskClass.HIGH -> BehaviorRiskAssessor.RiskLevel.HIGH
                BehaviorRiskClass.CRITICAL -> BehaviorRiskAssessor.RiskLevel.CRITICAL
            },
            appRiskTier = appRiskTier,
            sessionFactor = sessionFactor,
            behavioralFactor = behavioralFactor,
            reasoning = reasoning,
        )
}

data class BehaviorAssessment(
    val assessmentId: String = UUID.randomUUID().toString(),
    val createdAt: Long,
    val source: BehaviorAssessmentSource,
    val assessorKind: String,
    val assessorVersion: String,
    val targetPackageName: String,
    val targetAppName: String,
    val facts: BehaviorDeterministicFacts,
    val features: BehaviorFeatureSnapshot,
    val inference: BehaviorRiskInference,
    val runtimeEventId: String? = null,
    val labelState: BehaviorLabelState = BehaviorLabelState.UNLABELED,
)

data class BehaviorAssessmentFeedback(
    val assessmentId: String,
    val feedbackType: BehaviorFeedbackType,
    val feedbackValue: String,
    val packageName: String,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val createdBy: String = "user",
)

interface BehaviorRiskEngine {
    fun assess(
        input: BehaviorAssessmentInput,
        createdAt: Long = System.currentTimeMillis(),
    ): BehaviorAssessment
}
