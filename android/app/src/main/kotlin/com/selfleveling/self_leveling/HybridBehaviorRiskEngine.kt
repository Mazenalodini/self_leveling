package com.selfleveling.self_leveling

import android.content.Context
import android.util.Log
import java.util.Locale
import kotlin.math.abs

class HybridBehaviorRiskEngine(
    private val tfliteEngine: TFLiteBehaviorRiskEngine,
    private val ruleEngine: BehaviorRiskEngine = RuleBasedBehaviorRiskEngine(),
    private val tfliteInferenceOverride: ((BehaviorAssessmentInput, Long) -> TFLiteBehaviorRiskEngine.TFLiteScore?)? = null,
) : BehaviorRiskEngine {

    companion object {
        private const val TAG = "TFLiteRiskEngine"
        private const val TFLITE_WEIGHT = 0.5
        private const val RULE_WEIGHT = 0.5
        private const val LOG_THROTTLE_MS = 30_000L
    }

    constructor(context: Context) : this(
        tfliteEngine = TFLiteBehaviorRiskEngine(context),
    )

    @Volatile
    var lastTfliteScore: Double? = null
        private set

    @Volatile
    var lastRuleScore: Double? = null
        private set

    @Volatile
    var lastHybridScore: Double? = null
        private set

    @Volatile
    var lastModelError: String? = null
        private set

    @Volatile
    private var lastLogSignature: String = ""

    @Volatile
    private var lastLogAt: Long = 0L

    override fun assess(
        input: BehaviorAssessmentInput,
        createdAt: Long,
    ): BehaviorAssessment {
        val ruleAssessment = ruleEngine.assess(input, createdAt)
        val ruleScore = ruleAssessment.inference.riskScore.coerceIn(0.0, 1.0)
        lastRuleScore = ruleScore

        val tfliteScore = try {
            tfliteInferenceOverride?.invoke(input, createdAt) ?:
                tfliteEngine.inferRiskScoreOrNull(input, createdAt)
        } catch (e: Exception) {
            lastModelError = e.message ?: e.javaClass.simpleName
            Log.w(TAG, "Hybrid inference wrapper failed", e)
            null
        }

       val blendedScore = if (tfliteScore == null) {
       ruleScore
        } else {
       ((tfliteScore.score * TFLITE_WEIGHT) + (ruleScore * RULE_WEIGHT))
          .coerceIn(0.0, 1.0)
              }

      val finalScore = if (tfliteScore == null) {
       ruleScore
        } else {
          maxOf(ruleScore, blendedScore).coerceIn(0.0, 1.0)
           }

        lastTfliteScore = tfliteScore?.score
        lastHybridScore = finalScore
        lastModelError = if (tfliteScore == null) {
            tfliteEngine.lastModelError ?: lastModelError
        } else {
            null
        }

        logAssessmentScores(
            ruleScore = ruleScore,
            tfliteScore = tfliteScore?.score,
            finalScore = finalScore,
            error = lastModelError,
            createdAt = createdAt,
        )

        val modelVersion = tfliteScore?.modelVersion ?: tfliteEngine.modelVersion ?: "unavailable"
        val reasoning = buildHybridReasoning(
            baseReasoning = ruleAssessment.inference.reasoning,
            tfliteScore = tfliteScore?.score,
            ruleScore = ruleScore,
            finalScore = finalScore,
            modelVersion = modelVersion,
            error = lastModelError,
        )

        return BehaviorAssessment(
            createdAt = createdAt,
            source = BehaviorAssessmentSource.HYBRID,
            assessorKind = "hybrid",
            assessorVersion = "hybrid_${modelVersion}_${ruleAssessment.assessorVersion}",
            targetPackageName = ruleAssessment.targetPackageName,
            targetAppName = ruleAssessment.targetAppName,
            facts = ruleAssessment.facts,
            features = ruleAssessment.features,
            runtimeEventId = ruleAssessment.runtimeEventId,
            labelState = ruleAssessment.labelState,
            inference = ruleAssessment.inference.copy(
                riskScore = finalScore,
                riskClass = BehaviorRiskClass.fromRiskScore(finalScore),
                confidence = tfliteScore?.let {
                    abs(it.score - it.threshold)
                } ?: ruleAssessment.inference.confidence,
                reasoning = reasoning,
                predictedDistractionLikelihood = tfliteScore?.score,
            ),
        )
    }

    private fun buildHybridReasoning(
        baseReasoning: String,
        tfliteScore: Double?,
        ruleScore: Double,
        finalScore: Double,
        modelVersion: String,
        error: String?,
    ): String {
        val base = baseReasoning.trim()
        val suffix = buildString {
            append("model_source=hybrid")
            append(" tflite_score=")
            append(tfliteScore?.let(::formatScore) ?: "null")
            append(" rule_based_score=")
            append(formatScore(ruleScore))
            append(" final_score=")
            append(formatScore(finalScore))
            append(" model_version=")
            append(modelVersion)
            if (error != null) {
                append(" fallback=rule_based")
                append(" error=")
                append(error)
            }
        }
        return if (base.isBlank()) suffix else "$base | $suffix"
    }

    private fun logAssessmentScores(
        ruleScore: Double,
        tfliteScore: Double?,
        finalScore: Double,
        error: String?,
        createdAt: Long,
    ) {
        val signature = listOf(
            bucket(ruleScore),
            tfliteScore?.let(::bucket) ?: "null",
            bucket(finalScore),
            error ?: "",
        ).joinToString("|")
        if (signature == lastLogSignature && createdAt - lastLogAt < LOG_THROTTLE_MS) {
            return
        }
        lastLogSignature = signature
        lastLogAt = createdAt

        tfliteScore?.let {
            Log.i(TAG, "TFLite inference score=${formatScore(it)}")
        }
        Log.i(TAG, "Rule-based score=${formatScore(ruleScore)}")
        Log.i(TAG, "Hybrid final score=${formatScore(finalScore)}")
        if (error != null) {
            Log.w(TAG, "Fallback used because of error: $error")
        }
    }

    private fun formatScore(score: Double): String =
        String.format(Locale.US, "%.4f", score)

    private fun bucket(score: Double): String =
        String.format(Locale.US, "%.2f", score)
}
