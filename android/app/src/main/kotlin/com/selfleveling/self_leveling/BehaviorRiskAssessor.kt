package com.selfleveling.self_leveling

import kotlin.math.ln

/**
 * Behavior Risk Assessor — Layer A of Escalation Engine V2.
 *
 * PURE risk scoring layer. Stateless. No escalation decisions.
 * Evaluates the current behavioral context and produces a risk assessment.
 *
 * Architecture: designed to be replaceable by TFLite in the future.
 * Interface contract: context inputs → risk assessment output.
 *
 * SCORING MODEL (V2):
 *
 *   DESIGN GOAL:
 *     Multi-factor behavioral risk assessment where session duration is
 *     important but NOT dominant. Behavioral signals (re-entry, ignored
 *     warnings, post-lock return) carry significant weight so that
 *     repeat offenders escalate faster than first-time users.
 *
 *   RISK-TIERED BASELINES:
 *     High-risk apps (TikTok, Instagram, etc.):  S0→S1 at ~25-30 min
 *     Medium distracting apps:                    S0→S1 at ~35-40 min
 *     Lower-risk distracting apps:                S0→S1 at ~45 min
 *
 *   FOCUS MODE:
 *     Increases risk score by 1.3x (stricter, not disabled).
 *     Combined with 0.5x delay multiplier in the state machine,
 *     focus mode dramatically accelerates escalation.
 */
object BehaviorRiskAssessor {

    /**
     * Risk levels — semantic meaning for the state machine.
     */
    enum class RiskLevel {
        NONE,       // No risk detected
        LOW,        // Mild usage, no concern
        MODERATE,   // Sustained usage on distracting app
        HIGH,       // Long session + behavioral signals
        CRITICAL,   // Pathological usage pattern
    }

    /**
     * App risk tier — determines baseline escalation timing.
     */
    enum class AppRiskTier {
        HIGH_RISK,    // Short-form / infinite-feed / highly addictive
        MEDIUM_RISK,  // Social / streaming / moderate distraction
        LOW_RISK,     // Lower distraction potential
    }

    /**
     * Output of the risk assessment. Consumed by EscalationStateMachine.
     */
    data class RiskAssessment(
        /** Overall risk score: 0.0 (no risk) to 1.0 (maximum risk) */
        val riskScore: Double,

        /** Semantic risk level for state machine transition decisions */
        val riskLevel: RiskLevel,

        /** App risk tier for escalation timing policy */
        val appRiskTier: AppRiskTier,

        /** How much session time contributed to the score */
        val sessionFactor: Double,

        /** How much behavioral context contributed to the score */
        val behavioralFactor: Double,

        /** Human-readable reasoning for diagnostics */
        val reasoning: String,
    )

    // ═══════════════════════════════════════════
    // High-risk: short-form / infinite-feed apps
    // ═══════════════════════════════════════════
    private val highRiskPackages = setOf(
        "com.zhiliaoapp.musically",    // TikTok
        "com.ss.android.ugc.trill",    // TikTok alt
        "com.instagram.android",
        "com.snapchat.android",
        "com.google.android.youtube",
        "com.reddit.frontpage",
        "com.kwai.video",
        "likee.real.video",
        "com.bigo.live",
        "tv.twitch.android.app",
    )

    private val highRiskPatterns = listOf(
        "tiktok", "instagram", "snapchat", "youtube", "reddit", "twitch",
    )

    // ═══════════════════════════════════════════
    // Medium-risk: social / streaming / gaming
    // ═══════════════════════════════════════════
    private val mediumRiskPackages = setOf(
        "com.facebook.katana",
        "com.facebook.lite",
        "com.facebook.orca",
        "com.twitter.android",
        "com.twitter.android.lite",
        "com.pinterest",
        "com.tumblr",
        "com.linkedin.android",
        "com.netflix.mediaclient",
        "com.amazon.avod.thirdpartyclient",
        "com.disney.disneyplus",
        "com.hulu.livingroomplus",
        "com.google.android.apps.youtube.music",
    )

