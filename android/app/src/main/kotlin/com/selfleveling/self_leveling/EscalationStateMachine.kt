package com.selfleveling.self_leveling

import android.util.Log

/**
 * Escalation State Machine — Layer B of Escalation Engine V2.
 *
 * Explicit state machine with well-defined transitions.
 * This is the CORE decision engine. It determines WHEN to transition
 * between escalation stages based on risk assessment + behavioral history.
 *
 * The state machine is DETERMINISTIC. Given the same inputs, it always
 * produces the same transition decision. No hidden state, no side effects.
 *
 * STAGE SEMANTICS:
 *   S0 = MONITORING     — quiet observation, no user-visible action
 *   S1 = WARNING         — first notification sent
 *   S2 = REMINDER        — stronger reminder sent
 *   S3 = LOCK            — full-screen overlay block (15 min default)
 *   S4 = LIMITED_ACCESS   — monitored limited access (15 min allowance)
 *   S5 = HARD_LOCK        — hard lock (60 min default)
 *
 * TRANSITION RULES:
 *   S0→S1: Risk ≥ MODERATE sustained for computed delay
 *   S1→S2: Continued elevated risk 15-20 min after S1
 *   S2→S3: Continued elevated risk 10-15 min after S2
 *   S3→S4: S3 lock expires → automatic transition
 *   S4→S5: S4 allowance consumed / pathological re-entry
 *   S4→S0: S4 used responsibly
 *   S5→S0: S5 hard lock expires
 *   S1→S0 / S2→S0: De-escalation when risk drops significantly
 */
object EscalationStateMachine {

    private const val TAG = "SL.StateMachine"

    // ═══════════════════════════════════════════
    // Escalation Policy Configuration
    // ═══════════════════════════════════════════

    /**
     * Escalation timing policy. Can be swapped for Focus Mode, testing, etc.
     */
    data class EscalationPolicy(
        // ── S0→S1 base delays (seconds) by risk tier ──
        val s0ToS1HighRiskSec: Long = 25 * 60L,     // 25 min
        val s0ToS1MediumRiskSec: Long = 35 * 60L,    // 35 min
        val s0ToS1LowRiskSec: Long = 45 * 60L,       // 45 min

        // ── Subsequent transition delays (seconds) ──
        val s1ToS2DelaySec: Long = 15 * 60L,          // 15 min after S1
        val s2ToS3DelaySec: Long = 10 * 60L,          // 10 min after S2

        // ── Lock durations (seconds) ──
        val s3LockDurationSec: Long = 15 * 60L,       // 15 min lock
        val s4AllowanceSec: Long = 15 * 60L,           // 15 min limited access
        val s5LockDurationSec: Long = 60 * 60L,        // 60 min hard lock

        // ── S4→S5 pathological re-entry window (seconds) ──
        val postLockReturnWindowSec: Long = 5 * 60L,   // 5 min window

        // ── De-escalation ──
        val deEscalationThreshold: Double = 0.12,
        val deEscalationTicksRequired: Int = 4,

        // ── S4 near-end warning thresholds (seconds) ──
        val s4FirstWarningSec: Int = 120,               // 2 min remaining
        val s4FinalWarningSec: Int = 30,                 // 30 sec remaining
    ) {
        /**
         * Get S0→S1 base delay for a given app risk tier.
         */
        fun getS0ToS1BaseSec(tier: BehaviorRiskAssessor.AppRiskTier): Long = when (tier) {
            BehaviorRiskAssessor.AppRiskTier.HIGH_RISK   -> s0ToS1HighRiskSec
            BehaviorRiskAssessor.AppRiskTier.MEDIUM_RISK -> s0ToS1MediumRiskSec
            BehaviorRiskAssessor.AppRiskTier.LOW_RISK    -> s0ToS1LowRiskSec
        }
    }

    // Pre-built policies
    val NORMAL_POLICY = EscalationPolicy()

