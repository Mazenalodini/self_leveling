package com.selfleveling.self_leveling

import java.util.Calendar

/**
 * Builds canonical behavior-model inputs from authoritative runtime facts.
 *
 * This stays deterministic and model-free.
 */
object BehaviorFeatureExtractor {

    fun build(
        packageName: String,
        appName: String,
        appCategory: Int,
        state: AppEscalationState,
        sessionSeconds: Long,
        dailyDistractingSec: Long,
        dailyProductiveSec: Long,
        isFocusMode: Boolean,
        isManuallyLimited: Boolean,
        isBlacklisted: Boolean,
        sensitivity: Double,
        strength: Double,
        recentInterventionCount24h: Int,
        now: Long = System.currentTimeMillis(),
    ): BehaviorAssessmentInput {
        val calendar = Calendar.getInstance().apply { timeInMillis = now }
        val hasActiveLock = state.isLockActive(now)
        val isLimitedAccessActive = state.isInS4Window(now)
        val facts = BehaviorDeterministicFacts(
            packageName = packageName,
            appName = appName,
            appCategoryCode = appCategory,
            appCategoryName = AppClassifier.categoryName(appCategory),
            effectivePolicy = resolveEffectivePolicy(
                appCategory = appCategory,
                isManuallyLimited = isManuallyLimited,
                isBlacklisted = isBlacklisted,
            ),
            currentStage = state.currentStage,
            hasActiveLock = hasActiveLock,
            activeLockStage = when {
                hasActiveLock -> state.currentStage
                isLimitedAccessActive -> 4
                else -> null
            },
            isLimitedAccessActive = isLimitedAccessActive,
            limitedAccessTargetPackage = if (isLimitedAccessActive) state.s4TargetApp else null,
            sessionSeconds = sessionSeconds,
            dailyDistractingSeconds = dailyDistractingSec,
            dailyProductiveSeconds = dailyProductiveSec,
            reentryCount = state.reentryCount,
            ignoredWarnings = state.ignoredWarnings,
            postLockReturnCount = state.postLockReturnCount,
            recentInterventionCount24h = recentInterventionCount24h,
            isFocusModeActive = isFocusMode,
            sensitivity = sensitivity,
            strength = strength,
            hourOfDay = calendar.get(Calendar.HOUR_OF_DAY),
            dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK),
            isManuallyLimited = isManuallyLimited,
            isBlacklisted = isBlacklisted,
        )
        return BehaviorAssessmentInput(
            facts = facts,
            features = BehaviorFeatureSnapshot.fromFacts(facts),
        )
    }

    private fun resolveEffectivePolicy(
        appCategory: Int,
        isManuallyLimited: Boolean,
        isBlacklisted: Boolean,
    ): BehaviorEffectivePolicy = when {
        isBlacklisted -> BehaviorEffectivePolicy.BLACKLIST
        isManuallyLimited -> BehaviorEffectivePolicy.MANUAL_LIMIT
        appCategory == AppClassifier.ESSENTIAL -> BehaviorEffectivePolicy.ESSENTIAL_ALLOW
        appCategory == AppClassifier.PRODUCTIVE -> BehaviorEffectivePolicy.PRODUCTIVE_ALLOW
        appCategory == AppClassifier.DISTRACTING -> BehaviorEffectivePolicy.DISTRACTING_MONITOR
        else -> BehaviorEffectivePolicy.NEUTRAL_MONITOR
    }
}