    /**
     * Determine the risk tier for a package.
     */
    fun getAppRiskTier(packageName: String, appCategory: Int): AppRiskTier {
        if (highRiskPackages.contains(packageName)) return AppRiskTier.HIGH_RISK
        val lower = packageName.lowercase()
        if (highRiskPatterns.any { lower.contains(it) }) return AppRiskTier.HIGH_RISK
        if (mediumRiskPackages.contains(packageName)) return AppRiskTier.MEDIUM_RISK
        // Games are medium risk
        if (lower.contains("game") || lower.contains("puzzle") ||
            lower.contains("casino") || lower.contains("slots")) return AppRiskTier.MEDIUM_RISK
        // Default distracting apps are low risk
        if (appCategory == AppClassifier.DISTRACTING) return AppRiskTier.LOW_RISK
        return AppRiskTier.LOW_RISK
    }

    /**
     * Main assessment entry point.
     *
     * @param appCategory       AppClassifier category (PRODUCTIVE/NEUTRAL/DISTRACTING/etc.)
     * @param sessionSeconds    Current continuous session on this app
     * @param reentryCount      Times user re-entered this app after leaving
     * @param dailyDistractingSec Total distracting screen time today
     * @param dailyProductiveSec  Total productive screen time today
     * @param hourOfDay         Current hour (0–23)
     * @param isFocusMode       Whether focus mode is active
     * @param isManuallyLimited  User set a daily limit on this app
     * @param isBlacklisted      User explicitly blacklisted this app
     * @param ignoredWarnings    Number of S1/S2 warnings ignored
     * @param postLockReturnCount Times user returned after a lock ended
     * @param sensitivity       User's sensitivity setting (0.0–1.0)
     */
    fun assess(
        packageName: String,
        appCategory: Int,
        sessionSeconds: Long,
        reentryCount: Int,
        dailyDistractingSec: Long,
        dailyProductiveSec: Long,
        hourOfDay: Int,
        isFocusMode: Boolean,
        isManuallyLimited: Boolean,
        isBlacklisted: Boolean,
        ignoredWarnings: Int,
        postLockReturnCount: Int,
        sensitivity: Double,
    ): RiskAssessment {

        // Essential / productive apps → no risk
        if (appCategory == AppClassifier.ESSENTIAL) {
            return RiskAssessment(0.0, RiskLevel.NONE, AppRiskTier.LOW_RISK, 0.0, 0.0, "Essential app")
        }
        if (appCategory == AppClassifier.PRODUCTIVE && !isBlacklisted && !isManuallyLimited) {
            return RiskAssessment(0.02, RiskLevel.NONE, AppRiskTier.LOW_RISK, 0.0, 0.0, "Productive app")
        }

        val appRiskTier = getAppRiskTier(packageName, appCategory)

        // ─── Factor 1: App Category Base (20%) ───
        val categoryBase = when {
            isBlacklisted -> 0.80
            appCategory == AppClassifier.DISTRACTING -> when (appRiskTier) {
                AppRiskTier.HIGH_RISK   -> 0.70
                AppRiskTier.MEDIUM_RISK -> 0.55
                AppRiskTier.LOW_RISK    -> 0.40
            }
            appCategory == AppClassifier.NEUTRAL -> 0.15
            isManuallyLimited -> 0.50
            else -> 0.30
        }

        // ─── Factor 2: Session Duration (30%) ───
        // Logarithmic curve calibrated to risk tier baselines.
        // Higher-risk apps accumulate session score faster.
        val sessionMinutes = sessionSeconds / 60.0
        val tierSessionDivisor = when (appRiskTier) {
            AppRiskTier.HIGH_RISK   -> 3.8  // Reaches MODERATE threshold ~25 min
            AppRiskTier.MEDIUM_RISK -> 4.2  // Reaches MODERATE threshold ~35 min
            AppRiskTier.LOW_RISK    -> 4.8  // Reaches MODERATE threshold ~45 min
        }
        val sessionScore = (ln(1.0 + sessionMinutes) / tierSessionDivisor).coerceIn(0.0, 1.0)

        // ─── Factor 3: Behavioral Signals (20%) ───
        // Re-entries, ignored warnings, post-lock returns
        var behavioralScore = 0.0
        // Re-entry penalty (0–0.35)
        behavioralScore += when {
            reentryCount == 0 -> 0.0
            reentryCount == 1 -> 0.10
            reentryCount == 2 -> 0.20
            reentryCount >= 3 -> 0.35
            else -> 0.0
        }
        // Ignored warning penalty (0–0.35)
        behavioralScore += (ignoredWarnings * 0.12).coerceAtMost(0.35)
        // Post-lock return penalty (0–0.30) — strongest behavioral signal
        behavioralScore += when {
            postLockReturnCount == 0 -> 0.0
            postLockReturnCount == 1 -> 0.15
            postLockReturnCount >= 2 -> 0.30
            else -> 0.0
        }
        behavioralScore = behavioralScore.coerceAtMost(1.0)

        // ─── Factor 4: Daily Context (15%) ───
        val dailyTotalSec = dailyDistractingSec + dailyProductiveSec
        val dailyDistractionRatio = if (dailyTotalSec > 0) {
            dailyDistractingSec.toDouble() / dailyTotalSec
        } else 0.0

        var contextScore = dailyDistractionRatio * 0.6
        if (isManuallyLimited) contextScore += 0.15
        if (isBlacklisted) contextScore += 0.25
        contextScore = contextScore.coerceAtMost(1.0)

        // ─── Factor 5: Temporal Context (10%) ───
        val timePenalty = when {
            hourOfDay in 22..23 || hourOfDay in 0..5 -> 0.70   // Late night — high risk
            hourOfDay in 20..21 -> 0.40                         // Evening
            hourOfDay in 6..8   -> 0.25                         // Early morning
            hourOfDay in 12..13 -> 0.05                         // Lunch break — low penalty
            else -> 0.15                                        // Normal hours
        }

        // ─── Factor 6: User Override Signals (5%) ───
        var overrideScore = 0.0
        if (isBlacklisted) overrideScore += 0.60
        if (isManuallyLimited) overrideScore += 0.40
        overrideScore = overrideScore.coerceAtMost(1.0)

        // ─── Weighted combination ───
        val rawScore = (0.20 * categoryBase) +
                       (0.30 * sessionScore) +
                       (0.20 * behavioralScore) +
                       (0.15 * contextScore) +
                       (0.10 * timePenalty) +
                       (0.05 * overrideScore)

        // Apply sensitivity: 0.0=×0.6, 0.5=×1.0, 1.0=×1.4
        val sensitivityFactor = 0.6 + (sensitivity * 0.8)

        // Focus mode: 1.3x risk multiplier (stricter, not disabled)
        val focusFactor = if (isFocusMode) 1.3 else 1.0

        val finalScore = (rawScore * sensitivityFactor * focusFactor).coerceIn(0.0, 1.0)

        // ─── Risk level mapping ───
        val riskLevel = when {
            finalScore < 0.12 -> RiskLevel.NONE
            finalScore < 0.25 -> RiskLevel.LOW
            finalScore < 0.40 -> RiskLevel.MODERATE
            finalScore < 0.60 -> RiskLevel.HIGH
            else              -> RiskLevel.CRITICAL
        }

        val reasoning = buildString {
            append("tier=${appRiskTier.name}")
            append(" cat=${AppClassifier.categoryName(appCategory)}")
            append(" sess=${sessionMinutes.toInt()}m")
            append(" re=$reentryCount")
            append(" ign=$ignoredWarnings")
            append(" pLock=$postLockReturnCount")
            append(" beh=${(behavioralScore * 100).toInt()}%")
            append(" raw=${(rawScore * 100).toInt()}%")
            if (isFocusMode) append(" FOCUS")
            append(" → ${riskLevel.name} (${(finalScore * 100).toInt()}%)")
        }

        return RiskAssessment(
            riskScore = finalScore,
            riskLevel = riskLevel,
            appRiskTier = appRiskTier,
            sessionFactor = sessionScore,
            behavioralFactor = behavioralScore,
            reasoning = reasoning,
        )
    }
}