    val FOCUS_POLICY = EscalationPolicy(
        s0ToS1HighRiskSec = 12 * 60L,      // ~12 min (50% of 25)
        s0ToS1MediumRiskSec = 17 * 60L,     // ~17 min (50% of 35)
        s0ToS1LowRiskSec = 22 * 60L,        // ~22 min (50% of 45)
        s1ToS2DelaySec = 8 * 60L,            // ~8 min (50% of 15)
        s2ToS3DelaySec = 5 * 60L,            // ~5 min (50% of 10)
        s3LockDurationSec = 15 * 60L,        // Same lock duration
        s4AllowanceSec = 10 * 60L,           // Shorter allowance in focus
        s5LockDurationSec = 60 * 60L,        // Same hard lock
        postLockReturnWindowSec = 8 * 60L,   // Wider window in focus
    )

    // ═══════════════════════════════════════════
    // Transition Decision
    // ═══════════════════════════════════════════

    /**
     * Possible transition outcomes from the state machine.
     */
    sealed class TransitionResult {
        /** No change — stay in current stage */
        object NoChange : TransitionResult()

        /** Escalate to a new stage */
        data class Escalate(val newStage: Int, val reason: String) : TransitionResult()

        /** De-escalate back to S0 */
        data class DeEscalate(val reason: String) : TransitionResult()

        /** S3 lock has expired → transition to S4 */
        data class LockExpired(val reason: String) : TransitionResult()

        /** S4 allowance consumed or abused → transition to S5 */
        data class AllowanceExhausted(val reason: String) : TransitionResult()

        /** S5 hard lock expired → back to S0 */
        data class HardLockExpired(val reason: String) : TransitionResult()

        /** S4 completed responsibly → back to S0 */
        data class RecoveryComplete(val reason: String) : TransitionResult()
    }

    /**
     * Evaluate current state and determine if a transition should occur.
     *
     * This is a PURE function. No side effects. The caller (EscalationEvaluator)
     * is responsible for applying the transition.
     *
     * @param currentStage    Current escalation stage (0–5)
     * @param risk            Risk assessment from BehaviorRiskAssessor
     * @param state           Per-app escalation state
     * @param policy          Active escalation policy (normal or focus)
     * @param now             Current time in milliseconds
     * @param strength        User's escalation strength setting (0.0–1.0)
     */
    fun evaluate(
        currentStage: Int,
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
        now: Long,
        strength: Double,
    ): TransitionResult {

        return when (currentStage) {
            0 -> evaluateS0(risk, state, policy, now, strength)
            1 -> evaluateS1(risk, state, policy, now, strength)
            2 -> evaluateS2(risk, state, policy, now, strength)
            3 -> evaluateS3(state, now)
            4 -> evaluateS4(risk, state, policy, now)
            5 -> evaluateS5(state, now)
            else -> TransitionResult.NoChange
        }
    }

    // ═══════════════════════════════════════════
    // S0: Monitoring → may escalate to S1
    // ═══════════════════════════════════════════
    private fun evaluateS0(
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
        now: Long,
        strength: Double,
    ): TransitionResult {
        // Need at least MODERATE risk to start considering escalation
        if (risk.riskLevel.ordinal < BehaviorRiskAssessor.RiskLevel.MODERATE.ordinal) {
            state.sustainedSince = 0L
            return TransitionResult.NoChange
        }

        // Start sustain timer
        if (state.sustainedSince == 0L) {
            state.sustainedSince = now
        }

        // Compute required delay with behavioral multipliers
        val baseDelaySec = policy.getS0ToS1BaseSec(risk.appRiskTier)
        val requiredMs = computeAdjustedDelay(baseDelaySec * 1000L, state, strength)
        val elapsed = now - state.sustainedSince

        Log.d(TAG, "S0→S1: elapsed=${elapsed/1000}s required=${requiredMs/1000}s " +
              "tier=${risk.appRiskTier} risk=${risk.riskLevel}")

        return if (elapsed >= requiredMs) {
            TransitionResult.Escalate(1, "Sustained ${risk.riskLevel} risk for ${elapsed/1000}s")
        } else {
            TransitionResult.NoChange
        }
    }

