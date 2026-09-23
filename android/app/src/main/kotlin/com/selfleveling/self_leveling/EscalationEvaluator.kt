package com.selfleveling.self_leveling

import android.content.Context
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONObject

/**
 * Escalation Evaluator V2 — Orchestrator Layer C.
 *
 * Architecture:
 *   BehaviorFeatureExtractor → BehaviorRiskEngine (Layer A) →
 *   EscalationStateMachine (Layer B) → EscalationEvaluator (Layer C)
 *
 * This class orchestrates the escalation pipeline:
 *   1. Builds deterministic behavior facts + canonical feature inputs
 *   2. Calls BehaviorRiskEngine for risk scoring
 *   2. Feeds risk into EscalationStateMachine for transition decisions
 *   3. Applies transitions: creates locks, starts S4 windows, manages timers
 *   4. Manages intervention lifecycle: auto-dismiss, S3→S4 transition,
 *      S4 monitoring, notification delivery
 *   5. Builds InterventionPayload for OverlayManager / InterventionNotifier
 *   6. Persists lock state to SharedPreferences for crash recovery
 *   7. Persists throttled behavior assessments for future auditing/model prep
 *   8. Builds context-aware intervention messages
 *
 * KEY BEHAVIORS:
 *   - S3 lock auto-expires and transitions to S4 automatically
 *   - S4 is real monitored limited-access (no overlay, persistent notification)
 *   - S5 is naturally reachable via pathological re-entry or S4 abuse
 *   - Overlay dismisses automatically on lock expiry (no app-switch needed)
 *   - Focus Mode = stricter timing (not disabled)
 *   - Missing overlay permission = S1/S2 still work, S3+ degrades gracefully
 *   - Policy snapshot prevents settings abuse during active locks
 */
