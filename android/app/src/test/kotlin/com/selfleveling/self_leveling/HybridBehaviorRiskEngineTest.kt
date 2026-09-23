package com.selfleveling.self_leveling

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HybridBehaviorRiskEngineTest {

    @Test
    fun `hybrid engine blends tflite and rule scores`() {
        val input = sampleInput()
        val hybridEngine = HybridBehaviorRiskEngine(
            tfliteEngine = TFLiteBehaviorRiskEngine(context = null),
            ruleEngine = FixedRiskEngine(0.2),
            tfliteInferenceOverride = { _, _ ->
                TFLiteBehaviorRiskEngine.TFLiteScore(
                    score = 0.8,
                    riskClass = BehaviorRiskClass.CRITICAL,
                    modelVersion = "1.0.0",
                    threshold = 0.1126,
                    inputVectorSize = 19,
                )
            },
        )

        val assessment = hybridEngine.assess(input, createdAt = 123_456L)

        assertEquals(BehaviorAssessmentSource.HYBRID, assessment.source)
        assertEquals("hybrid", assessment.assessorKind)
        assertEquals(0.62, assessment.inference.riskScore, 0.0001)
        assertTrue(assessment.inference.riskScore in 0.0..1.0)
    }

    @Test
    fun `hybrid engine falls back to rule score when tflite is unavailable`() {
        val input = sampleInput()
        val hybridEngine = HybridBehaviorRiskEngine(
            tfliteEngine = TFLiteBehaviorRiskEngine(context = null),
            ruleEngine = FixedRiskEngine(0.31),
        )

        val assessment = hybridEngine.assess(input, createdAt = 123_456L)

        assertEquals(0.31, assessment.inference.riskScore, 0.0001)
        assertTrue(assessment.inference.reasoning.contains("fallback=rule_based"))
    }

    private fun sampleInput(): BehaviorAssessmentInput {
        return BehaviorFeatureExtractor.build(
            packageName = "com.instagram.android",
            appName = "Instagram",
            appCategory = AppClassifier.DISTRACTING,
            state = AppEscalationState(
                currentStage = 2,
                reentryCount = 1,
                ignoredWarnings = 2,
                postLockReturnCount = 1,
            ),
            sessionSeconds = 1800L,
            dailyDistractingSec = 7200L,
            dailyProductiveSec = 1800L,
            isFocusMode = true,
            isManuallyLimited = true,
            isBlacklisted = false,
            sensitivity = 0.7,
            strength = 0.8,
            recentInterventionCount24h = 5,
            now = 1_713_814_200_000L,
        )
    }

    private class FixedRiskEngine(
        private val score: Double,
    ) : BehaviorRiskEngine {
        override fun assess(
            input: BehaviorAssessmentInput,
            createdAt: Long,
        ): BehaviorAssessment {
            return BehaviorAssessment(
                createdAt = createdAt,
                source = BehaviorAssessmentSource.RULE_BASED,
                assessorKind = "rule_based",
                assessorVersion = "fixed_rule",
                targetPackageName = input.facts.packageName,
                targetAppName = input.facts.appName,
                facts = input.facts,
                features = input.features,
                inference = BehaviorRiskInference(
                    riskScore = score,
                    riskClass = BehaviorRiskClass.fromRiskScore(score),
                    appRiskTier = BehaviorRiskAssessor.getAppRiskTier(
                        input.facts.packageName,
                        input.facts.appCategoryCode,
                    ),
                    reasoning = "fixed_rule_score",
                ),
            )
        }
    }
}
