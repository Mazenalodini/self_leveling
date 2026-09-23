package com.selfleveling.self_leveling

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Native Android Foreground Service for continuous behavior monitoring.
 *
 * Two parallel enforcement paths:
 *   1. Usage-Limit Enforcement — daily limit blocks
 *   2. Behavior-Based Escalation — staged S0–S5 interventions
 *
 * V2 — ESCALATION ENGINE V2
 *
 * Key design decisions:
 *
 * 1. OVERLAY IS DRIVEN BY EVALUATOR DECISION
 *    - S3/S5 → show overlay lock
 *    - S4 → NO overlay (persistent notification only)
 *    - S1/S2 → notification only
 *    - null → hide overlay
 *
 * 2. S4 LIMITED ACCESS HANDLING
 *    - S4 payloads go through InterventionNotifier (persistent notification)
 *    - No overlay shown during S4
 *    - S4 near-end warnings delivered as heads-up notifications
 *    - When S4 transitions to S5, overlay is shown immediately
 *
 * 3. AUTO-DISMISS
 *    - When evaluator returns null after a lock, overlay is hidden immediately
 *    - OverlayManager also auto-dismisses when its countdown reaches zero
 *
 * 4. FOCUS MODE
 *    - Makes escalation stricter (not disabled, not paused)
 *    - Passed to evaluator which uses FOCUS_POLICY
 *
 * 5. PERMISSION DEGRADATION
 *    - Missing Usage → no monitoring (early return)
 *    - Missing Overlay → S1/S2/S4 still work, S3/S5 overlay skipped
 *    - Missing Notification → core logic unaffected, delivery degrades
 */
class TrackingService : Service() {
    private enum class ForegroundSource {
        ACCESSIBILITY,
        POLL,
    }

    companion object {
        const val CHANNEL_ID = "self_leveling_tracking"
        const val NOTIFICATION_ID = 1001
        private const val TAG = "SL.TrackingService"
        private const val ENFORCE_INTERVAL_MS = 2000L
        private const val LIMITS_REFRESH_MS   = 30_000L
        private const val USAGE_REFRESH_MS    = 15_000L
        private const val ACCESSIBILITY_STALE_MS = 1200L
        private const val ACTIVE_LOCK_TRANSIENT_EXIT_GRACE_MS = 900L
        private const val USAGE_LIMIT_TRANSIENT_EXIT_GRACE_MS = 900L

        const val ACTION_LIMITS_CHANGED = "com.selfleveling.LIMITS_CHANGED"

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var currentInstance: TrackingService? = null
            private set

        // ── Native → Flutter state bridge ──
        @Volatile
        private var stateListener: ((RuntimeStateSnapshot) -> Unit)? = null

        fun setStateListener(listener: ((RuntimeStateSnapshot) -> Unit)?) {
            stateListener = listener
        }

        fun clearStateListener() {
            stateListener = null
        }

        @Volatile
        var currentNativeState: RuntimeStateSnapshot = buildDefaultState()
            private set

        private fun buildDefaultState(): RuntimeStateSnapshot =
            RuntimeStateSnapshot()
    }

    // ── Dependencies ──
    private lateinit var usageStatsHelper: UsageStatsHelper
    private lateinit var overlayManager: OverlayManager
    private lateinit var escalationEvaluator: EscalationEvaluator
    private lateinit var interventionNotifier: InterventionNotifier
    private lateinit var runtimeStore: NativeRuntimeStore
    private lateinit var usageSnapshotStore: NativeUsageSnapshotStore

    // ── Threading ──
    private var handlerThread: HandlerThread? = null
    private var bgHandler: Handler? = null
    private val mainHandler = Handler(android.os.Looper.getMainLooper())

    // ══════════════════════════════════════════
    // Usage-Limit Enforcement State
    // ══════════════════════════════════════════
    private data class AppLimit(val packageName: String, val name: String, val maxSeconds: Long)

    private var cachedLimits: List<AppLimit> = emptyList()
    private var prevLimitMap: Map<String, Long> = emptyMap()
    private var lastLimitsRefresh: Long = 0L
    private var lastUsageRefresh: Long = 0L

    private val usageSecondsMap = mutableMapOf<String, Long>()
    private val localAccSeconds = mutableMapOf<String, Long>()
    private val lockedToday = mutableSetOf<String>()
    private var lockedDate: String = ""

