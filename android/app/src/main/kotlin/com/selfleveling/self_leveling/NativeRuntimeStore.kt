package com.selfleveling.self_leveling

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.util.UUID

/**
 * Native runtime persistence / projection store.
 *
 * Ownership categories:
 *   A. Live mutable runtime authority
 *      - TrackingService + EscalationEvaluator in memory
 *   B. Canonical persisted local facts
 *      - user_profile, settings, app_list, habits, escalation_events
 *   C. Approved local native read models / projections
 *      - runtime_active_state
 *      - activation / focus intent prefs below
 *   D. Flutter presentation state
 *      - never used as runtime authority
 *
 * This store deliberately persists only:
 *   - runtime activation intent
 *   - focus-mode enforcement intent
 *   - active runtime snapshot projection for recovery/UI readback
 *   - authoritative native-written intervention facts
 *   - behavior assessments / labels for future model auditing and tuning
 */
class NativeRuntimeStore(private val context: Context) {

    companion object {
        private const val TAG = "SL.RuntimeStore"
        private const val PREFS_NAME = "sl_native_runtime"
        private const val KEY_ENGINE_ACTIVATED = "engine_activation_requested"
        private const val KEY_FOCUS_MODE_ACTIVE = "focus_mode_active"
        private const val ACTIVE_STATE_ROW_ID = "singleton"
    }

    private val prefs by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun isEngineActivationRequested(): Boolean =
        prefs.getBoolean(KEY_ENGINE_ACTIVATED, false)

    fun setEngineActivationRequested(active: Boolean) {
        prefs.edit().putBoolean(KEY_ENGINE_ACTIVATED, active).apply()
    }

    fun isFocusModePersisted(): Boolean =
        prefs.getBoolean(KEY_FOCUS_MODE_ACTIVE, false)

    fun setFocusModePersisted(active: Boolean) {
        prefs.edit().putBoolean(KEY_FOCUS_MODE_ACTIVE, active).apply()
    }