    // ═══════════════════════════════════════════
    // S1: Warning → may escalate to S2 or de-escalate to S0
    // ═══════════════════════════════════════════
    private fun evaluateS1(
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
        now: Long,
        strength: Double,
    ): TransitionResult {
        // De-escalation check
        val deEscResult = checkDeEscalation(risk, state, policy)
        if (deEscResult != null) return deEscResult

        // Need continued elevated risk for S1→S2
        if (risk.riskLevel.ordinal < BehaviorRiskAssessor.RiskLevel.MODERATE.ordinal) {
            return TransitionResult.NoChange
        }

        // Start sustain timer for S1→S2
        if (state.sustainedSince == 0L) {
            state.sustainedSince = now
        }

        val requiredMs = computeAdjustedDelay(policy.s1ToS2DelaySec * 1000L, state, strength)
        val elapsed = now - state.sustainedSince

        Log.d(TAG, "S1→S2: elapsed=${elapsed/1000}s required=${requiredMs/1000}s")

        return if (elapsed >= requiredMs) {
            TransitionResult.Escalate(2, "Ignored S1 for ${elapsed/1000}s, risk still ${risk.riskLevel}")
        } else {
            TransitionResult.NoChange
        }
    }

    // ═══════════════════════════════════════════
    // S2: Reminder → may escalate to S3 or de-escalate to S0
    // ═══════════════════════════════════════════
    private fun evaluateS2(
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
        now: Long,
        strength: Double,
    ): TransitionResult {
        // De-escalation check
        val deEscResult = checkDeEscalation(risk, state, policy)
        if (deEscResult != null) return deEscResult

        // Need continued elevated risk for S2→S3
        if (risk.riskLevel.ordinal < BehaviorRiskAssessor.RiskLevel.LOW.ordinal) {
            return TransitionResult.NoChange
        }

        // Start sustain timer for S2→S3
        if (state.sustainedSince == 0L) {
            state.sustainedSince = now
        }

        val requiredMs = computeAdjustedDelay(policy.s2ToS3DelaySec * 1000L, state, strength)
        val elapsed = now - state.sustainedSince

        Log.d(TAG, "S2→S3: elapsed=${elapsed/1000}s required=${requiredMs/1000}s")

        return if (elapsed >= requiredMs) {
            TransitionResult.Escalate(3, "Ignored S2 for ${elapsed/1000}s, escalating to lock")
        } else {
            TransitionResult.NoChange
        }
    }

    // ═══════════════════════════════════════════
    // S3: Active lock — waiting for expiry
    // ═══════════════════════════════════════════
    private fun evaluateS3(
        state: AppEscalationState,
        now: Long,
    ): TransitionResult {
        return if (state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            TransitionResult.LockExpired("S3 lock expired after ${(now - state.lockStartedAt) / 1000}s")
        } else {
            TransitionResult.NoChange  // Lock still active
        }
    }

    // ═══════════════════════════════════════════
    // S4: Limited access — monitoring allowance
    // ═══════════════════════════════════════════
    private fun evaluateS4(
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
        now: Long,
    ): TransitionResult {
        // Check if S4 window has expired
        if (state.s4AllowedUntilMs > 0L && now >= state.s4AllowedUntilMs) {
            // Time expired — was the user still using the distracting app?
            if (state.s4UsedSec > (policy.s4AllowanceSec * 0.8)) {
                // Used >80% of allowance — likely abusing → S5
                return TransitionResult.AllowanceExhausted(
                    "S4 allowance expired after ${state.s4UsedSec}s used of ${policy.s4AllowanceSec}s"
                )
            }
            // Used moderately or exited early → recovery
            return TransitionResult.RecoveryComplete(
                "S4 completed: used ${state.s4UsedSec}s of ${policy.s4AllowanceSec}s"
            )
        }

        // Check if allowance consumed while window still open
        if (state.s4UsedSec >= policy.s4AllowanceSec) {
            return TransitionResult.AllowanceExhausted(
                "S4 allowance fully consumed (${state.s4UsedSec}s >= ${policy.s4AllowanceSec}s)"
            )
        }

        // Check for excessive re-entry during S4
        if (state.s4EntryCount >= 5) {
            return TransitionResult.AllowanceExhausted(
                "Excessive re-entry during S4: ${state.s4EntryCount} entries"
            )
        }

        return TransitionResult.NoChange
    }

