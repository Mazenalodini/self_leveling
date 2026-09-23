package com.selfleveling.self_leveling

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleBasedBehaviorRiskEngineTest {

    @Test
    fun `rule based engine wraps current scorer behind behavior risk engine boundary`() {
        val input = BehaviorFeatureExtractor.build(
            packageName = "com.instagram.android",
            appName = "Instagram",
            appCategory = AppClassifier.DISTRACTING,
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

        val assessment = RuleBasedBehaviorRiskEngine().assess(
            input = input,
            createdAt = 123_456L,
        )

        assertEquals(BehaviorAssessmentSource.RULE_BASED, assessment.source)
        assertEquals("rule_based", assessment.assessorKind)
        assertEquals("com.instagram.android", assessment.targetPackageName)
        assertEquals(123_456L, assessment.createdAt)
        assertEquals(input.facts.packageName, assessment.facts.packageName)
        assertTrue(assessment.inference.riskScore in 0.0..1.0)
        assertEquals(
            assessment.inference.riskClass,
            BehaviorRiskClass.fromLegacy(
                assessment.inference.toLegacyRiskAssessment().riskLevel,
            ),
        )
        assertEquals(
            assessment.inference.appRiskTier,
            assessment.inference.toLegacyRiskAssessment().appRiskTier,
        )
    }
}