    fun restoreRuntimeSnapshot(): RuntimeStateSnapshot {
        val db = openReadableDb() ?: return RuntimeStateSnapshot(
            focusModeActive = isFocusModePersisted(),
        )
        return try {
            val cursor = db.query(
                "runtime_active_state",
                null,
                "id = ?",
                arrayOf(ACTIVE_STATE_ROW_ID),
                null,
                null,
                null,
                "1",
            )
            cursor.use {
                if (!it.moveToFirst()) {
                    return RuntimeStateSnapshot(
                        focusModeActive = isFocusModePersisted(),
                    )
                }
                val now = System.currentTimeMillis()
                val lockUntilMs = it.getLongOrZero("lock_until_ms")
                val limitedUntilMs = it.getLongOrZero("limited_access_until_ms")
                RuntimeStateSnapshot(
                    contractVersion = it.getIntOr("contract_version", RuntimeContract.VERSION),
                    trackingActive = it.getIntOr("engine_running", 0) == 1,
                    stage = InterventionStage.fromCode(it.getIntOr("current_stage", 0)),
                    currentAppPackage = it.getStringOrNull("current_app_package"),
                    overlayVisible = it.getIntOr("overlay_visible", 0) == 1,
                    riskScore = it.getDoubleOr("risk_score", 0.0),
                    focusModeActive = it.getIntOr("focus_mode_active", 0) == 1,
                    lockState = LockStatePayload(
                        blockedAppPackage = it.getStringOrNull("blocked_app_package"),
                        remainingLockSeconds = remainingSeconds(lockUntilMs, now),
                        reentryCount = it.getIntOr("reentry_count", 0),
                        isLimitedAccess = it.getIntOr("is_limited_access", 0) == 1,
                        limitedAccessRemainingSeconds = remainingSeconds(limitedUntilMs, now),
                        limitedAccessAppPackage = it.getStringOrNull("limited_access_app_package"),
                    ),
                    lastUpdatedAt = it.getLongOrZero("updated_at"),
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to restore runtime snapshot", e)
            RuntimeStateSnapshot(
                focusModeActive = isFocusModePersisted(),
            )
        } finally {
            db.close()
        }
    }

    fun persistRuntimeSnapshot(
        snapshot: RuntimeStateSnapshot,
        activeInterventionId: String?,
    ) {
        val db = openWritableDb() ?: return
        try {
            val values = ContentValues().apply {
                put("id", ACTIVE_STATE_ROW_ID)
                put("contract_version", snapshot.contractVersion)
                put("engine_activation_requested", if (isEngineActivationRequested()) 1 else 0)
                put("engine_running", if (snapshot.trackingActive) 1 else 0)
                put("focus_mode_active", if (snapshot.focusModeActive) 1 else 0)
                put("current_stage", snapshot.stage.code)
                put("current_app_package", snapshot.currentAppPackage)
                put("overlay_visible", if (snapshot.overlayVisible) 1 else 0)
                put("risk_score", snapshot.riskScore)
                put("blocked_app_package", snapshot.lockState.blockedAppPackage)
                put(
                    "lock_until_ms",
                    computeExpiry(snapshot.lastUpdatedAt, snapshot.lockState.remainingLockSeconds),
                )
                put("reentry_count", snapshot.lockState.reentryCount)
                put("is_limited_access", if (snapshot.lockState.isLimitedAccess) 1 else 0)
                put(
                    "limited_access_until_ms",
                    computeExpiry(
                        snapshot.lastUpdatedAt,
                        snapshot.lockState.limitedAccessRemainingSeconds,
                    ),
                )
                put("limited_access_app_package", snapshot.lockState.limitedAccessAppPackage)
                put("active_intervention_id", activeInterventionId)
                put("updated_at", snapshot.lastUpdatedAt)
            }
            db.insertWithOnConflict(
                "runtime_active_state",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist runtime snapshot", e)
        } finally {
            db.close()
        }
    }

    fun clearRuntimeSnapshot() {
        persistRuntimeSnapshot(
            RuntimeStateSnapshot(
                trackingActive = false,
                focusModeActive = isFocusModePersisted(),
                lastUpdatedAt = System.currentTimeMillis(),
            ),
            activeInterventionId = null,
        )
    }

    fun appendInterventionEvent(
        fromLevel: Int,
        toLevel: Int,
        packageName: String,
        reason: String,
        riskScore: Double,
        reentryCount: Int,
        xpPenalty: Int = 0,
        eventType: String = "transition",
    ): String? {
        val db = openWritableDb() ?: return null
        val runtimeEventId = UUID.randomUUID().toString()
        try {
            val values = ContentValues().apply {
                put("runtime_event_id", runtimeEventId)
                put("event_type", eventType)
                put("from_level", fromLevel)
                put("to_level", toLevel)
                put("stage", toLevel)
                put("timestamp", System.currentTimeMillis())
                put("reason", reason)
                put("package_name", packageName)
                put("risk_score", riskScore)
                put("reentry_count", reentryCount)
                put("xp_penalty", xpPenalty)
                put("created_by", "native")
            }
            db.insert("escalation_events", null, values)
            return runtimeEventId
        } catch (e: Exception) {
            Log.w(TAG, "Rich intervention event insert failed; trying legacy insert", e)
            return try {
                val legacyValues = ContentValues().apply {
                    put("from_level", fromLevel)
                    put("to_level", toLevel)
                    put("timestamp", System.currentTimeMillis())
                    put("reason", reason)
                }
                db.insert("escalation_events", null, legacyValues)
                runtimeEventId
            } catch (legacyException: Exception) {
                Log.w(TAG, "Legacy intervention event insert failed", legacyException)
                null
            }
        } finally {
            db.close()
        }
    }

    fun appendBehaviorAssessment(assessment: BehaviorAssessment): String? {
        val db = openWritableDb() ?: return null
        return try {
            val values = ContentValues().apply {
                put("assessment_id", assessment.assessmentId)
                put("created_at", assessment.createdAt)
                put("source", assessment.source.storageValue)
                put("assessor_kind", assessment.assessorKind)
                put("assessor_version", assessment.assessorVersion)
                put("package_name", assessment.targetPackageName)
                put("app_name", assessment.targetAppName)
                put("app_category", assessment.facts.appCategoryCode)
                put("effective_policy", assessment.facts.effectivePolicy.storageValue)
                put("current_stage", assessment.facts.currentStage)
                put("runtime_event_id", assessment.runtimeEventId)
                put("risk_score", assessment.inference.riskScore)
                put("risk_tier", assessment.inference.riskClass.storageValue)
                put("confidence", assessment.inference.confidence)
                put("reasoning", assessment.inference.reasoning)
                put("deterministic_facts_json", assessment.facts.toStorageJson())
                put("feature_snapshot_json", assessment.features.toStorageJson())
                put("label_state", assessment.labelState.storageValue)
            }
            db.insertWithOnConflict(
                "behavior_assessments",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            assessment.assessmentId
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist behavior assessment", e)
            null
        } finally {
            db.close()
        }
    }

    fun appendBehaviorAssessmentFeedback(
        feedback: BehaviorAssessmentFeedback,
    ): Boolean {
        val db = openWritableDb() ?: return false
        return try {
            val values = ContentValues().apply {
                put("assessment_id", feedback.assessmentId)
                put("feedback_type", feedback.feedbackType.storageValue)
                put("feedback_value", feedback.feedbackValue)
                put("package_name", feedback.packageName)
                put("note", feedback.note)
                put("created_at", feedback.createdAt)
                put("created_by", feedback.createdBy)
            }
            db.insertWithOnConflict(
                "behavior_assessment_feedback",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE,
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist behavior assessment feedback", e)
            false
        } finally {
            db.close()
        }
    }

    private fun openReadableDb(): SQLiteDatabase? {
        return NativeDatabaseAccess.openReadable(context)
    }

    private fun openWritableDb(): SQLiteDatabase? {
        return NativeDatabaseAccess.openWritable(context)
    }

    private fun computeExpiry(updatedAt: Long, remainingSeconds: Int): Long {
        if (remainingSeconds <= 0) return 0L
        return updatedAt + (remainingSeconds * 1000L)
    }

    private fun remainingSeconds(untilMs: Long, now: Long): Int {
        if (untilMs <= now) return 0
        return ((untilMs - now) / 1000L).toInt()
    }

    private fun android.database.Cursor.getIntOr(column: String, fallback: Int): Int {
        val index = getColumnIndex(column)
        return if (index >= 0) getInt(index) else fallback
    }

    private fun android.database.Cursor.getLongOrZero(column: String): Long {
        val index = getColumnIndex(column)
        return if (index >= 0) getLong(index) else 0L
    }

    private fun android.database.Cursor.getDoubleOr(column: String, fallback: Double): Double {
        val index = getColumnIndex(column)
        return if (index >= 0) getDouble(index) else fallback
    }

    private fun android.database.Cursor.getStringOrNull(column: String): String? {
        val index = getColumnIndex(column)
        return if (index >= 0) getString(index) else null
    }
}