    // ═══════════════════════════════════════════
    // S5: Hard lock — waiting for expiry
    // ═══════════════════════════════════════════
    private fun evaluateS5(
        state: AppEscalationState,
        now: Long,
    ): TransitionResult {
        return if (state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            TransitionResult.HardLockExpired("S5 hard lock expired after ${(now - state.lockStartedAt) / 1000}s")
        } else {
            TransitionResult.NoChange
        }
    }

    // ═══════════════════════════════════════════
    // De-escalation Check (S1/S2 only)
    // ═══════════════════════════════════════════
    private fun checkDeEscalation(
        risk: BehaviorRiskAssessor.RiskAssessment,
        state: AppEscalationState,
        policy: EscalationPolicy,
    ): TransitionResult? {
        if (risk.riskScore < policy.deEscalationThreshold) {
            state.lowScoreTicks++
            if (state.lowScoreTicks >= policy.deEscalationTicksRequired) {
                return TransitionResult.DeEscalate(
                    "Risk dropped below ${policy.deEscalationThreshold} for ${state.lowScoreTicks} ticks"
                )
            }
        } else {
            state.lowScoreTicks = 0
        }
        return null
    }

    // ═══════════════════════════════════════════
    // Behavioral Delay Compression
    // ═══════════════════════════════════════════

    /**
     * Compute adjusted delay based on behavioral multipliers.
     *
     * Behavioral factors that compress delay:
     * - Re-entry count: each re-entry reduces delay by 15% (up to 60%)
     * - Ignored warnings: each ignored warning reduces delay by 12% (up to 50%)
     * - Post-lock returns: each return reduces delay by 25% (up to 50%)
     * - Strength setting: 0.0=×1.3 (more lenient), 0.5=×1.0, 1.0=×0.7 (stricter)
     *
     * Minimum delay floor: 15% of base (never instant escalation)
     */
    private fun computeAdjustedDelay(baseMs: Long, state: AppEscalationState, strength: Double): Long {
        // Re-entry compression: 15% per re-entry, max 60% reduction
        val reentryFactor = maxOf(0.40, 1.0 - (state.reentryCount * 0.15))

        // Ignored warnings compression: 12% per ignored, max 50% reduction
        val ignoredFactor = maxOf(0.50, 1.0 - (state.ignoredWarnings * 0.12))

        // Post-lock return compression: 25% per return, max 50% reduction
        val postLockFactor = maxOf(0.50, 1.0 - (state.postLockReturnCount * 0.25))

        // Strength modifier: 0.0=×1.3(lenient) 0.5=×1.0 1.0=×0.7(strict)
        val strengthFactor = 1.3 - (strength * 0.6)

        val multiplier = (reentryFactor * ignoredFactor * postLockFactor * strengthFactor)
            .coerceIn(0.15, 2.0) // floor at 15% of base, cap at 200%

        return (baseMs * multiplier).toLong()
    }

    /**
     * Check if a post-lock return qualifies for direct S5 escalation.
     *
     * @param lastLockEndTime When the last S3/S5 lock ended
     * @param now Current time
     * @param policy Active policy
     * @return true if the return is within the pathological re-entry window
     */
    fun isPathologicalReturn(lastLockEndTime: Long, now: Long, policy: EscalationPolicy): Boolean {
        if (lastLockEndTime == 0L) return false
        val timeSinceLockEnd = now - lastLockEndTime
        return timeSinceLockEnd in 1..policy.postLockReturnWindowSec * 1000L
    }
}

