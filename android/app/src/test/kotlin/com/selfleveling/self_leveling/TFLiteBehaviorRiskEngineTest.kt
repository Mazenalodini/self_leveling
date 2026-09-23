package com.selfleveling.self_leveling

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TFLiteBehaviorRiskEngineTest {

    @Test
    fun `feature vector matches expected model length and unknown category stays safe`() {
        val input = sampleInput(
            packageName = "com.example.mystery_app",
            appCategory = AppClassifier.NEUTRAL,
        )
        val supplemental = TFLiteBehaviorRiskEngine.SupplementalFeatures(
            launchCountToday = 3,
            sessionIndexToday = 4,
            totalAppUsageTodayMinutes = 42.0,
            dailyLimitMinutes = 0.0,
            isWhitelisted = false,
        )
        val featureOrder = listOf(
            "duration_minutes",
            "launch_count_today",
            "session_index_today",
            "total_app_usage_today_minutes",
            "total_distracting_today_minutes",
            "daily_limit_minutes",
            "ignored_warning_count",
            "reentry_count",
            "hour_of_day",
            "day_of_week",
            "user_sensitivity",
            "escalation_strength",
            "is_focus_mode",
            "is_blacklisted",
            "is_whitelisted",
            "daily_limit_exceeded",
            "returned_after_block",
            "current_escalation_stage",
            "app_category_enc",
        )
        val normalization = TFLiteBehaviorRiskEngine.NormalizationStats(
            mean = mapOf("duration_minutes" to 10.0),
            std = mapOf("duration_minutes" to 2.0),
        )
        val featureMap = TFLiteBehaviorRiskEngine.buildFeatureMap(
            input = input,
            supplemental = supplemental,
            categoryMapping = mapOf("unknown" to 11),
        )

        val vector = TFLiteBehaviorRiskEngine.buildInputVector(
            featureOrder = featureOrder,
            normalizationStats = normalization,
            featureValues = featureMap,
        )

        assertEquals(featureOrder.size, vector.size)
        assertEquals(11.0, featureMap["app_category_enc"]!!, 0.0)
    }

    @Test
    fun `falls back to rule engine when model context is unavailable`() {
        val input = sampleInput()

        val assessment = TFLiteBehaviorRiskEngine(context = null).assess(
            input = input,
            createdAt = 123_456L,
        )

        assertEquals("rule_based", assessment.assessorKind)
        assertTrue(assessment.inference.riskScore in 0.0..1.0)
    }

    @Test
    fun `stage mapping clamps to s0 through s5`() {
        assertEquals(0, TFLiteBehaviorRiskEngine.mapStage(-2))
        assertEquals(3, TFLiteBehaviorRiskEngine.mapStage(3))
        assertEquals(5, TFLiteBehaviorRiskEngine.mapStage(9))
    }

    private fun sampleInput(
        packageName: String = "com.instagram.android",
        appCategory: Int = AppClassifier.DISTRACTING,
    ): BehaviorAssessmentInput {
        return BehaviorFeatureExtractor.build(
            packageName = packageName,
            appName = "Sample App",
            appCategory = appCategory,
            state = AppEscalationState(
                currentStage = 2,
                reentryCount = 1,
                ignoredWarnings = 2,
                postLockReturnCount = 1,
            ),
            sessionSeconds = 2400L,
            dailyDistractingSec = 5400L,
            dailyProductiveSec = 1200L,
            isFocusMode = true,
            isManuallyLimited = false,
            isBlacklisted = true,
            sensitivity = 0.8,
            strength = 0.6,
            recentInterventionCount24h = 4,
            now = 1_713_814_200_000L,
        )
    }
}