    // ══════════════════════════════════════════
    // App name cache + common state
    // ══════════════════════════════════════════
    private val appNameCache = mutableMapOf<String, String>()
    private var lastKnownForeground: String? = null
    private var lastTickTime: Long = 0L
    private var isUsageLimitOverlayShowing = false
    private var activeUsageLimitAttachmentPackage: String? = null
    private var pendingUsageLimitDetachPackage: String? = null
    private var pendingUsageLimitDetachStartedAt: Long = 0L
    private var dbHandle: android.database.sqlite.SQLiteDatabase? = null
    private var lastDbOpen: Long = 0L
    private var lastNullFgLog: Long = 0L
    @Volatile
    private var limitsRefreshPending = false
    private var activeInterventionId: String? = null
    private var lastPersistedRuntimeSignature: String = ""
    private var activeLockAttachmentPackage: String? = null
    private var pendingActiveLockDetachPackage: String? = null
    private var pendingActiveLockDetachStartedAt: Long = 0L
    private val accessibilityListener =
        AccessibilityForegroundMonitor.Listener { packageName, eventTime ->
            bgHandler?.post {
                processForegroundSignal(
                    signaledPackage = packageName,
                    now = eventTime.takeIf { it > 0L } ?: System.currentTimeMillis(),
                    hasOverlayPermission = android.provider.Settings.canDrawOverlays(this),
                    source = ForegroundSource.ACCESSIBILITY,
                )
            }
        }

    // ── V3: Local Intelligence Payload Cache ──
    private var lastPayloadSignature: String = ""
    private var lastRichPayload: InterventionPayload? = null

    // ── Focus Mode flag (set by Flutter via MethodChannel) ──
    @Volatile
    var isFocusModeActive: Boolean = false

    private val enforceRunnable = object : Runnable {
        override fun run() {
            try { mainLoop() } catch (e: Exception) { Log.e(TAG, "mainLoop error", e) }
            bgHandler?.postDelayed(this, ENFORCE_INTERVAL_MS)
        }
    }