/**
 * Per-app escalation state — mutable state held by the orchestrator.
 *
 * This is the authoritative state for one app's escalation lifecycle.
 * It persists across ticks and is reset daily.
 */
data class AppEscalationState(
    // ── Current stage ──
    var currentStage: Int = 0,

    // ── Stage timestamps ──
    var stageEnteredAt: Long = 0L,
    var s1SentAt: Long = 0L,
    var s2SentAt: Long = 0L,

    // ── Lock lifecycle ──
    var lockUntilMs: Long = 0L,
    var lockStartedAt: Long = 0L,

    // ── S4 Limited Access Window ──
    var s4AllowedUntilMs: Long = 0L,
    var s4UsedSec: Long = 0L,
    var s4EntryCount: Int = 0,
    var s4DidExitEarly: Boolean = false,
    var s4WarningShown: Boolean = false,
    var s4FinalWarningShown: Boolean = false,
    var s4TargetApp: String? = null,

    // ── Behavioral history ──
    var reentryCount: Int = 0,
    var ignoredWarnings: Int = 0,
    var lockCount: Int = 0,
    var peakStage: Int = 0,
    var lastLockEndTime: Long = 0L,
    var postLockReturnCount: Int = 0,

    // ── Sustain tracking ──
    var sustainedSince: Long = 0L,
    var lowScoreTicks: Int = 0,

    // ── Notification cooldown ──
    var lastNotificationTime: Long = 0L,
    var lastInterventionTime: Long = 0L,

    // ── Scoring ──
    var currentRiskScore: Double = 0.0,
    var totalSessionSeconds: Long = 0L,
    var lastAssessmentPersistedAt: Long = 0L,
    var lastAssessmentSignature: String = "",

    // ── Policy snapshot (frozen on lock creation) ──
    var policySnapshot: LockedPolicySnapshot? = null,
) {
    fun isLockActive(now: Long): Boolean = lockUntilMs > now && currentStage in 3..5
    fun remainingLockSeconds(now: Long): Int {
        val r = ((lockUntilMs - now) / 1000L).toInt()
        return if (r > 0) r else 0
    }
    fun isInS4Window(now: Long): Boolean =
        currentStage == 4 && s4AllowedUntilMs > 0L && now < s4AllowedUntilMs
    fun s4RemainingSeconds(now: Long): Int {
        if (currentStage != 4 || s4AllowedUntilMs == 0L) return 0
        val r = ((s4AllowedUntilMs - now) / 1000L).toInt()
        return if (r > 0) r else 0
    }
}

/**
 * Frozen policy snapshot — persisted when a lock is created.
 * Active locks use this instead of live settings to prevent abuse
 * (user lowering settings during an active lock).
 */
data class LockedPolicySnapshot(
    val sensitivity: Double,
    val strength: Double,
    val s3LockDurationSec: Long,
    val s5LockDurationSec: Long,
    val s4AllowanceSec: Long,
) {
    fun toJson(): String = org.json.JSONObject().apply {
        put("sensitivity", sensitivity)
        put("strength", strength)
        put("s3LockDurationSec", s3LockDurationSec)
        put("s5LockDurationSec", s5LockDurationSec)
        put("s4AllowanceSec", s4AllowanceSec)
    }.toString()

    companion object {
        fun fromJson(json: String): LockedPolicySnapshot? = try {
            val o = org.json.JSONObject(json)
            LockedPolicySnapshot(
                sensitivity = o.optDouble("sensitivity", 0.5),
                strength = o.optDouble("strength", 0.5),
                s3LockDurationSec = o.optLong("s3LockDurationSec", 15 * 60L),
                s5LockDurationSec = o.optLong("s5LockDurationSec", 60 * 60L),
                s4AllowanceSec = o.optLong("s4AllowanceSec", 15 * 60L),
            )
        } catch (_: Exception) { null }
    }
}
