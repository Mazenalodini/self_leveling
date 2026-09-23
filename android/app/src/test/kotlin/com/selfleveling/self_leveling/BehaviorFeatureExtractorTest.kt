package com.selfleveling.self_leveling

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BehaviorFeatureExtractorTest {

    @Test
    fun `build creates deterministic facts and feature snapshot`() {
        val now = 1_713_814_200_000L
        val state = AppEscalationState(
            currentStage = 4,
            s4AllowedUntilMs = now + 120_000L,
            s4TargetApp = "com.instagram.android",
            reentryCount = 2,
            ignoredWarnings = 3,
            postLockReturnCount = 1,
        )

        val input = BehaviorFeatureExtractor.build(
            packageName = "com.instagram.android",
            appName = "Instagram",
            appCategory = AppClassifier.DISTRACTING,
            state = state,
            sessionSeconds = 1800L,
            dailyDistractingSec = 7200L,
            dailyProductiveSec = 1800L,
            isFocusMode = true,
            isManuallyLimited = true,
            isBlacklisted = false,
            sensitivity = 0.7,
            strength = 0.8,
            recentInterventionCount24h = 5,
            now = now,
        )

        assertEquals("com.instagram.android", input.facts.packageName)
        assertEquals("Instagram", input.facts.appName)
        assertEquals(BehaviorEffectivePolicy.MANUAL_LIMIT, input.facts.effectivePolicy)
        assertTrue(input.facts.isLimitedAccessActive)
        assertEquals(4, input.facts.activeLockStage)
        assertEquals(30.0, input.features.sessionMinutes, 0.001)
        assertEquals("HIGH_RISK", input.features.appRiskTier)
        assertTrue(input.features.dailyDistractingRatio > 0.79)
        assertTrue(input.features.hourOfDayNormalized in 0.0..1.0)
        assertTrue(input.features.dayOfWeekNormalized in 0.0..1.0)
        assertEquals(5, input.features.recentInterventionCount24h)
    }
}
