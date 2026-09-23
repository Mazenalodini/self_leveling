package com.selfleveling.self_leveling

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Delivers outside-app intervention notifications for escalation stages.
 *
 * V2 — ESCALATION ENGINE V2
 *
 * Notification types:
 *   - S1: DEFAULT priority notification (drawer)
 *   - S2: HIGH priority heads-up notification
 *   - S4: LOW priority persistent notification showing remaining allowance
 *   - S4 near-end: HIGH priority heads-up at 2 min and 30 sec remaining
 *
 * Key improvements in V2:
 *   - S4 persistent notification channel (LOW importance, ongoing)
 *   - S4 near-end warning channel (HIGH importance, heads-up)
 *   - Context-aware expanded text with habit suggestions
 *   - Throttle per notification type
 */
class InterventionNotifier(private val context: Context) {

    companion object {
        const val CHANNEL_S1 = "self_leveling_warning"
        const val CHANNEL_S2 = "self_leveling_alert"
        const val CHANNEL_S4 = "self_leveling_limited"
        const val CHANNEL_S4_WARN = "self_leveling_limited_warn"
        private const val TAG = "SL.Notifier"
        private const val NOTIFICATION_S1_ID = 2001
        private const val NOTIFICATION_S2_ID = 2002
        private const val NOTIFICATION_S4_ID = 2003
        private const val NOTIFICATION_S4_WARN_ID = 2004
        private const val MIN_INTERVAL_MS = 120_000L
    }

    private var notificationManager: NotificationManager? = null
    private var lastS1Time = 0L
    private var lastS2Time = 0L

    init {
        createChannels()
        notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager
    }

    fun showIntervention(payload: InterventionPayload) {
        if (notificationManager == null) return
        val now = System.currentTimeMillis()

        when (payload.stage) {
            1 -> {
                if (now - lastS1Time < MIN_INTERVAL_MS) return
                lastS1Time = now
                showS1(payload)
            }
            2 -> {
                if (now - lastS2Time < MIN_INTERVAL_MS) return
                lastS2Time = now
                showS2(payload)
            }
            4 -> {
                showS4Persistent(payload)
                // Check for near-end warnings
                if (payload.s4WarningNeeded) {
                    showS4Warning(payload, isFinal = false)
                }
                if (payload.s4FinalWarningNeeded) {
                    showS4Warning(payload, isFinal = true)
                }
            }
        }
    }

    // ═══════════════════════════════════════════
    // S1 — Soft warning notification
    // ═══════════════════════════════════════════