class EscalationEvaluator(
    private val context: Context,
    private val runtimeStore: NativeRuntimeStore,
    private val riskEngine: BehaviorRiskEngine = RuleBasedBehaviorRiskEngine(),
) {
    data class ActiveLockSnapshot(
        val packageName: String,
        val stage: Int,
        val expiresAtMs: Long,
        val remainingSeconds: Int,
    )

    companion object {
        private const val TAG = "SL.Escalation"
        private const val PREFS_NAME = "sl_active_locks"
        private const val NOTIFICATION_COOLDOWN_MS = 90_000L

        private const val DEFAULT_SENSITIVITY = 0.5
        private const val DEFAULT_STRENGTH = 0.5
    }

    private val appStates = mutableMapOf<String, AppEscalationState>()
    private var stateDate: String = ""

    // ── Lock persistence ──
    // This SharedPreferences store is an approved native recovery projection
    // for active lock facts only. It is not a conflicting product-facing
    // source of truth and exists strictly for low-latency runtime recovery.
    private val lockPrefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // ── Cached settings ──
    private var sensitivity = DEFAULT_SENSITIVITY
    private var strength = DEFAULT_STRENGTH
    private var userIdentity: String? = null
    private var lastSettingsRefresh = 0L

    // ── User overrides cache ──
    private var userOverrides = mapOf<String, Int>()
    private var blacklistedPackages = setOf<String>()
    private var limitedPackages = setOf<String>()
    private var lastOverridesRefresh = 0L

    // ── Habit context cache ──
    private var cachedHabits: List<String> = emptyList()
    private var lastHabitsRefresh = 0L
    private var cachedRecentInterventionCount24h = 0
    private var lastRecentInterventionCountRefresh = 0L

    // ═══════════════════════════════════════════
    // Lock Persistence (SharedPreferences)
    // ═══════════════════════════════════════════

    private fun persistLock(packageName: String, state: AppEscalationState, snapshot: LockedPolicySnapshot) {
        lockPrefs.edit()
            .putLong("lock_${packageName}_until", state.lockUntilMs)
            .putLong("lock_${packageName}_started", state.lockStartedAt)
            .putInt("lock_${packageName}_stage", state.currentStage)
            .putInt("lock_${packageName}_peak", state.peakStage)
            .putInt("lock_${packageName}_lockCount", state.lockCount)
            .putInt("lock_${packageName}_reentryCount", state.reentryCount)
            .putInt("lock_${packageName}_postLockReturnCount", state.postLockReturnCount)
            .putString("lock_${packageName}_policy", snapshot.toJson())
            // S4 fields
            .putLong("lock_${packageName}_s4Until", state.s4AllowedUntilMs)
            .putLong("lock_${packageName}_s4Used", state.s4UsedSec)
            .putInt("lock_${packageName}_s4Entries", state.s4EntryCount)
            .apply()
        Log.d(TAG, "Persisted: $packageName S${state.currentStage} lock=${state.lockUntilMs} s4Until=${state.s4AllowedUntilMs}")
    }

    private fun clearPersistedLock(packageName: String) {
        lockPrefs.edit().apply {
            listOf("until", "started", "stage", "peak", "lockCount", "reentryCount",
                "postLockReturnCount", "policy", "s4Until", "s4Used", "s4Entries"
            ).forEach { remove("lock_${packageName}_$it") }
        }.apply()
    }

    private fun clearAllPersistedLocks() {
        lockPrefs.edit().clear().apply()
    }

    private fun tryRestoreLock(packageName: String, state: AppEscalationState, now: Long): Boolean {
        val lockUntil = lockPrefs.getLong("lock_${packageName}_until", 0L)
        val lockStage = lockPrefs.getInt("lock_${packageName}_stage", 0)
        val peak = lockPrefs.getInt("lock_${packageName}_peak", 0)
        val lockCount = lockPrefs.getInt("lock_${packageName}_lockCount", 0)
        val reentryCount = lockPrefs.getInt("lock_${packageName}_reentryCount", 0)
        val postLockReturnCount = lockPrefs.getInt("lock_${packageName}_postLockReturnCount", 0)
        val policyJson = lockPrefs.getString("lock_${packageName}_policy", null)
        val lockStarted = lockPrefs.getLong("lock_${packageName}_started", 0L)
        val s4Until = lockPrefs.getLong("lock_${packageName}_s4Until", 0L)
        val s4Used = lockPrefs.getLong("lock_${packageName}_s4Used", 0L)
        val s4Entries = lockPrefs.getInt("lock_${packageName}_s4Entries", 0)

        if (lockStage == 0) return false

        // Restore common history
        state.peakStage = maxOf(state.peakStage, peak)
        state.lockCount = maxOf(state.lockCount, lockCount)
        state.reentryCount = maxOf(state.reentryCount, reentryCount)
        state.postLockReturnCount = maxOf(state.postLockReturnCount, postLockReturnCount)

        // Active S3/S5 lock
        if (lockStage in intArrayOf(3, 5) && lockUntil > now) {
            state.lockUntilMs = lockUntil
            state.lockStartedAt = lockStarted
            state.currentStage = lockStage
            state.policySnapshot = policyJson?.let { LockedPolicySnapshot.fromJson(it) }
            Log.i(TAG, "RESTORED S$lockStage lock: $packageName, ${state.remainingLockSeconds(now)}s left")
            return true
        }

        // Active S4 limited access
        if (lockStage == 4 && s4Until > now) {
            state.currentStage = 4
            state.s4AllowedUntilMs = s4Until
            state.s4UsedSec = s4Used
            state.s4EntryCount = s4Entries
            state.s4TargetApp = packageName
            state.policySnapshot = policyJson?.let { LockedPolicySnapshot.fromJson(it) }
            Log.i(TAG, "RESTORED S4 limited access: $packageName, ${state.s4RemainingSeconds(now)}s left")
            return true
        }

        // Expired lock — restore history
        if (lockUntil > 0L && lockUntil <= now) {
            state.lastLockEndTime = lockUntil
            state.policySnapshot = null
            clearPersistedLock(packageName)
            Log.i(TAG, "Expired lock cleared: $packageName (was S$lockStage)")
        }

        return false
    }

    // ═══════════════════════════════════════════
    // Main Entry Point
    // ═══════════════════════════════════════════

    /**
     * Evaluate the current app and return an intervention payload (or null).
     *
     * Called every tick (~2s) by TrackingService.
     *
     * Return semantics:
     *   null = no intervention → hide overlay if visible
     *   payload.stage 1-2 = notification (no overlay)
     *   payload.stage 3,5 = show overlay lock
     *   payload.stage 4 = S4 limited access (no overlay, handled via notification)
     */
    fun evaluate(
        currentApp: String,
        appName: String,
        cumulativeFgSeconds: Long,
        dailyDistractingSec: Long,
        dailyProductiveSec: Long,
        db: SQLiteDatabase?,
        isFocusMode: Boolean = false,
    ): InterventionPayload? {
        val now = System.currentTimeMillis()

        // ── Daily reset ──
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date(now))
        if (today != stateDate) {
            appStates.clear()
            stateDate = today
            lastSettingsRefresh = 0L
            lastOverridesRefresh = 0L
            lastHabitsRefresh = 0L
            cachedRecentInterventionCount24h = 0
            lastRecentInterventionCountRefresh = 0L
            clearAllPersistedLocks()
        }

        // ── Refresh settings (30s) ──
        if (db != null && now - lastSettingsRefresh > 30_000L) {
            refreshSettings(db); lastSettingsRefresh = now
        }
        if (db != null && now - lastOverridesRefresh > 30_000L) {
            refreshUserOverrides(db); lastOverridesRefresh = now
        }
        if (db != null && now - lastHabitsRefresh > 60_000L) {
            refreshHabits(db); lastHabitsRefresh = now
        }

        // ══════════════════════════════════════════
        // CLASSIFICATION GATE — only escalate on the right apps
        // ══════════════════════════════════════════
        val category = AppClassifier.classify(currentApp, userOverrides)

        // ESSENTIAL → never escalate
        if (category == AppClassifier.ESSENTIAL) return null

        // PRODUCTIVE → never escalate (unless user explicitly set a limit)
        if (category == AppClassifier.PRODUCTIVE && !limitedPackages.contains(currentApp)) return null

        // NEUTRAL → never escalate (unless user blacklisted or limited)
        if (category == AppClassifier.NEUTRAL
            && !blacklistedPackages.contains(currentApp)
            && !limitedPackages.contains(currentApp)) return null

        // ── Per-app state ──
        val state = appStates.getOrPut(currentApp) { AppEscalationState() }
        state.totalSessionSeconds = cumulativeFgSeconds

        // ═══ LOCK RECOVERY from SharedPreferences ═══
        if (state.currentStage == 0 && state.lockUntilMs == 0L && state.s4AllowedUntilMs == 0L) {
            tryRestoreLock(currentApp, state, now)
        }

        // ═══ ACTIVE S3/S5 LOCK ═══
        if (state.currentStage in intArrayOf(3, 5) && state.isLockActive(now)) {
            return buildLockPayload(state.currentStage, currentApp, appName, state, now)
        }

        // ═══ S3 LOCK JUST EXPIRED → TRANSITION TO S4 ═══
        if (state.currentStage == 3 && state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            return transitionS3ToS4(currentApp, appName, state, now, isFocusMode, db)
        }

        // ═══ S5 HARD LOCK JUST EXPIRED → BACK TO S0 ═══
        if (state.currentStage == 5 && state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            val expiredStage = state.currentStage
            state.lastLockEndTime = state.lockUntilMs
            state.lockUntilMs = 0L
            state.lockStartedAt = 0L
            state.currentStage = 0
            state.sustainedSince = 0L
            state.policySnapshot = null
            clearPersistedLock(currentApp)
            logEscalationEvent(currentApp, expiredStage, 0, "S5 hard lock expired", state)
            Log.i(TAG, "S5 expired: $currentApp → S0")
            return null  // Hide overlay this tick
        }

        // ═══ ACTIVE S4 LIMITED ACCESS ═══
        if (state.currentStage == 4) {
            return handleS4Tick(currentApp, appName, state, now, isFocusMode, db)
        }

        // ═══ STALE S3+ WITHOUT LOCK → reset ═══
        if (state.currentStage >= 3 && !state.isLockActive(now) && state.s4AllowedUntilMs == 0L) {
            state.currentStage = 0
            state.sustainedSince = 0L
        }

        // ── Check for pathological return (direct S5) ──
        val policy = if (isFocusMode) EscalationStateMachine.FOCUS_POLICY else EscalationStateMachine.NORMAL_POLICY
        if (state.currentStage == 0 && state.lastLockEndTime > 0L) {
            if (EscalationStateMachine.isPathologicalReturn(state.lastLockEndTime, now, policy)) {
                state.postLockReturnCount++
                if (state.postLockReturnCount >= 2) {
                    Log.i(TAG, "PATHOLOGICAL RETURN: $currentApp (return #${state.postLockReturnCount}) → S5")
                    return escalateToLock(currentApp, appName, state, 5, now, isFocusMode, db,
                        "Pathological re-entry #${state.postLockReturnCount} within ${policy.postLockReturnWindowSec/60}min")
                }
            }
        }

        // ── Risk assessment via Phase 10 boundary ──
        val assessmentInput = BehaviorFeatureExtractor.build(
            packageName = currentApp,
            appName = appName,
            appCategory = category,
            state = state,
            sessionSeconds = cumulativeFgSeconds,
            dailyDistractingSec = dailyDistractingSec,
            dailyProductiveSec = dailyProductiveSec,
            isFocusMode = isFocusMode,
            isManuallyLimited = limitedPackages.contains(currentApp),
            isBlacklisted = blacklistedPackages.contains(currentApp),
            sensitivity = sensitivity,
            strength = strength,
            recentInterventionCount24h = loadRecentInterventionCount24h(db, now),
            now = now,
        )
        val assessment = riskEngine.assess(assessmentInput, createdAt = now)
        val risk = assessment.inference.toLegacyRiskAssessment()

        state.currentRiskScore = assessment.inference.riskScore
        persistBehaviorAssessmentIfNeeded(state, assessment, now)

        // ── State machine evaluation ──
        val transition = EscalationStateMachine.evaluate(
            currentStage = state.currentStage,
            risk = risk,
            state = state,
            policy = policy,
            now = now,
            strength = strength,
        )

        // ── Apply transition ──
        return applyTransition(transition, currentApp, appName, state, risk, now, isFocusMode, db)
    }

    // ═══════════════════════════════════════════
    // Transition Application
    // ═══════════════════════════════════════════

    private fun applyTransition(
        transition: EscalationStateMachine.TransitionResult,
        packageName: String,
        appName: String,
        state: AppEscalationState,
        risk: BehaviorRiskAssessor.RiskAssessment,
        now: Long,
        isFocusMode: Boolean,
        db: SQLiteDatabase?,
    ): InterventionPayload? {

        return when (transition) {
            is EscalationStateMachine.TransitionResult.NoChange -> {
                maintainCurrentStage(packageName, appName, state, now)
            }

            is EscalationStateMachine.TransitionResult.Escalate -> {
                val newStage = transition.newStage
                if (newStage >= 3) {
                    escalateToLock(packageName, appName, state, newStage, now, isFocusMode, db, transition.reason)
                } else {
                    // S1 or S2 transition
                    val oldStage = state.currentStage
                    state.currentStage = newStage
                    state.peakStage = maxOf(state.peakStage, newStage)
                    state.stageEnteredAt = now
                    state.sustainedSince = 0L
                    state.lastInterventionTime = now
                    state.lastNotificationTime = now
                    if (newStage == 1) state.s1SentAt = now
                    if (newStage == 2) state.s2SentAt = now

                    logEscalationEvent(packageName, oldStage, newStage, transition.reason, state)
                    Log.i(TAG, "Escalated $packageName: S$oldStage → S$newStage (${transition.reason})")

                    buildNotificationPayload(newStage, packageName, appName, state, now)
                }
            }

            is EscalationStateMachine.TransitionResult.DeEscalate -> {
                val prev = state.currentStage
                state.currentStage = 0
                state.sustainedSince = 0L
                state.lowScoreTicks = 0
                state.stageEnteredAt = now
                logEscalationEvent(packageName, prev, 0, transition.reason, state)
                Log.i(TAG, "De-escalated $packageName: S$prev → S0 (${transition.reason})")
                null  // No intervention
            }

            is EscalationStateMachine.TransitionResult.LockExpired -> {
                // S3 expired → handled in evaluate() directly for immediate auto-dismiss
                null
            }

            is EscalationStateMachine.TransitionResult.AllowanceExhausted -> {
                // S4 exhausted → S5
                Log.i(TAG, "S4 exhausted for $packageName → S5 (${transition.reason})")
                logEscalationEvent(packageName, 4, 5, transition.reason, state)
                escalateToLock(packageName, appName, state, 5, now, isFocusMode, db, transition.reason)
            }

            is EscalationStateMachine.TransitionResult.HardLockExpired -> {
                // S5 expired → handled in evaluate() directly
                null
            }

            is EscalationStateMachine.TransitionResult.RecoveryComplete -> {
                // S4 completed responsibly → S0
                state.currentStage = 0
                state.s4AllowedUntilMs = 0L
                state.s4UsedSec = 0L
                state.s4EntryCount = 0
                state.sustainedSince = 0L
                state.stageEnteredAt = now
                state.policySnapshot = null
                clearPersistedLock(state.s4TargetApp ?: "")
                logEscalationEvent(packageName, 4, 0, transition.reason, state)
                Log.i(TAG, "Recovery complete: ${state.s4TargetApp} S4 → S0 (${transition.reason})")
                null
            }
        }
    }

    // ═══════════════════════════════════════════
    // S3 → S4 Automatic Transition
    // ═══════════════════════════════════════════

    private fun transitionS3ToS4(
        packageName: String,
        appName: String,
        state: AppEscalationState,
        now: Long,
        isFocusMode: Boolean,
        db: SQLiteDatabase?,
    ): InterventionPayload? {
        val policy = if (isFocusMode) EscalationStateMachine.FOCUS_POLICY else EscalationStateMachine.NORMAL_POLICY
        val snapshot = state.policySnapshot

        // Record lock end
        state.lastLockEndTime = state.lockUntilMs
        state.lockUntilMs = 0L
        state.lockStartedAt = 0L

        // Transition to S4
        state.currentStage = 4
        state.stageEnteredAt = now
        state.s4AllowedUntilMs = now + (snapshot?.s4AllowanceSec ?: policy.s4AllowanceSec) * 1000L
        state.s4UsedSec = 0L
        state.s4EntryCount = 0
        state.s4DidExitEarly = false
        state.s4WarningShown = false
        state.s4FinalWarningShown = false
        state.s4TargetApp = packageName

        // Persist S4 state
        val policyForPersist = snapshot ?: LockedPolicySnapshot(
            sensitivity = sensitivity,
            strength = strength,
            s3LockDurationSec = policy.s3LockDurationSec,
            s5LockDurationSec = policy.s5LockDurationSec,
            s4AllowanceSec = policy.s4AllowanceSec,
        )
        persistLock(packageName, state, policyForPersist)

        logEscalationEvent(
            packageName,
            3,
            4,
            "S3 lock expired → S4 limited access (${policy.s4AllowanceSec/60}min)",
            state,
        )
        Log.i(TAG, "S3→S4: $packageName, ${policy.s4AllowanceSec/60}min limited access")

        // Return null to HIDE the overlay immediately
        // S4 is overlay-free — monitoring only via notification
        return null
    }

    // ═══════════════════════════════════════════
    // S4 Tick Handler
    // ═══════════════════════════════════════════

    private fun handleS4Tick(
        packageName: String,
        appName: String,
        state: AppEscalationState,
        now: Long,
        isFocusMode: Boolean,
        db: SQLiteDatabase?,
    ): InterventionPayload? {
        val policy = if (isFocusMode) EscalationStateMachine.FOCUS_POLICY else EscalationStateMachine.NORMAL_POLICY

        // If this is the target S4 app and user is using it, accumulate time
        if (packageName == state.s4TargetApp || state.s4TargetApp == null) {
            state.s4UsedSec += 2  // ~2 seconds per tick
        }

        // Check S4 lifecycle via state machine
        val risk = BehaviorRiskAssessor.RiskAssessment(
            riskScore = state.currentRiskScore,
            riskLevel = BehaviorRiskAssessor.RiskLevel.HIGH,
            appRiskTier = BehaviorRiskAssessor.AppRiskTier.HIGH_RISK,
            sessionFactor = 0.0,
            behavioralFactor = 0.0,
            reasoning = "S4 tick"
        )

        val transition = EscalationStateMachine.evaluate(
            currentStage = 4, risk = risk, state = state, policy = policy, now = now, strength = strength
        )

        // Apply transition if S4 changed
        if (transition !is EscalationStateMachine.TransitionResult.NoChange) {
            return applyTransition(transition, packageName, appName, state, risk, now, isFocusMode, db)
        }

        // S4 still active — build notification-based payload (no overlay)
        // The TrackingService will use this to show/update notification, NOT overlay
        return buildS4Payload(packageName, appName, state, now, isFocusMode)
    }

    // ═══════════════════════════════════════════
    // Escalate to Lock (S3 or S5)
    // ═══════════════════════════════════════════

    private fun escalateToLock(
        packageName: String, appName: String,
        state: AppEscalationState,
        targetStage: Int,
        now: Long, isFocusMode: Boolean,
        db: SQLiteDatabase?,
        reason: String,
    ): InterventionPayload {
        val policy = if (isFocusMode) EscalationStateMachine.FOCUS_POLICY else EscalationStateMachine.NORMAL_POLICY
        val oldStage = state.currentStage

        // Freeze policy snapshot
        val snapshot = LockedPolicySnapshot(
            sensitivity = sensitivity,
            strength = strength,
            s3LockDurationSec = policy.s3LockDurationSec,
            s5LockDurationSec = policy.s5LockDurationSec,
            s4AllowanceSec = policy.s4AllowanceSec,
        )
        state.policySnapshot = snapshot

        // Set lock duration
        val durationSec = when (targetStage) {
            3 -> snapshot.s3LockDurationSec
            5 -> snapshot.s5LockDurationSec
            else -> snapshot.s3LockDurationSec
        }

        // Apply lock count multiplier (each additional lock 15% longer, max 2x)
        val countMultiplier = minOf(2.0, 1.0 + (state.lockCount * 0.15))
        val effectiveDurationMs = (durationSec * 1000L * countMultiplier).toLong()

        state.currentStage = targetStage
        state.peakStage = maxOf(state.peakStage, targetStage)
        state.stageEnteredAt = now
        state.lockStartedAt = now
        state.lockUntilMs = now + effectiveDurationMs
        state.sustainedSince = 0L
        state.lastInterventionTime = now
        state.lockCount++

        // Clear S4 state if escalating
        state.s4AllowedUntilMs = 0L
        state.s4UsedSec = 0L
        state.s4EntryCount = 0

        persistLock(packageName, state, snapshot)

        logEscalationEvent(
            packageName,
            oldStage,
            targetStage,
            "Lock #${state.lockCount}: ${effectiveDurationMs/60000}min — $reason",
            state,
        )
        Log.i(TAG, "LOCK $packageName: S$oldStage → S$targetStage (${effectiveDurationMs/60000}min, lock#${state.lockCount})")

        return buildLockPayload(targetStage, packageName, appName, state, now)
    }

    // ═══════════════════════════════════════════
    // App Lifecycle Hooks (called by TrackingService)
    // ═══════════════════════════════════════════

    fun onAppExit(previousApp: String) {
        val state = appStates[previousApp] ?: return
        val now = System.currentTimeMillis()

        // S4: user exited the distracting app during limited access
        if (state.currentStage == 4 && state.s4TargetApp == previousApp) {
            state.s4DidExitEarly = true
            Log.d(TAG, "S4 exit: $previousApp (used ${state.s4UsedSec}s)")
        }
    }

    fun onAppReentry(app: String) {
        val state = appStates[app] ?: return
        val now = System.currentTimeMillis()

        // S4: re-entry during limited access
        if (state.currentStage == 4 && state.s4TargetApp == app) {
            state.s4EntryCount++
            Log.d(TAG, "S4 re-entry for $app (#${state.s4EntryCount})")
        }

        // Post-lock re-entry tracking
        if (state.lastLockEndTime > 0L && state.currentStage < 3) {
            val timeSinceLock = now - state.lastLockEndTime
            if (timeSinceLock < 10 * 60_000L) {
                state.postLockReturnCount++
                Log.d(TAG, "Post-lock re-entry for $app (#${state.postLockReturnCount})")
            }
        }

        // Post-warning re-entry (S1/S2)
        if (state.lastInterventionTime > 0L && state.currentStage in 1..2) {
            if (now - state.lastInterventionTime < 10 * 60_000L) {
                state.ignoredWarnings++
                Log.d(TAG, "Warning ignored for $app (#${state.ignoredWarnings})")
            }
        }

        // DO NOT reset sustainedSince here.
        // The evaluateS0/S1/S2 functions already handle risk-based de-escalation:
        //   - evaluateS0: resets sustainedSince when risk drops below MODERATE
        //   - evaluateS1/S2: checkDeEscalation returns DeEscalate after N low-risk ticks
        // Resetting here was causing phantom timer resets because:
        //   1. Android notification delivery briefly changes foreground process
        //   2. TrackingService detects app switch → onAppReentry fires
        //   3. sustainedSince resets → S0→S1 and S1→S2 timers restart from 0
        // This made it nearly impossible to reach any escalation threshold.
    }

    /**
     * Get the current S4 state for a package (for TrackingService to check).
     */
    fun getS4State(packageName: String): AppEscalationState? {
        val state = appStates[packageName] ?: return null
        return if (state.currentStage == 4) state else null
    }

    /**
     * Get ALL current S4 states (for TrackingService to find any active S4).
     */
    fun getActiveS4(): Pair<String, AppEscalationState>? {
        return appStates.entries.firstOrNull { it.value.currentStage == 4 }
            ?.let { it.key to it.value }
    }

    fun getActiveLockSnapshot(now: Long = System.currentTimeMillis()): ActiveLockSnapshot? {
        appStates.entries.forEach { (packageName, state) ->
            if (state.currentStage == 0 && state.lockUntilMs == 0L && state.s4AllowedUntilMs == 0L) {
                tryRestoreLock(packageName, state, now)
            }
        }

        val activeEntry = appStates.entries.firstOrNull { (_, state) ->
            state.currentStage in intArrayOf(3, 5) && state.isLockActive(now)
        } ?: return null

        return ActiveLockSnapshot(
            packageName = activeEntry.key,
            stage = activeEntry.value.currentStage,
            expiresAtMs = activeEntry.value.lockUntilMs,
            remainingSeconds = activeEntry.value.remainingLockSeconds(now),
        )
    }

    fun getActiveLockPayloadFor(
        packageName: String,
        appName: String,
        now: Long = System.currentTimeMillis(),
        isFocusMode: Boolean = false,
    ): InterventionPayload? {
        val state = appStates.getOrPut(packageName) { AppEscalationState() }
        if (state.currentStage == 0 && state.lockUntilMs == 0L && state.s4AllowedUntilMs == 0L) {
            tryRestoreLock(packageName, state, now)
        }

        if (state.currentStage in intArrayOf(3, 5) && state.isLockActive(now)) {
            return buildLockPayload(state.currentStage, packageName, appName, state, now)
        }

        if (state.currentStage == 3 && state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            return transitionS3ToS4(
                packageName = packageName,
                appName = appName,
                state = state,
                now = now,
                isFocusMode = isFocusMode,
                db = null,
            )
        }

        if (state.currentStage == 5 && state.lockUntilMs > 0L && now >= state.lockUntilMs) {
            val expiredStage = state.currentStage
            state.lastLockEndTime = state.lockUntilMs
            state.lockUntilMs = 0L
            state.lockStartedAt = 0L
            state.currentStage = 0
            state.sustainedSince = 0L
            state.policySnapshot = null
            clearPersistedLock(packageName)
            logEscalationEvent(packageName, expiredStage, 0, "Timed block expired", state)
            Log.i(TAG, "Timed block expired: $packageName S$expiredStage → S0")
        }

        return null
    }

    // ═══════════════════════════════════════════
    // Maintain Current Stage (no transition)
    // ═══════════════════════════════════════════

    private fun maintainCurrentStage(
        packageName: String, appName: String,
        state: AppEscalationState, now: Long,
    ): InterventionPayload? {
        // Active lock → always return lock payload
        if (state.currentStage in intArrayOf(3, 5) && state.isLockActive(now)) {
            return buildLockPayload(state.currentStage, packageName, appName, state, now)
        }

        // S4 → return S4 payload (notification-based)
        if (state.currentStage == 4) {
            return buildS4Payload(packageName, appName, state, now)
        }

        // Stale S3+ without lock → reset
        if (state.currentStage >= 3 && !state.isLockActive(now)) {
            state.currentStage = 0
            state.sustainedSince = 0L
            clearPersistedLock(packageName)
            return null
        }

        // S1/S2 → re-deliver notification on cooldown
        if (state.currentStage in 1..2) {
            if (now - state.lastNotificationTime > NOTIFICATION_COOLDOWN_MS) {
                state.lastNotificationTime = now
                return buildNotificationPayload(state.currentStage, packageName, appName, state, now)
            }
        }

        return null
    }

    // ═══════════════════════════════════════════
    // Payload Builders
    // ═══════════════════════════════════════════

    /**
     * Build context-aware intervention message.
     */
    private fun buildContextMessage(stage: Int, appName: String, state: AppEscalationState): String {
        val usageMin = (state.totalSessionSeconds / 60).toInt()
        val hourOfDay = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        val timeContext = when {
            hourOfDay in 22..23 || hourOfDay in 0..5 -> "late_night"
            hourOfDay in 6..8 -> "morning"
            hourOfDay in 20..21 -> "evening"
            else -> "day"
        }
        val res = context.resources

        return try {
            when (stage) {
                1 -> res.getString(R.string.s1_message, appName, usageMin)
                2 -> res.getString(R.string.s2_message, appName, usageMin)
                3 -> res.getString(R.string.s3_message, appName)
                4 -> res.getString(R.string.s4_message, appName, state.s4RemainingSeconds(System.currentTimeMillis()) / 60)
                5 -> res.getString(R.string.s5_message, appName, state.lockCount)
                else -> res.getString(R.string.s0_message, appName)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Message format error S$stage", e)
            "$appName — Stage $stage active"
        }
    }

    /**
     * Build suggested action based on local context.
     */
    private fun buildSuggestedAction(stage: Int): String? {
        val res = context.resources
        // If we have cached habits, suggest the most relevant
        val habitSuggestion = if (cachedHabits.isNotEmpty()) {
            cachedHabits.firstOrNull()
        } else null

        return when (stage) {
            1 -> habitSuggestion?.let { "💡 Try working on: $it" } ?: res.getString(R.string.s1_suggestion)
            2 -> habitSuggestion?.let { "💡 Your habit '$it' needs attention" } ?: res.getString(R.string.s2_suggestion)
            3 -> res.getString(R.string.s3_suggestion)
            4 -> res.getString(R.string.s4_suggestion)
            else -> null
        }
    }

    /**
     * Build reminder text using identity context.
     */
    private fun buildReminderText(stage: Int): String? {
        val identity = userIdentity ?: return null
        val res = context.resources
        return when (stage) {
            1 -> res.getString(R.string.s1_reminder, identity)
            2 -> res.getString(R.string.s2_reminder, identity)
            3 -> res.getString(R.string.s3_reminder, identity)
            4 -> res.getString(R.string.s4_reminder, identity)
            else -> null
        }
    }

    private fun buildNotificationPayload(
        stage: Int, packageName: String, appName: String,
        state: AppEscalationState, now: Long,
    ): InterventionPayload {
        val res = context.resources
        return InterventionPayload(
            stage = stage,
            mode = OverlayMode.BEHAVIOR_WARNING,
            title = when (stage) {
                1 -> res.getString(R.string.s1_title)
                2 -> res.getString(R.string.s2_title)
                else -> res.getString(R.string.s0_title)
            },
            message = buildContextMessage(stage, appName, state),
            appName = appName,
            packageName = packageName,
            reason = when (stage) {
                1 -> res.getString(R.string.s1_reason)
                2 -> res.getString(R.string.s2_reason)
                else -> "S$stage"
            },
            canDismiss = true,
            reminderText = buildReminderText(stage),
            suggestedAction = buildSuggestedAction(stage),
            reentryCount = state.reentryCount,
            distractionScore = state.currentRiskScore,
            contextIgnoredCount = state.ignoredWarnings,
            contextTimeOfDay = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY).let {
                when {
                    it in 22..23 || it in 0..5 -> "night"
                    it in 6..8 -> "morning"
                    it in 20..21 -> "evening"
                    else -> "day"
                }
            },
        )
    }

    private fun buildLockPayload(
        stage: Int, packageName: String, appName: String,
        state: AppEscalationState, now: Long,
    ): InterventionPayload {
        val remainingSec = state.remainingLockSeconds(now)
        val remainMin = remainingSec / 60
        val remainSecPart = remainingSec % 60
        val res = context.resources

        val (mode, title, reason) = try {
            when (stage) {
                3 -> Triple(OverlayMode.BEHAVIOR_WARNING,
                    res.getString(R.string.s3_title),
                    res.getString(R.string.s3_reason, state.lockCount, (state.totalSessionSeconds / 60).toInt()))
                5 -> Triple(OverlayMode.HARD_LOCK,
                    res.getString(R.string.s5_title),
                    res.getString(R.string.s5_reason))
                else -> Triple(OverlayMode.BEHAVIOR_WARNING,
                    res.getString(R.string.s3_title),
                    "Lock active")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Lock payload format error S$stage", e)
            Triple(OverlayMode.BEHAVIOR_WARNING, "LOCK", "Lock active")
        }

        val resetText = when (stage) {
            3 -> res.getString(R.string.s3_reset, remainMin, remainSecPart)
            5 -> res.getString(R.string.s5_reset, remainMin, remainSecPart)
            else -> null
        }

        return InterventionPayload(
            stage = stage,
            mode = mode,
            title = title,
            message = buildContextMessage(stage, appName, state),
            appName = appName,
            packageName = packageName,
            reason = reason,
            durationSeconds = remainingSec,
            canDismiss = false,
            reminderText = buildReminderText(stage),
            suggestedAction = buildSuggestedAction(stage),
            reentryCount = state.reentryCount,
            xpPenalty = if (stage == 5) 10 else 0,
            resetText = resetText,
            distractionScore = state.currentRiskScore,
            contextIgnoredCount = state.ignoredWarnings,
            actionLabel = res.getString(R.string.exit_app_action),
            showExitAppAction = true,
        )
    }

    private fun buildS4Payload(
        packageName: String, appName: String,
        state: AppEscalationState, now: Long,
        isFocusMode: Boolean = false,
    ): InterventionPayload {
        val remainingSec = state.s4RemainingSeconds(now)
        val remainMin = remainingSec / 60
        val remainSecPart = remainingSec % 60
        val res = context.resources
        val policy = if (isFocusMode) EscalationStateMachine.FOCUS_POLICY else EscalationStateMachine.NORMAL_POLICY

        return InterventionPayload(
            stage = 4,
            mode = OverlayMode.LIMITED_ACCESS,
            title = res.getString(R.string.s4_title),
            message = buildContextMessage(4, appName, state),
            appName = appName,
            packageName = packageName,
            reason = res.getString(R.string.s4_reason),
            durationSeconds = remainingSec,
            canDismiss = false,
            reminderText = buildReminderText(4),
            suggestedAction = buildSuggestedAction(4),
            reentryCount = state.reentryCount,
            xpPenalty = 0,
            resetText = res.getString(R.string.s4_reset, remainMin, remainSecPart),
            distractionScore = state.currentRiskScore,
            contextIgnoredCount = state.ignoredWarnings,
            isLimitedAccess = true,
            limitedAccessRemainingSec = remainingSec,
            s4WarningNeeded = !state.s4WarningShown && remainingSec <= policy.s4FirstWarningSec,
            s4FinalWarningNeeded = !state.s4FinalWarningShown && remainingSec <= policy.s4FinalWarningSec,
        )
    }

    // ═══════════════════════════════════════════
    // Settings & Data Refresh
    // ═══════════════════════════════════════════

    private fun refreshSettings(db: SQLiteDatabase) {
        try {
            val cursor = db.rawQuery("SELECT key, value FROM settings", null)
            while (cursor.moveToNext()) {
                val key = cursor.getString(0) ?: continue
                val value = cursor.getString(1) ?: continue
                when (key) {
                    RuntimeSettingKeys.SYSTEM_SENSITIVITY ->
                        sensitivity = value.toDoubleOrNull()?.coerceIn(0.0, 1.0) ?: sensitivity
                    RuntimeSettingKeys.ESCALATION_STRENGTH ->
                        strength = value.toDoubleOrNull()?.coerceIn(0.0, 1.0) ?: strength
                }
            }
            cursor.close()

            val pCursor = db.rawQuery(
                "SELECT identity_statement FROM user_profile WHERE id = 'default'", null
            )
            if (pCursor.moveToFirst()) {
                val id = pCursor.getString(0)
                userIdentity = if (id.isNullOrBlank()) null else id
            }
            pCursor.close()
        } catch (e: Exception) { Log.w(TAG, "Settings refresh failed", e) }
    }

    private fun refreshUserOverrides(db: SQLiteDatabase) {
        userOverrides = AppClassifier.loadUserOverrides(db)
        val bl = mutableSetOf<String>()
        val lm = mutableSetOf<String>()
        try {
            val c = db.rawQuery(
                "SELECT package_name, list_type, daily_limit_minutes FROM app_list WHERE is_enabled = 1 AND package_name != ''", null
            )
            while (c.moveToNext()) {
                val pkg = c.getString(0)
                if (c.getString(1) == "blacklist") bl.add(pkg)
                if (c.getInt(2) > 0) lm.add(pkg)
            }
            c.close()
        } catch (_: Exception) {}
        blacklistedPackages = bl; limitedPackages = lm
    }

    private fun refreshHabits(db: SQLiteDatabase) {
        try {
            // Schema: habits(id, name, type, frequency, current_streak, longest_streak,
            //   xp_reward, reminder_time, sort_order, created_at, is_active)
            val c = db.rawQuery(
                "SELECT name FROM habits WHERE is_active = 1 ORDER BY created_at DESC LIMIT 3", null
            )
            val habits = mutableListOf<String>()
            while (c.moveToNext()) {
                c.getString(0)?.let { habits.add(it) }
            }
            c.close()
            cachedHabits = habits
        } catch (_: Exception) {
            // habits table may not exist yet or schema mismatch
        }
    }

    private fun loadRecentInterventionCount24h(db: SQLiteDatabase?, now: Long): Int {
        if (db == null) return cachedRecentInterventionCount24h
        if (now - lastRecentInterventionCountRefresh < 60_000L) {
            return cachedRecentInterventionCount24h
        }

        return try {
            val since = now - (24L * 60L * 60L * 1000L)
            val cursor = db.rawQuery(
                "SELECT COUNT(*) FROM escalation_events WHERE timestamp >= ?",
                arrayOf(since.toString()),
            )
            val count = cursor.use {
                if (it.moveToFirst()) it.getInt(0) else 0
            }
            cachedRecentInterventionCount24h = count
            lastRecentInterventionCountRefresh = now
            count
        } catch (e: Exception) {
            Log.w(TAG, "Recent intervention count refresh failed", e)
            cachedRecentInterventionCount24h
        }
    }

    private fun persistBehaviorAssessmentIfNeeded(
        state: AppEscalationState,
        assessment: BehaviorAssessment,
        now: Long,
    ) {
        val scoreBucket = (assessment.inference.riskScore * 10.0).toInt()
        val signature = listOf(
            assessment.targetPackageName,
            assessment.facts.currentStage,
            assessment.facts.effectivePolicy.storageValue,
            assessment.inference.riskClass.storageValue,
            scoreBucket,
            if (assessment.facts.hasActiveLock) 1 else 0,
            if (assessment.facts.isLimitedAccessActive) 1 else 0,
        ).joinToString(":")

        val shouldPersist = state.lastAssessmentSignature != signature ||
            now - state.lastAssessmentPersistedAt >= 60_000L
        if (!shouldPersist) return

        runtimeStore.appendBehaviorAssessment(assessment)
        state.lastAssessmentSignature = signature
        state.lastAssessmentPersistedAt = now
    }

    private fun logEscalationEvent(
        packageName: String,
        from: Int,
        to: Int,
        reason: String,
        state: AppEscalationState,
    ) {
        runtimeStore.appendInterventionEvent(
            fromLevel = from,
            toLevel = to,
            packageName = packageName,
            reason = reason,
            riskScore = state.currentRiskScore,
            reentryCount = state.reentryCount,
            xpPenalty = if (to == 5) 10 else 0,
        )
    }
}
