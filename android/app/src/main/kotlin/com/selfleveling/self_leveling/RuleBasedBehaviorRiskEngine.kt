package com.selfleveling.self_leveling

/**
 * Current Phase 10 scoring boundary implementation.
 *
 * Today:
 *   rule-based assessor → [BehaviorAssessment]
 *
 * Future:
 *   model-backed assessor can implement [BehaviorRiskEngine] without forcing
 *   TrackingService / overlay / state machine rewrites.
 */
class RuleBasedBehaviorRiskEngine(
    private val assessorVersion: String = "behavior_risk_assessor_v2",
) : BehaviorRiskEngine {

    override fun assess(
        input: BehaviorAssessmentInput,
        createdAt: Long,
    ): BehaviorAssessment {
        val facts = input.facts
        val risk = BehaviorRiskAssessor.assess(
            packageName = facts.packageName,
            appCategory = facts.appCategoryCode,
            sessionSeconds = facts.sessionSeconds,
            reentryCount = facts.reentryCount,
            dailyDistractingSec = facts.dailyDistractingSeconds,
            dailyProductiveSec = facts.dailyProductiveSeconds,
            hourOfDay = facts.hourOfDay,
            isFocusMode = facts.isFocusModeActive,
            isManuallyLimited = facts.isManuallyLimited,
            isBlacklisted = facts.isBlacklisted,
            ignoredWarnings = facts.ignoredWarnings,
            postLockReturnCount = facts.postLockReturnCount,
            sensitivity = facts.sensitivity,
        )

        return BehaviorAssessment(
            createdAt = createdAt,
            source = BehaviorAssessmentSource.RULE_BASED,
            assessorKind = "rule_based",
            assessorVersion = assessorVersion,
            targetPackageName = facts.packageName,
            targetAppName = facts.appName,
            facts = facts,
            features = input.features,
            inference = BehaviorRiskInference(
                riskScore = risk.riskScore,
                riskClass = BehaviorRiskClass.fromLegacy(risk.riskLevel),
                appRiskTier = risk.appRiskTier,
                confidence = null,
                sessionFactor = risk.sessionFactor,
                behavioralFactor = risk.behavioralFactor,
                reasoning = risk.reasoning,
                predictedDistractionLikelihood = null,
            ),
        )
    }
}