    private fun showS1(payload: InterventionPayload) {
        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = openIntent?.let {
            PendingIntent.getActivity(context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val expandedText = buildExpandedText(payload)

        val builder = NotificationCompat.Builder(context, CHANNEL_S1)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(payload.headline ?: payload.title)
            .setContentText(payload.body ?: payload.message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText(expandedText)
                .setBigContentTitle(payload.headline ?: payload.title))

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
            val actionText = payload.actionLabel ?: context.getString(R.string.action_open_app)
            builder.addAction(android.R.drawable.ic_menu_agenda, actionText, pendingIntent)
        }

        try {
            notificationManager?.notify(NOTIFICATION_S1_ID, builder.build())
            Log.d(TAG, "S1 notification: ${payload.title}")
        } catch (e: Exception) {
            Log.w(TAG, "S1 notification failed", e)
        }
    }

    // ═══════════════════════════════════════════
    // S2 — Strong warning heads-up notification
    // ═══════════════════════════════════════════

    private fun showS2(payload: InterventionPayload) {
        // Cancel S1 if present — S2 supersedes it
        notificationManager?.cancel(NOTIFICATION_S1_ID)

        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = openIntent?.let {
            PendingIntent.getActivity(context, 1, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val expandedText = buildExpandedText(payload)

        val builder = NotificationCompat.Builder(context, CHANNEL_S2)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(payload.headline ?: payload.title)
            .setContentText(payload.body ?: payload.message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVibrate(longArrayOf(0, 300, 150, 300))
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText(expandedText)
                .setBigContentTitle(payload.headline ?: payload.title))

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
            val actionText = payload.actionLabel ?: context.getString(R.string.action_open_app)
            builder.addAction(android.R.drawable.ic_menu_agenda, actionText, pendingIntent)
            builder.setFullScreenIntent(pendingIntent, true)
        }

        try {
            notificationManager?.notify(NOTIFICATION_S2_ID, builder.build())
            Log.d(TAG, "S2 heads-up notification: ${payload.title}")
        } catch (e: Exception) {
            Log.w(TAG, "S2 notification failed", e)
        }
    }

    // ═══════════════════════════════════════════
    // S4 — Persistent notification (limited access monitoring)
    // ═══════════════════════════════════════════

    private fun showS4Persistent(payload: InterventionPayload) {
        val remainMin = payload.limitedAccessRemainingSec / 60
        val remainSec = payload.limitedAccessRemainingSec % 60

        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = openIntent?.let {
            PendingIntent.getActivity(context, 2, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val contentText = context.getString(R.string.s4_notification_text,
            payload.appName, remainMin, remainSec)

        val builder = NotificationCompat.Builder(context, CHANNEL_S4)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle(context.getString(R.string.s4_notification_title))
            .setContentText(contentText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)  // Persistent — can't be swiped
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOnlyAlertOnce(true)  // Don't re-alert on updates

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        try {
            notificationManager?.notify(NOTIFICATION_S4_ID, builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "S4 persistent notification failed", e)
        }
    }

    /**
     * S4 near-end warning — heads-up at 2 min and 30 sec remaining.
     */
    private fun showS4Warning(payload: InterventionPayload, isFinal: Boolean) {
        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = openIntent?.let {
            PendingIntent.getActivity(context, 3, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        val title = if (isFinal) {
            context.getString(R.string.s4_final_warning_title)
        } else {
            context.getString(R.string.s4_warning_title)
        }

        val message = if (isFinal) {
            context.getString(R.string.s4_final_warning_message, payload.appName)
        } else {
            context.getString(R.string.s4_warning_message, payload.appName)
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_S4_WARN)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVibrate(longArrayOf(0, 200, 100, 200))

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        try {
            notificationManager?.notify(NOTIFICATION_S4_WARN_ID, builder.build())
            Log.d(TAG, "S4 ${if (isFinal) "FINAL" else ""} warning: ${payload.appName}")
        } catch (e: Exception) {
            Log.w(TAG, "S4 warning notification failed", e)
        }
    }

    // ═══════════════════════════════════════════
    // Dismiss
    // ═══════════════════════════════════════════

    fun dismissAll() {
        notificationManager?.cancel(NOTIFICATION_S1_ID)
        notificationManager?.cancel(NOTIFICATION_S2_ID)
        notificationManager?.cancel(NOTIFICATION_S4_ID)
        notificationManager?.cancel(NOTIFICATION_S4_WARN_ID)
    }

    fun dismissS4() {
        notificationManager?.cancel(NOTIFICATION_S4_ID)
        notificationManager?.cancel(NOTIFICATION_S4_WARN_ID)
    }

    // ═══════════════════════════════════════════
    // Build expanded text with context
    // ═══════════════════════════════════════════

    private fun buildExpandedText(payload: InterventionPayload): String {
        return buildString {
            append(payload.body ?: payload.message)
            
            if (!payload.recommendationText.isNullOrBlank()) {
                val recText = if (!payload.recommendationTitle.isNullOrBlank()) 
                    "${payload.recommendationTitle}: ${payload.recommendationText}" 
                else payload.recommendationText!!
                append("\n\n💡 $recText")
            } else {
                payload.reminderText?.let { append("\n\n🎯 $it") }
                payload.suggestedAction?.let { append("\n\n💡 $it") }
            }
            
            if (payload.reentryCount > 0) {
                append("\n\n⚠ ${context.getString(R.string.reentry_detected, payload.reentryCount)}")
            }
            if (payload.contextIgnoredCount > 0 && payload.stage >= 2) {
                append("\n\n⚠ ${payload.contextIgnoredCount} previous warning(s) ignored")
            }
        }
    }

    // ═══════════════════════════════════════════
    // Notification Channels
    // ═══════════════════════════════════════════

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return

            // S1 channel — DEFAULT importance
            val s1Channel = NotificationChannel(
                CHANNEL_S1,
                context.getString(R.string.channel_s1_name),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(R.string.channel_s1_desc)
                setShowBadge(true)
            }
            manager.createNotificationChannel(s1Channel)

            // S2 channel — HIGH importance (heads-up)
            val s2Channel = NotificationChannel(
                CHANNEL_S2,
                context.getString(R.string.channel_s2_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = context.getString(R.string.channel_s2_desc)
                setShowBadge(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 150, 300)
            }
            manager.createNotificationChannel(s2Channel)

            // S4 persistent channel — LOW importance (silent, ongoing)
            val s4Channel = NotificationChannel(
                CHANNEL_S4,
                context.getString(R.string.channel_s4_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.channel_s4_desc)
                setShowBadge(false)
            }
            manager.createNotificationChannel(s4Channel)

            // S4 warning channel — HIGH importance (heads-up near end)
            val s4WarnChannel = NotificationChannel(
                CHANNEL_S4_WARN,
                context.getString(R.string.channel_s4_warn_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = context.getString(R.string.channel_s4_warn_desc)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
            }
            manager.createNotificationChannel(s4WarnChannel)
        }
    }
}