    // ═══════════════════════════════════════════
    // Service Lifecycle
    // ═══════════════════════════════════════════
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        AppClassifier.setContext(this)  // Enable dynamic game detection
        usageStatsHelper = UsageStatsHelper(this)
        overlayManager = OverlayManager(this)
        runtimeStore = NativeRuntimeStore(this)
        usageSnapshotStore = NativeUsageSnapshotStore(this, usageStatsHelper)
        isFocusModeActive = runtimeStore.isFocusModePersisted()
        currentNativeState = runtimeStore.restoreRuntimeSnapshot()
        escalationEvaluator = EscalationEvaluator(
            context = this,
            runtimeStore = runtimeStore,
            riskEngine = HybridBehaviorRiskEngine(this),
        )
        interventionNotifier = InterventionNotifier(this)
        handlerThread = HandlerThread("SL-Enforce").also { it.start() }
        bgHandler = Handler(handlerThread!!.looper)
        AccessibilityForegroundMonitor.registerListener(accessibilityListener)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_LIMITS_CHANGED) {
            Log.i(TAG, "Limits changed signal received")
            requestLimitsRefresh()
            return START_STICKY
        }

        if (isRunning && currentInstance === this) {
            Log.i(TAG, "TrackingService start ignored — already running")
            broadcastState()
            return START_STICKY
        }

        isRunning = true
        currentInstance = this
        broadcastState()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.tracking_notification_title))
            .setContentText(getString(R.string.tracking_notification_text))
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        bgHandler?.removeCallbacks(enforceRunnable)
        bgHandler?.post(enforceRunnable)
        Log.i(TAG, "TrackingService started")

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        currentInstance = null
        activeInterventionId = null
        broadcastState()
        bgHandler?.removeCallbacks(enforceRunnable)
        mainHandler.post { overlayManager.hideOverlay() }
        interventionNotifier.dismissAll()
        handlerThread?.quitSafely()
        handlerThread = null; bgHandler = null
        AccessibilityForegroundMonitor.unregisterListener(accessibilityListener)
        closeDb()
        Log.i(TAG, "TrackingService destroyed")
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "onTaskRemoved — keeping foreground service alive without UI")
        super.onTaskRemoved(rootIntent)
    }

    fun requestLimitsRefresh() {
        if (limitsRefreshPending) {
            Log.d(TAG, "Limits refresh already pending — coalescing request")
            return
        }
        limitsRefreshPending = true
        bgHandler?.post {
            try {
                forceRefreshLimits()
            } finally {
                limitsRefreshPending = false
            }
        }
    }

    // ═══════════════════════════════════════════
    // Main Loop
    // ═══════════════════════════════════════════
    private fun mainLoop() {
        if (!usageStatsHelper.hasPermission()) return
        val hasOverlayPermission = android.provider.Settings.canDrawOverlays(this)

        val now = System.currentTimeMillis()

        // ── Daily reset ──
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date(now))
        if (today != lockedDate) {
            lockedToday.clear()
            localAccSeconds.clear()
            usageSecondsMap.clear()
            appNameCache.clear()
            lockedDate = today
            lastLimitsRefresh = 0L
            lastUsageRefresh = 0L
            prevLimitMap = emptyMap()
        }

        // ── DB handle ──
        if (dbHandle == null || now - lastDbOpen > 300_000L) openDb()

        // ── Refresh limits (30s) ──
        if (now - lastLimitsRefresh > LIMITS_REFRESH_MS) {
            refreshLimitsFromDb()
            lastLimitsRefresh = now
        }

        // ── Refresh usage stats (15s) ──
        if (now - lastUsageRefresh > USAGE_REFRESH_MS) {
            refreshUsageTotals(now)
            lastUsageRefresh = now
        }

        val source = if (
            AccessibilityForegroundMonitor.isConnected() &&
            AccessibilityForegroundMonitor.hasSnapshot()
        ) {
            val accessibilityAge = AccessibilityForegroundMonitor.snapshotAgeMs(now)
            if (accessibilityAge <= ACCESSIBILITY_STALE_MS) {
                ForegroundSource.ACCESSIBILITY
            } else {
                ForegroundSource.POLL
            }
        } else {
            ForegroundSource.POLL
        }
        val currentApp = if (source == ForegroundSource.ACCESSIBILITY) {
            AccessibilityForegroundMonitor.currentPackage()
        } else {
            usageStatsHelper.getCurrentForegroundApp()
        }

        processForegroundSignal(
            signaledPackage = currentApp,
            now = now,
            hasOverlayPermission = hasOverlayPermission,
            source = source,
        )
    }

    private fun processForegroundSignal(
        signaledPackage: String?,
        now: Long,
        hasOverlayPermission: Boolean,
        source: ForegroundSource,
    ) {
        if (signaledPackage == null && source == ForegroundSource.POLL) {
            if (now - lastNullFgLog > 30_000L) {
                Log.w(
                    TAG,
                    "Foreground app = null (${source.name.lowercase()}) — last known: $lastKnownForeground",
                )
                lastNullFgLog = now
            }
        }

        val activeLockSnapshot = escalationEvaluator.getActiveLockSnapshot(now)
        val lockStabilizedPackage = stabilizeForegroundSignalForActiveLock(
            signaledPackage = signaledPackage,
            activeLock = activeLockSnapshot,
            now = now,
            source = source,
        )
        val stabilizedPackage = stabilizeForegroundSignalForUsageLimit(
            signaledPackage = lockStabilizedPackage,
            now = now,
            source = source,
        )

        val resolution = ForegroundSignalState.resolve(
            previousForegroundPackage = lastKnownForeground,
            signaledPackage = stabilizedPackage,
            ownPackage = packageName,
            isEssentialPackage = { pkg -> shouldClearForegroundForPackage(pkg) },
            shouldPreservePreviousPackage = { pkg -> shouldPreserveForegroundForPackage(pkg) },
        )

        resolution.exitedPackage?.let { escalationEvaluator.onAppExit(it) }
        resolution.enteredPackage?.let { escalationEvaluator.onAppReentry(it) }

        val currentApp = resolution.effectiveForegroundPackage
        if (currentApp == null) {
            // ── If we have an overlay actively attached, DON'T hide it ──
            // This prevents flickering when Android briefly reports our own
            // overlay or SystemUI as the foreground package.
            if (activeLockAttachmentPackage != null) {
                // Keep the overlay visible — the locked app is still underneath
                val attachedPkg = activeLockAttachmentPackage!!
                lastTickTime = now
                // Don't clear lastKnownForeground — preserve it for next tick
                val preservedLockState = if (activeLockSnapshot != null) {
                    LockStatePayload(
                        blockedAppPackage = activeLockSnapshot.packageName,
                        remainingLockSeconds = activeLockSnapshot.remainingSeconds,
                    )
                } else {
                    LockStatePayload(
                        blockedAppPackage = attachedPkg,
                    )
                }
                broadcastState(
                    stage = if (activeLockSnapshot != null) InterventionStage.fromCode(activeLockSnapshot.stage)
                            else currentNativeState.stage,
                    currentApp = attachedPkg,
                    overlayVisible = true,
                    riskScore = currentNativeState.riskScore,
                    lockState = preservedLockState,
                )
                return
            }

            clearPendingActiveLockDetach()
            clearPendingUsageLimitDetach()
            lastKnownForeground = null
            lastTickTime = now
            if (hasOverlayPermission) {
                mainHandler.post { overlayManager.hideOverlay() }
            }
            isUsageLimitOverlayShowing = false
            activeUsageLimitAttachmentPackage = null

            activeLockAttachmentPackage = null
            val preservedLockState = if (activeLockSnapshot != null) {
                LockStatePayload(
                    blockedAppPackage = activeLockSnapshot.packageName,
                    remainingLockSeconds = activeLockSnapshot.remainingSeconds,
                )
            } else {
                LockStatePayload()
            }
            val preservedStage = if (activeLockSnapshot != null) {
                InterventionStage.fromCode(activeLockSnapshot.stage)
            } else {
                InterventionStage.MONITORING
            }
            val preservedRiskScore = if (activeLockSnapshot != null) {
                currentNativeState.riskScore
            } else {
                0.0
            }
            broadcastState(
                stage = preservedStage,
                currentApp = null,
                overlayVisible = false,
                riskScore = preservedRiskScore,
                lockState = preservedLockState,
            )
            return
        }

        if (currentApp == lastKnownForeground && lastTickTime > 0L) {
            val diffSec = (now - lastTickTime) / 1000L
            if (diffSec in 1..5) {
                val prev = localAccSeconds[currentApp] ?: (usageSecondsMap[currentApp] ?: 0L)
                localAccSeconds[currentApp] = prev + diffSec
            }
        }

        lastKnownForeground = currentApp
        lastTickTime = now

        val appName = appNameCache.getOrPut(currentApp) {
            try {
                val pm = packageManager
                pm.getApplicationLabel(pm.getApplicationInfo(currentApp, 0)).toString()
            } catch (_: Exception) { currentApp.substringAfterLast('.') }
        }

        val currentAppLockPayload = escalationEvaluator.getActiveLockPayloadFor(
            packageName = currentApp,
            appName = appName,
            now = now,
            isFocusMode = isFocusModeActive,
        )
        if (currentAppLockPayload != null) {
            clearPendingActiveLockDetach()
            clearPendingUsageLimitDetach()
            activeLockAttachmentPackage = currentApp
            activeUsageLimitAttachmentPackage = null
            isUsageLimitOverlayShowing = false
            deliverPayload(currentAppLockPayload, currentApp, hasOverlayPermission)
            return
        }

        val activeLockDecision = ActiveBlockAttachmentPolicy.decide(
            blockedPackageName = activeLockSnapshot?.packageName,
            blockExpiresAtMs = activeLockSnapshot?.expiresAtMs ?: 0L,
            foregroundPackageName = currentApp,
            now = now,
        )

        if (activeLockDecision.shouldClearExpiredBlock) {
            activeLockAttachmentPackage = null
        }

        if (activeLockDecision.shouldKeepBlockState) {
            clearPendingActiveLockDetach()
            activeLockAttachmentPackage = null
            if (hasOverlayPermission) {
                mainHandler.post { overlayManager.hideOverlay() }
            }
        }
        activeLockAttachmentPackage = null

        if (checkUsageLimits(currentApp, hasOverlayPermission)) return
        evaluateBehaviorEscalation(currentApp, hasOverlayPermission)
    }

    private fun stabilizeForegroundSignalForActiveLock(
        signaledPackage: String?,
        activeLock: EscalationEvaluator.ActiveLockSnapshot?,
        now: Long,
        source: ForegroundSource,
    ): String? {
        if (source != ForegroundSource.ACCESSIBILITY) {
            clearPendingActiveLockDetach()
            return signaledPackage
        }

        // ── FIX: Prioritize the package that ACTUALLY has the overlay attached ──
        // When multiple locks exist (e.g., Instagram S5 + TikTok S3),
        // getActiveLockSnapshot() returns the first lock found, which may NOT be
        // the one with the overlay showing. Use activeLockAttachmentPackage first.
        val blockedPackage = activeLockAttachmentPackage
            ?: activeLock?.packageName
        if (blockedPackage.isNullOrBlank()) {
            clearPendingActiveLockDetach()
            return signaledPackage
        }

        val normalizedPackage = signaledPackage
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

        val blockedPackageIsStillAuthoritative =
            lastKnownForeground == blockedPackage || activeLockAttachmentPackage == blockedPackage
        if (!blockedPackageIsStillAuthoritative) {
            clearPendingActiveLockDetach()
            return signaledPackage
        }

        if (normalizedPackage == blockedPackage) {
            clearPendingActiveLockDetach()
            return blockedPackage
        }

        val isTransientNoise = normalizedPackage == null ||
            normalizedPackage == packageName ||
            (normalizedPackage?.let(::shouldPreserveForegroundForPackage) == true)

        if (!isTransientNoise) {
            clearPendingActiveLockDetach()
            return signaledPackage
        }

        if (pendingActiveLockDetachPackage != blockedPackage) {
            pendingActiveLockDetachPackage = blockedPackage
            pendingActiveLockDetachStartedAt = now
        }

        return if (now - pendingActiveLockDetachStartedAt < ACTIVE_LOCK_TRANSIENT_EXIT_GRACE_MS) {
            blockedPackage
        } else {
            clearPendingActiveLockDetach()
            signaledPackage
        }
    }

    private fun stabilizeForegroundSignalForUsageLimit(
        signaledPackage: String?,
        now: Long,
        source: ForegroundSource,
    ): String? {
        if (source != ForegroundSource.ACCESSIBILITY) {
            clearPendingUsageLimitDetach()
            return signaledPackage
        }

        val limitedPackage = activeUsageLimitAttachmentPackage
            ?.takeIf { lockedToday.contains(it) }
            ?: lastKnownForeground?.takeIf { lockedToday.contains(it) }

        if (limitedPackage.isNullOrBlank()) {
            clearPendingUsageLimitDetach()
            return signaledPackage
        }

        val normalizedPackage = signaledPackage
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

        val limitedPackageIsStillAuthoritative =
            lastKnownForeground == limitedPackage || activeUsageLimitAttachmentPackage == limitedPackage
        if (!limitedPackageIsStillAuthoritative) {
            clearPendingUsageLimitDetach()
            return signaledPackage
        }

        if (normalizedPackage == limitedPackage) {
            clearPendingUsageLimitDetach()
            return limitedPackage
        }

        val isTransientNoise = normalizedPackage == null ||
            normalizedPackage == packageName ||
            (normalizedPackage?.let(::shouldPreserveForegroundForPackage) == true)

        if (!isTransientNoise) {
            clearPendingUsageLimitDetach()
            return signaledPackage
        }

        if (pendingUsageLimitDetachPackage != limitedPackage) {
            pendingUsageLimitDetachPackage = limitedPackage
            pendingUsageLimitDetachStartedAt = now
        }

        return if (now - pendingUsageLimitDetachStartedAt < USAGE_LIMIT_TRANSIENT_EXIT_GRACE_MS) {
            limitedPackage
        } else {
            clearPendingUsageLimitDetach()
            signaledPackage
        }
    }

    private fun clearPendingActiveLockDetach() {
        pendingActiveLockDetachPackage = null
        pendingActiveLockDetachStartedAt = 0L
    }

    private fun clearPendingUsageLimitDetach() {
        pendingUsageLimitDetachPackage = null
        pendingUsageLimitDetachStartedAt = 0L
    }

    private fun shouldClearForegroundForPackage(packageName: String): Boolean {
        return AppClassifier.isEssential(packageName)
    }

    private fun shouldPreserveForegroundForPackage(packageName: String): Boolean {
        val normalized = packageName.lowercase()
        return normalized.contains("inputmethod") ||
            normalized.contains("keyboard") ||
            normalized.contains(".ime")
    }

    // ═══════════════════════════════════════════
    // PATH 1: Usage-Limit Enforcement
    // ═══════════════════════════════════════════
    private fun checkUsageLimits(currentApp: String, hasOverlayPermission: Boolean): Boolean {
        if (cachedLimits.isEmpty()) {
            activeUsageLimitAttachmentPackage = null
            clearPendingUsageLimitDetach()
            clearUsageLimitOverlay(hasOverlayPermission)
            return false
        }

        if (lockedToday.contains(currentApp)) {
            val limit = cachedLimits.firstOrNull { it.packageName == currentApp }
            if (limit != null) {
                clearPendingUsageLimitDetach()
                activeUsageLimitAttachmentPackage = currentApp
                if (hasOverlayPermission) {
                    val payload = buildUsageLimitPayload(limit)
                    mainHandler.post { overlayManager.showWithPayload(payload) }
                    isUsageLimitOverlayShowing = true
                }
                return true
            } else {
                lockedToday.remove(currentApp)
                if (activeUsageLimitAttachmentPackage == currentApp) {
                    activeUsageLimitAttachmentPackage = null
                }
            }
        }

        val limit = cachedLimits.firstOrNull { it.packageName == currentApp }
        if (limit == null) {
            activeUsageLimitAttachmentPackage = null
            clearPendingUsageLimitDetach()
            clearUsageLimitOverlay(hasOverlayPermission)
            return false
        }
        val androidSec = usageSecondsMap[currentApp] ?: 0L
        val localSec = localAccSeconds[currentApp] ?: 0L
        val effectiveSec = maxOf(androidSec, localSec)

        if (effectiveSec >= limit.maxSeconds) {
            lockedToday.add(currentApp)
            clearPendingUsageLimitDetach()
            activeUsageLimitAttachmentPackage = currentApp
            if (hasOverlayPermission) {
                val payload = buildUsageLimitPayload(limit)
                mainHandler.post { overlayManager.showWithPayload(payload) }
                isUsageLimitOverlayShowing = true
            }
            return true
        }

        if (activeUsageLimitAttachmentPackage == currentApp) {
            activeUsageLimitAttachmentPackage = null
        }
        clearPendingUsageLimitDetach()
        clearUsageLimitOverlay(hasOverlayPermission)
        return false
    }

    private fun buildUsageLimitPayload(limit: AppLimit): InterventionPayload {
        val limitMinutes = (limit.maxSeconds / 60L).coerceAtLeast(1L)
        val message = if (resources.configuration.layoutDirection == android.view.View.LAYOUT_DIRECTION_RTL) {
            "${limit.name}\nتم بلوغ حد الاستخدام اليومي (${limitMinutes} د)."
        } else {
            "${limit.name}\nDaily limit reached (${limitMinutes} min)."
        }
        return InterventionPayload(
            stage = 0,
            mode = OverlayMode.USAGE_LIMIT,
            title = getString(R.string.usage_limit_title),
            message = message,
            appName = limit.name,
            packageName = limit.packageName,
            reason = getString(R.string.usage_limit_reason),
            resetText = getString(R.string.usage_limit_reset),
            showExitAppAction = true,
        )
    }

    private fun clearUsageLimitOverlay(hasOverlayPermission: Boolean) {
        if (isUsageLimitOverlayShowing && hasOverlayPermission) {
            mainHandler.post { overlayManager.hideOverlay() }
        }
        isUsageLimitOverlayShowing = false
    }

    // ═══════════════════════════════════════════
    // PATH 2: Behavior-Based Escalation
    // ═══════════════════════════════════════════
    private fun evaluateBehaviorEscalation(currentApp: String, hasOverlayPermission: Boolean) {
        // Use the higher of local accumulator vs UsageStats API for accuracy.
        // Local accumulator can miss ticks during Doze/Battery Saver,
        // while UsageStats is the ground truth from Android.
        val localSec = localAccSeconds[currentApp] ?: 0L
        val usageSec = usageSecondsMap[currentApp] ?: 0L
        val cumulativeFgSeconds = maxOf(localSec, usageSec)

        // Also sync local accumulator to prevent drift
        if (usageSec > localSec) {
            localAccSeconds[currentApp] = usageSec
        }

        val dailyDistractingSec = localAccSeconds
            .filter { (pkg, _) -> AppClassifier.classify(pkg, emptyMap()) == AppClassifier.DISTRACTING }
            .values.sum()
        val dailyProductiveSec = localAccSeconds
            .filter { (pkg, _) -> AppClassifier.classify(pkg, emptyMap()) == AppClassifier.PRODUCTIVE }
            .values.sum()

        val appName = appNameCache.getOrPut(currentApp) {
            try {
                val pm = packageManager
                pm.getApplicationLabel(pm.getApplicationInfo(currentApp, 0)).toString()
            } catch (_: Exception) { currentApp.substringAfterLast('.') }
        }

        val payload = escalationEvaluator.evaluate(
            currentApp = currentApp,
            appName = appName,
            cumulativeFgSeconds = cumulativeFgSeconds,
            dailyDistractingSec = dailyDistractingSec,
            dailyProductiveSec = dailyProductiveSec,
            db = dbHandle,
            isFocusMode = isFocusModeActive,
        )

        if (payload == null) {
            // No intervention → hide overlay, dismiss S4 notifications
            if (hasOverlayPermission) {
                mainHandler.post { overlayManager.hideOverlay() }
            }
            activeLockAttachmentPackage = null
            // Check if we just left S4 — dismiss S4 notifications
            interventionNotifier.dismissS4()
            activeInterventionId = null
            broadcastState(
                stage = InterventionStage.MONITORING,
                currentApp = currentApp,
            )
            
            // Clear signature so next escalation triggers a new fetch
            lastPayloadSignature = ""
            lastRichPayload = null
            return
        }

        val signature = "${payload.stage}_${currentApp}_${payload.s4WarningNeeded}_${payload.s4FinalWarningNeeded}"

        if (signature != lastPayloadSignature) {
            lastPayloadSignature = signature
            
            MessagingBridge.requestGeneratedMessage(
                basePayload = payload,
                contextIgnoredCount = payload.contextIgnoredCount,
                distractionScore = payload.distractionScore
            ) { richPayload ->
                lastRichPayload = richPayload
                deliverPayload(richPayload, currentApp, hasOverlayPermission)
            }
        } else {
            val updatedPayload = lastRichPayload?.copy(
                durationSeconds = payload.durationSeconds,
                limitedAccessRemainingSec = payload.limitedAccessRemainingSec,
                distractionScore = payload.distractionScore
            ) ?: payload
            deliverPayload(updatedPayload, currentApp, hasOverlayPermission)
        }
    }

    private fun deliverPayload(payload: InterventionPayload, currentApp: String, hasOverlayPermission: Boolean) {
        activeInterventionId = buildActiveInterventionId(payload, currentApp)
        when {
            // ── S1/S2: notification only, no overlay ──
            payload.stage in 1..2 -> {
                if (hasOverlayPermission) {
                    mainHandler.post { overlayManager.hideOverlay() }
                }
                activeLockAttachmentPackage = null
                if (hasNotificationPermission()) {
                    interventionNotifier.showIntervention(payload)
                } else {
                    Log.w(TAG, "S${payload.stage} skipped: no POST_NOTIFICATIONS")
                }
                broadcastState(
                    stage = InterventionStage.fromCode(payload.stage),
                    currentApp = currentApp,
                    overlayVisible = false,
                    riskScore = payload.distractionScore,
                    lockState = LockStatePayload(),
                )
            }

            // ── S3/S5: overlay lock ──
            payload.stage in intArrayOf(3, 5) -> {
                activeLockAttachmentPackage = payload.packageName
                if (hasOverlayPermission) {
                    mainHandler.post { overlayManager.showWithPayload(payload) }
                } else {
                    Log.w(TAG, "S${payload.stage} overlay skipped: no SYSTEM_ALERT_WINDOW")
                }
                broadcastState(
                    stage = InterventionStage.fromCode(payload.stage),
                    currentApp = currentApp,
                    overlayVisible = hasOverlayPermission,
                    riskScore = payload.distractionScore,
                    lockState = LockStatePayload(
                        blockedAppPackage = payload.packageName,
                        remainingLockSeconds = payload.durationSeconds,
                        reentryCount = payload.reentryCount,
                    ),
                )
            }

            // ── S4: limited access (notification only, NO overlay) ──
            payload.stage == 4 -> {
                // HIDE overlay — S4 is overlay-free
                if (hasOverlayPermission) {
                    mainHandler.post { overlayManager.hideOverlay() }
                }
                activeLockAttachmentPackage = null

                // Show/update persistent notification
                if (hasNotificationPermission()) {
                    interventionNotifier.showIntervention(payload)
                }

                // Mark S4 warnings as shown to prevent re-delivery
                val s4State = escalationEvaluator.getS4State(currentApp)
                if (s4State != null) {
                    if (payload.s4WarningNeeded) s4State.s4WarningShown = true
                    if (payload.s4FinalWarningNeeded) s4State.s4FinalWarningShown = true
                }

                broadcastState(
                    stage = InterventionStage.LIMITED_REENTRY,
                    currentApp = currentApp,
                    overlayVisible = false,
                    riskScore = payload.distractionScore,
                    lockState = LockStatePayload(
                        reentryCount = payload.reentryCount,
                        isLimitedAccess = true,
                        limitedAccessRemainingSeconds = payload.limitedAccessRemainingSec,
                        limitedAccessAppPackage = payload.packageName,
                    ),
                )
            }
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_GRANTED
        } else true
    }

    // ═══════════════════════════════════════════
    // Limits Change Handling
    // ═══════════════════════════════════════════
    private fun forceRefreshLimits() {
        if (dbHandle == null) openDb()
        refreshLimitsFromDb()
        lastLimitsRefresh = System.currentTimeMillis()
        val current = lastKnownForeground
        if (current != null && isUsageLimitOverlayShowing && !lockedToday.contains(current)) {
            mainHandler.post { overlayManager.hideOverlay() }
            isUsageLimitOverlayShowing = false
            activeUsageLimitAttachmentPackage = null
            Log.i(TAG, "Cleared stale overlay for $current")
        }
    }

    // ═══════════════════════════════════════════
    // DB Helpers
    // ═══════════════════════════════════════════
    private fun openDb() {
        closeDb()
        dbHandle = NativeDatabaseAccess.openReadable(this)
        if (dbHandle != null) {
            lastDbOpen = System.currentTimeMillis()
        }
    }

    private fun closeDb() {
        try { dbHandle?.close() } catch (_: Exception) {}
        dbHandle = null
    }

    private fun refreshLimitsFromDb() {
        val db = dbHandle ?: return
        try {
            val cursor = db.rawQuery(
                "SELECT package_name, daily_limit_minutes, name FROM app_list WHERE daily_limit_minutes > 0 AND is_enabled = 1",
                null
            )
            val result = mutableListOf<AppLimit>()
            val newLimitMap = mutableMapOf<String, Long>()
            while (cursor.moveToNext()) {
                val pkg = cursor.getString(0) ?: continue
                val mins = cursor.getInt(1)
                val name = cursor.getString(2) ?: pkg
                val maxSec = mins.toLong() * 60L
                result.add(AppLimit(pkg, name, maxSec))
                newLimitMap[pkg] = maxSec
            }
            cursor.close()
            cachedLimits = result

            val toUnlock = mutableSetOf<String>()
            for (pkg in lockedToday) {
                val newMaxSec = newLimitMap[pkg]
                if (newMaxSec == null) {
                    toUnlock.add(pkg)
                } else {
                    val effectiveSec = maxOf(usageSecondsMap[pkg] ?: 0L, localAccSeconds[pkg] ?: 0L)
                    if (effectiveSec < newMaxSec) toUnlock.add(pkg)
                }
            }
            lockedToday.removeAll(toUnlock)
            if (activeUsageLimitAttachmentPackage != null &&
                activeUsageLimitAttachmentPackage !in lockedToday) {
                activeUsageLimitAttachmentPackage = null
            }
            prevLimitMap = newLimitMap
        } catch (e: Exception) { Log.w(TAG, "DB read error", e) }
    }

    private fun refreshUsageTotals(now: Long) {
        usageSnapshotStore.refreshRecentDays(days = 1, endTime = now)

        val cal = java.util.Calendar.getInstance()
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        val todayStart = cal.timeInMillis
        val trackedPackages = cachedLimits.map { it.packageName }.toSet()
        if (trackedPackages.isEmpty()) return
        val stats = usageStatsHelper.getUsageStats(todayStart, now)
        for (record in stats) {
            val pkg = record["packageName"] as? String ?: continue
            if (pkg in trackedPackages) {
                val durationMs = record["durationMs"] as? Number ?: continue
                val sec = durationMs.toLong() / 1000L
                usageSecondsMap[pkg] = sec
                val localSec = localAccSeconds[pkg] ?: 0L
                if (sec > localSec) localAccSeconds[pkg] = sec
            }
        }
    }

    // ═══════════════════════════════════════════
    // Notification Channel
    // ═══════════════════════════════════════════
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.tracking_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = getString(R.string.tracking_channel_desc)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    // ═══════════════════════════════════════════
    // Native State Broadcasting
    // ═══════════════════════════════════════════
    private fun broadcastState(
        stage: InterventionStage = InterventionStage.MONITORING,
        currentApp: String? = lastKnownForeground,
        overlayVisible: Boolean = false,
        riskScore: Double = 0.0,
        lockState: LockStatePayload = LockStatePayload(),
    ) {
        val snapshot = RuntimeStateSnapshot(
            trackingActive = isRunning,
            stage = stage,
            currentAppPackage = currentApp,
            overlayVisible = overlayVisible,
            riskScore = riskScore,
            focusModeActive = isFocusModeActive,
            lockState = lockState,
            lastUpdatedAt = System.currentTimeMillis(),
        )
        currentNativeState = snapshot
        persistRuntimeProjection(snapshot)
        val listener = stateListener ?: return
        mainHandler.post {
            try {
                listener.invoke(currentNativeState)
            } catch (e: Exception) {
                Log.w(TAG, "State broadcast failed; clearing detached listener", e)
                if (stateListener === listener) {
                    stateListener = null
                }
            }
        }
    }

    private fun persistRuntimeProjection(snapshot: RuntimeStateSnapshot) {
        val signature = listOf(
            snapshot.trackingActive,
            snapshot.stage.code,
            snapshot.currentAppPackage ?: "",
            snapshot.overlayVisible,
            snapshot.focusModeActive,
            snapshot.lockState.blockedAppPackage ?: "",
            snapshot.lockState.reentryCount,
            snapshot.lockState.isLimitedAccess,
            snapshot.lockState.limitedAccessAppPackage ?: "",
            activeInterventionId ?: "",
        ).joinToString("|")

        if (signature == lastPersistedRuntimeSignature) return
        lastPersistedRuntimeSignature = signature
        runtimeStore.persistRuntimeSnapshot(snapshot, activeInterventionId)
    }

    private fun buildActiveInterventionId(
        payload: InterventionPayload,
        currentApp: String,
    ): String {
        val targetPackage = payload.packageName.ifBlank { currentApp }
        return listOf(
            payload.stage,
            targetPackage,
            payload.reentryCount,
            lastPayloadSignature,
        ).joinToString(":")
    }
}
