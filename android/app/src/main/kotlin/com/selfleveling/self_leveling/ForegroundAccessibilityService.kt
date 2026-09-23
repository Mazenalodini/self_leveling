package com.selfleveling.self_leveling

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * Narrow AccessibilityService for package-level foreground/window detection.
 *
 * It intentionally does NOT inspect view trees or scrape text. It only emits
 * package changes for immediate native overlay show/hide decisions.
 */
class ForegroundAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        AccessibilityForegroundMonitor.onServiceConnected()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val safeEvent = event ?: return
        if (
            safeEvent.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            safeEvent.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val packageName = safeEvent.packageName?.toString()
        if (packageName.isNullOrBlank()) {
            if (
                safeEvent.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                safeEvent.windowChanges != 0
            ) {
                AccessibilityForegroundMonitor.publish(
                    packageName = null,
                    eventTime = System.currentTimeMillis(),
                )
            }
            return
        }

        AccessibilityForegroundMonitor.publish(
            packageName = packageName,
            eventTime = System.currentTimeMillis(),
        )
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        AccessibilityForegroundMonitor.onServiceDisconnected()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        AccessibilityForegroundMonitor.onServiceDisconnected()
        super.onDestroy()
    }
}
