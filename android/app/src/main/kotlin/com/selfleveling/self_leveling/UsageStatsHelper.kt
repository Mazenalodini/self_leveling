package com.selfleveling.self_leveling

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import kotlin.math.max

/**
 * Helper class for querying Android UsageStatsManager.
 * Provides app usage data for the behavioral analysis engine.
 *
 * v5 FIXES:
 *   - getCurrentForegroundApp() tracks ACTIVITY_RESUMED, ACTIVITY_PAUSED,
 *     ACTIVITY_STOPPED, and MOVE_TO_BACKGROUND events.
 *   - If the last relevant event for the detected app is a leave-foreground
 *     event, we correctly return null (nothing truly in foreground).
 *   - Result is cached for 1 second to avoid scanning events on every tick.
 *   - Fallback window is 3 minutes (covers sustained single-app usage).
 */
class UsageStatsHelper(private val context: Context) {

    data class UsageStatRecord(
        val packageName: String,
        val appName: String,
        val startTime: Long,
        val durationMs: Long,
        val launchCount: Int,
        val lastTimeUsed: Long,
        val category: Int,
        val usedStatsFallback: Boolean = false,
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "startTime" to startTime,
            "durationMs" to durationMs,
            "launchCount" to launchCount,
            "lastTimeUsed" to lastTimeUsed,
            "category" to category,
        )
    }

    companion object {
        private const val TAG = "SL.UsageStats"
        /** Cache foreground result for this long to reduce event scanning */
        private const val CACHE_VALIDITY_MS = 1000L
        /** Event type for MOVE_TO_BACKGROUND (API 29+, type=2 on some OEMs) */
        private const val EVENT_MOVE_TO_BACKGROUND = 2
    }

    private val usageStatsManager: UsageStatsManager by lazy {
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    }
    private val appNameCache = mutableMapOf<String, String>()

    // ── Foreground detection cache ──
    private var cachedForeground: String? = null
    private var cacheTimestamp: Long = 0L

    /**
     * Check if the app has PACKAGE_USAGE_STATS permission.
     */
    fun hasPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Get aggregated usage stats for the given time range.
     * Includes both duration-based usage and launch/open counts from UsageEvents.
     */
    fun getUsageStats(startTime: Long, endTime: Long): List<Map<String, Any>> {
        return collectUsageStats(startTime, endTime).map { it.toMap() }
    }

    fun collectUsageStats(
        startTime: Long,
        endTime: Long,
        userOverrides: Map<String, Int> = emptyMap(),
    ): List<UsageStatRecord> {
        if (!hasPermission()) return emptyList()

        val packages = linkedMapOf<String, MutableUsageStat>()
        val pm = context.packageManager

        val stats: List<UsageStats> = try {
            usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                startTime,
                endTime,
            ) ?: emptyList()
        } catch (e: Exception) {
            Log.w(TAG, "queryUsageStats failed", e)
            emptyList()
        }

        val statsByPackage = mutableMapOf<String, UsageStats>()
        for (stat in stats) {
            val pkg = stat.packageName ?: continue
            val previous = statsByPackage[pkg]
            if (previous == null || stat.totalTimeInForeground > previous.totalTimeInForeground) {
                statsByPackage[pkg] = stat
            }
        }

        try {
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            val activeSessions = mutableMapOf<String, Long>()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                val pkg = event.packageName ?: continue
                val usage = packages.getOrPut(pkg) {
                    MutableUsageStat(
                        packageName = pkg,
                        appName = resolveAppName(pkg, pm),
                        startTime = startTime,
                    )
                }
                when {
                    isLaunchEvent(event.eventType) -> {
                        usage.launchCount += 1
                        usage.lastTimeUsed = max(usage.lastTimeUsed, event.timeStamp)
                        activeSessions[pkg] = event.timeStamp
                    }
                    isBackgroundEvent(event.eventType) -> {
                        usage.lastTimeUsed = max(usage.lastTimeUsed, event.timeStamp)
                        val startedAt = activeSessions.remove(pkg)
                        if (startedAt != null && event.timeStamp >= startedAt) {
                            usage.durationMs += (event.timeStamp - startedAt)
                        }
                    }
                }
            }

            for ((pkg, startedAt) in activeSessions) {
                val usage = packages[pkg] ?: continue
                if (endTime >= startedAt) {
                    usage.durationMs += (endTime - startedAt)
                    usage.lastTimeUsed = max(usage.lastTimeUsed, endTime)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "queryEvents failed while collecting usage stats", e)
        }

        for ((pkg, stat) in statsByPackage) {
            val usage = packages.getOrPut(pkg) {
                MutableUsageStat(
                    packageName = pkg,
                    appName = resolveAppName(pkg, pm),
                    startTime = startTime,
                )
            }
            if (usage.durationMs <= 0L && stat.totalTimeInForeground > 0L) {
                usage.durationMs = stat.totalTimeInForeground
                usage.usedStatsFallback = true
            }
            usage.lastTimeUsed = max(usage.lastTimeUsed, stat.lastTimeUsed)
        }

        return packages.values
            .map { usage ->
                UsageStatRecord(
                    packageName = usage.packageName,
                    appName = usage.appName,
                    startTime = usage.startTime,
                    durationMs = usage.durationMs,
                    launchCount = usage.launchCount,
                    lastTimeUsed = usage.lastTimeUsed,
                    category = AppClassifier.classify(usage.packageName, userOverrides),
                    usedStatsFallback = usage.usedStatsFallback,
                )
            }
            .filter { it.durationMs > 0L || it.launchCount > 0 }
            .sortedWith(
                compareByDescending<UsageStatRecord> { it.durationMs }
                    .thenByDescending { it.launchCount }
                    .thenByDescending { it.lastTimeUsed }
                    .thenBy { it.appName.lowercase() },
            )
    }

    /**
     * Get the currently foreground app package name.
     *
     * CRITICAL: Correctly handles background/recent-apps scenarios.
     * Tracks ACTIVITY_RESUMED and all leave-foreground events.
     * If the most recent event for the detected app is a leave event,
     * nothing is truly in the foreground → returns null.
     *
     * Window strategy (progressive expansion):
     *   1. 30-second tight window (covers most transitions with ~2s polling)
     *   2. 5-minute window (covers normal sustained usage)
     *   3. 30-minute window (covers very long sustained single-app usage)
     *   4. Last-known cache (10s grace period to prevent null gaps)
     *
     * Android fires ACTIVITY_RESUMED only ONCE when an app opens. If the
     * user stays in one app for hours, only the 30-minute window will find it.
     */
    fun getCurrentForegroundApp(): String? {
        if (!hasPermission()) return null

        val now = System.currentTimeMillis()

        // Return cached result if still fresh (avoids scanning events every 2s)
        if (now - cacheTimestamp < CACHE_VALIDITY_MS && cacheTimestamp > 0L) {
            return cachedForeground
        }

        // First try: tight 30-second window (fast path — catches recent transitions)
        var result = scanTrueForeground(now - 30_000L, now)
        if (result != null) {
            cachedForeground = result
            cacheTimestamp = now
            return result
        }

        // Second try: 5-minute window (covers most sustained usage)
        result = scanTrueForeground(now - 300_000L, now)
        if (result != null) {
            cachedForeground = result
            cacheTimestamp = now
            return result
        }

        // Final fallback: 30-minute window (covers very long sustained usage)
        // Android only fires ACTIVITY_RESUMED once when the app opens.
        // If the user stays in one app for 30+ minutes without switching,
        // the RESUMED event falls outside shorter windows → we'd lose tracking.
        result = scanTrueForeground(now - 1_800_000L, now)
        if (result != null) {
            cachedForeground = result
            cacheTimestamp = now
            return result
        }

        // If no foreground app found even in 30-min window, return the
        // last known foreground if it was seen recently (within 10 seconds).
        // This prevents a brief null gap from killing the monitoring loop.
        if (cachedForeground != null && now - cacheTimestamp < 10_000L) {
            return cachedForeground
        }

        cachedForeground = null
        cacheTimestamp = now
        return null
    }

    /**
     * Scans UsageEvents in the given window and returns the package that is
     * TRULY in the foreground — i.e., the last ACTIVITY_RESUMED that has NOT
     * been followed by a leave-foreground event for the same package.
     *
     * Leave-foreground events: ACTIVITY_PAUSED, ACTIVITY_STOPPED,
     * MOVE_TO_BACKGROUND (type 2 on some OEMs/API levels).
     */
    private fun scanTrueForeground(startTime: Long, endTime: Long): String? {
        val usageEvents: UsageEvents
        try {
            usageEvents = usageStatsManager.queryEvents(startTime, endTime) ?: return null
        } catch (e: Exception) {
            Log.w(TAG, "queryEvents failed", e)
            return null
        }

        val event = UsageEvents.Event()

        // Track the chronologically last RESUMED app
        var lastResumedApp: String? = null
        var lastResumedTime = 0L

        // Track the most recent resume timestamp per package
        val resumeTimes = mutableMapOf<String, Long>()
        // Track which packages have a leave-foreground event AFTER their last resume
        val leftForeground = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val ts = event.timeStamp

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    lastResumedApp = pkg
                    lastResumedTime = ts
                    resumeTimes[pkg] = ts
                    leftForeground.remove(pkg)
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val resumeTs = resumeTimes[pkg] ?: 0L
                    if (ts >= resumeTs) {
                        leftForeground[pkg] = ts
                    }
                }
                else -> {
                    // Some OEMs emit MOVE_TO_BACKGROUND (type 2) instead of PAUSED
                    if (event.eventType == EVENT_MOVE_TO_BACKGROUND) {
                        val resumeTs = resumeTimes[pkg] ?: 0L
                        if (ts >= resumeTs) {
                            leftForeground[pkg] = ts
                        }
                    }
                }
            }
        }

        // The last RESUMED app must not have been subsequently paused/stopped
        if (lastResumedApp != null) {
            val leftTs = leftForeground[lastResumedApp]
            if (leftTs != null && leftTs >= lastResumedTime) {
                return null
            }
            return lastResumedApp
        }

        return null
    }

    private fun isLaunchEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
            eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
    }

    private fun isBackgroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.ACTIVITY_PAUSED ||
            eventType == UsageEvents.Event.ACTIVITY_STOPPED ||
            eventType == EVENT_MOVE_TO_BACKGROUND
    }

    private fun resolveAppName(packageName: String, pm: PackageManager): String {
        return appNameCache.getOrPut(packageName) {
            try {
                val appInfo = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (_: PackageManager.NameNotFoundException) {
                packageName
            }
        }
    }

    private data class MutableUsageStat(
        val packageName: String,
        val appName: String,
        val startTime: Long,
        var durationMs: Long = 0L,
        var launchCount: Int = 0,
        var lastTimeUsed: Long = 0L,
        var usedStatsFallback: Boolean = false,
    )
}
