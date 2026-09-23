package com.selfleveling.self_leveling

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class UsageSnapshotRefreshResult(
    val changed: Boolean = false,
    val refreshedDays: Int = 0,
    val appCount: Int = 0,
    val totalDurationSeconds: Int = 0,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "changed" to changed,
        "refreshedDays" to refreshedDays,
        "appCount" to appCount,
        "totalDurationSeconds" to totalDurationSeconds,
    )
}

/**
 * Canonical native writer for usage-history projections.
 *
 * Native owns collection of usage snapshots because it is the process that
 * continues running while the Flutter UI is absent. Flutter can trigger a
 * refresh, but it no longer owns persistence of `app_usage` / `behavior_records`.
 */
class NativeUsageSnapshotStore(
    private val context: Context,
    private val usageStatsHelper: UsageStatsHelper,
) {
    companion object {
        private const val TAG = "SL.UsageSnapshot"
        private const val MAX_BACKFILL_DAYS = 31
        private const val DAY_MS = 24L * 60L * 60L * 1000L
        private val refreshLock = Any()
    }

    private val dateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    @Synchronized
    fun refreshRecentDays(
        days: Int,
        endTime: Long = System.currentTimeMillis(),
    ): UsageSnapshotRefreshResult {
        synchronized(refreshLock) {
            if (!usageStatsHelper.hasPermission()) {
                return UsageSnapshotRefreshResult()
            }

            val boundedDays = days.coerceIn(1, MAX_BACKFILL_DAYS)
            val db = NativeDatabaseAccess.openWritable(context) ?: return UsageSnapshotRefreshResult()

            return try {
                val userOverrides = AppClassifier.loadUserOverrides(db)
                var changedAny = false
                var totalDurationSeconds = 0
                var appCount = 0

                for (offset in 0 until boundedDays) {
                    val dayStart = startOfDay(endTime, offset)
                    val dayEnd = minOf(dayStart + DAY_MS, endTime)
                    val records = normalizeDayRecords(
                        dayStart = dayStart,
                        dayEnd = dayEnd,
                        records = usageStatsHelper.collectUsageStats(
                            startTime = dayStart,
                            endTime = dayEnd,
                            userOverrides = userOverrides,
                        ),
                    )
                    val changed = persistDaySnapshot(db, dayStart, dayEnd, records)
                    if (changed) {
                        changedAny = true
                    }
                    if (offset == 0) {
                        totalDurationSeconds =
                            records.sumOf { (it.durationMs / 1000L).toInt() }
                        appCount = records.size
                    }
                }

                UsageSnapshotRefreshResult(
                    changed = changedAny,
                    refreshedDays = boundedDays,
                    appCount = appCount,
                    totalDurationSeconds = totalDurationSeconds,
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to refresh usage snapshot", e)
                UsageSnapshotRefreshResult()
            } finally {
                db.close()
            }
        }
    }

    private fun persistDaySnapshot(
        db: SQLiteDatabase,
        dayStart: Long,
        dayEnd: Long,
        records: List<UsageStatsHelper.UsageStatRecord>,
    ): Boolean {
        val dateKey = dateFormatter.format(Date(dayStart))
        val nextTimestamp = maxOf(dayStart, dayEnd - 1)
        val nextSignature = buildDaySignature(records)
        val previousSignature = readExistingDaySignature(db, dateKey)
        if (previousSignature == nextSignature) {
            return false
        }

        db.beginTransaction()
        try {
            db.delete("app_usage", "date_key = ?", arrayOf(dateKey))
            db.delete("behavior_records", "date_key = ?", arrayOf(dateKey))

            if (records.isNotEmpty()) {
                val behaviorSummary = buildBehaviorSummary(records)

                for (record in records) {
                    val values = ContentValues().apply {
                        put("package_name", record.packageName)
                        put("app_name", record.appName)
                        put("category", record.category)
                        put("start_time", dayStart)
                        put("duration_seconds", (record.durationMs / 1000L).toInt())
                        put("launch_count", record.launchCount)
                        put("last_time_used", record.lastTimeUsed)
                        put("date_key", dateKey)
                    }
                    db.insertWithOnConflict(
                        "app_usage",
                        null,
                        values,
                        SQLiteDatabase.CONFLICT_REPLACE,
                    )
                }

                val summaryValues = ContentValues().apply {
                    put("timestamp", nextTimestamp)
                    put("productive_seconds", behaviorSummary.productiveSeconds)
                    put("neutral_seconds", behaviorSummary.neutralSeconds)
                    put("distracting_seconds", behaviorSummary.distractingSeconds)
                    put("session_count", behaviorSummary.sessionCount)
                    put("top_distracting_app", behaviorSummary.topDistractingApp)
                    put("date_key", dateKey)
                }
                db.insertWithOnConflict(
                    "behavior_records",
                    null,
                    summaryValues,
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }

            db.setTransactionSuccessful()
            return true
        } finally {
            db.endTransaction()
        }
    }

    private fun buildDaySignature(records: List<UsageStatsHelper.UsageStatRecord>): String {
        return records
            .sortedBy { it.packageName }
            .joinToString("|") { record ->
                listOf(
                    record.packageName,
                    record.durationMs / 1000L,
                    record.launchCount,
                    record.lastTimeUsed,
                    record.category,
                ).joinToString(":")
            }
    }

    private fun normalizeDayRecords(
        dayStart: Long,
        dayEnd: Long,
        records: List<UsageStatsHelper.UsageStatRecord>,
    ): List<UsageStatsHelper.UsageStatRecord> {
        if (records.isEmpty()) return emptyList()

        val dayWindowMs = (dayEnd - dayStart).coerceAtLeast(0L)
        if (dayWindowMs <= 0L) return emptyList()

        val merged = linkedMapOf<String, UsageStatsHelper.UsageStatRecord>()
        for (record in records) {
            val clampedDuration = record.durationMs.coerceIn(0L, dayWindowMs)
            val clampedLastTimeUsed = record.lastTimeUsed.coerceIn(dayStart, dayEnd)
            val normalized = record.copy(
                durationMs = clampedDuration,
                lastTimeUsed = clampedLastTimeUsed,
            )
            val previous = merged[record.packageName]
            merged[record.packageName] = if (previous == null) {
                normalized
            } else {
                previous.copy(
                    appName = if (previous.appName.isNotBlank()) previous.appName else normalized.appName,
                    durationMs = maxOf(previous.durationMs, normalized.durationMs),
                    launchCount = maxOf(previous.launchCount, normalized.launchCount),
                    lastTimeUsed = maxOf(previous.lastTimeUsed, normalized.lastTimeUsed),
                    category = normalized.category,
                    usedStatsFallback = previous.usedStatsFallback || normalized.usedStatsFallback,
                )
            }
        }

        val normalizedRecords = merged.values.toMutableList()
        var totalDurationMs = normalizedRecords.sumOf { it.durationMs }
        if (totalDurationMs <= dayWindowMs) {
            return normalizedRecords.sortedForStorage()
        }

        val fallbackIndexes = normalizedRecords
            .withIndex()
            .filter { it.value.usedStatsFallback && it.value.durationMs > 0L }
            .sortedByDescending { it.value.durationMs }

        for ((index, record) in fallbackIndexes) {
            if (totalDurationMs <= dayWindowMs) break
            val overBy = totalDurationMs - dayWindowMs
            val reducedDuration = (record.durationMs - overBy).coerceAtLeast(0L)
            totalDurationMs -= (record.durationMs - reducedDuration)
            normalizedRecords[index] = record.copy(durationMs = reducedDuration)
        }

        if (totalDurationMs > dayWindowMs && totalDurationMs > 0L) {
            val scale = dayWindowMs.toDouble() / totalDurationMs.toDouble()
            var scaledTotal = 0L
            for (i in normalizedRecords.indices) {
                val record = normalizedRecords[i]
                val scaledDuration = (record.durationMs * scale).toLong().coerceIn(0L, dayWindowMs)
                normalizedRecords[i] = record.copy(durationMs = scaledDuration)
                scaledTotal += scaledDuration
            }

            if (scaledTotal > dayWindowMs) {
                val overflow = scaledTotal - dayWindowMs
                val firstIndex = normalizedRecords.indices.firstOrNull { normalizedRecords[it].durationMs >= overflow }
                if (firstIndex != null) {
                    val record = normalizedRecords[firstIndex]
                    normalizedRecords[firstIndex] = record.copy(durationMs = record.durationMs - overflow)
                }
            }
        }

        return normalizedRecords
            .filter { it.durationMs > 0L || it.launchCount > 0 }
            .sortedForStorage()
    }

    private fun readExistingDaySignature(db: SQLiteDatabase, dateKey: String): String {
        val cursor = db.rawQuery(
            """
            SELECT package_name, duration_seconds, launch_count, last_time_used, category
            FROM app_usage
            WHERE date_key = ?
            ORDER BY package_name ASC
            """.trimIndent(),
            arrayOf(dateKey),
        )
        return cursor.use {
            val parts = mutableListOf<String>()
            while (it.moveToNext()) {
                val packageName = it.getString(0) ?: continue
                val durationSeconds = it.getLong(1)
                val launchCount = it.getInt(2)
                val lastTimeUsed = it.getLong(3)
                val category = it.getInt(4)
                parts += "$packageName:$durationSeconds:$launchCount:$lastTimeUsed:$category"
            }
            parts.joinToString("|")
        }
    }

    private fun buildBehaviorSummary(
        records: List<UsageStatsHelper.UsageStatRecord>,
    ): DayBehaviorSummary {
        var productiveSeconds = 0
        var neutralSeconds = 0
        var distractingSeconds = 0
        var sessionCount = 0
        var topDistractingApp: String? = null
        var topDistractingSeconds = 0

        for (record in records) {
            val durationSeconds = (record.durationMs / 1000L).toInt()
            when (record.category) {
                AppClassifier.PRODUCTIVE -> productiveSeconds += durationSeconds
                AppClassifier.DISTRACTING -> {
                    distractingSeconds += durationSeconds
                    sessionCount += record.launchCount
                    if (durationSeconds >= topDistractingSeconds) {
                        topDistractingSeconds = durationSeconds
                        topDistractingApp = record.appName
                    }
                }
                else -> neutralSeconds += durationSeconds
            }
        }

        return DayBehaviorSummary(
            productiveSeconds = productiveSeconds,
            neutralSeconds = neutralSeconds,
            distractingSeconds = distractingSeconds,
            sessionCount = sessionCount,
            topDistractingApp = topDistractingApp,
        )
    }

    private fun startOfDay(referenceTime: Long, daysBack: Int): Long {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = referenceTime
            add(Calendar.DAY_OF_YEAR, -daysBack)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return calendar.timeInMillis
    }

    private fun List<UsageStatsHelper.UsageStatRecord>.sortedForStorage():
        List<UsageStatsHelper.UsageStatRecord> {
        return sortedWith(
            compareByDescending<UsageStatsHelper.UsageStatRecord> { it.durationMs }
                .thenByDescending { it.launchCount }
                .thenByDescending { it.lastTimeUsed }
                .thenBy { it.packageName },
        )
    }

    private data class DayBehaviorSummary(
        val productiveSeconds: Int,
        val neutralSeconds: Int,
        val distractingSeconds: Int,
        val sessionCount: Int,
        val topDistractingApp: String?,
    )
}
