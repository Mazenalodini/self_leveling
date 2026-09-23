package com.selfleveling.self_leveling

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.view.accessibility.AccessibilityManager
import android.provider.Settings
import android.util.Log
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Narrow foreground/window-change monitor fed only by AccessibilityService.
 *
 * It does not inspect view content or scrape text. It only keeps the latest
 * package-level foreground signal so TrackingService can react immediately.
 */
object AccessibilityForegroundMonitor {
    private const val TAG = "SL.AccessibilityFg"

    fun interface Listener {
        fun onForegroundChanged(packageName: String?, eventTime: Long)
    }

    private val listeners = CopyOnWriteArraySet<Listener>()

    @Volatile
    private var currentForegroundPackage: String? = null

    @Volatile
    private var hasForegroundSnapshot: Boolean = false

    @Volatile
    private var isServiceConnected: Boolean = false

    @Volatile
    private var lastEventTime: Long = 0L

    fun registerListener(listener: Listener) {
        listeners += listener
        if (hasForegroundSnapshot) {
            listener.onForegroundChanged(
                currentForegroundPackage,
                System.currentTimeMillis(),
            )
        }
    }

    fun unregisterListener(listener: Listener) {
        listeners -= listener
    }

    fun onServiceConnected() {
        isServiceConnected = true
        hasForegroundSnapshot = false
        currentForegroundPackage = null
        lastEventTime = 0L
        Log.i(TAG, "Accessibility foreground monitor connected")
    }

    fun onServiceDisconnected() {
        isServiceConnected = false
        hasForegroundSnapshot = false
        currentForegroundPackage = null
        lastEventTime = 0L
        Log.i(TAG, "Accessibility foreground monitor disconnected")
        notifyListeners(null, System.currentTimeMillis())
    }

    fun publish(packageName: String?, eventTime: Long) {
        val normalized = packageName?.trim()?.takeIf { it.isNotEmpty() }
        val safeEventTime = eventTime.takeIf { it > 0L } ?: System.currentTimeMillis()
        if (hasForegroundSnapshot && currentForegroundPackage == normalized) {
            lastEventTime = safeEventTime
            return
        }
        currentForegroundPackage = normalized
        hasForegroundSnapshot = true
        lastEventTime = safeEventTime
        notifyListeners(normalized, safeEventTime)
    }

    fun isConnected(): Boolean = isServiceConnected

    fun hasSnapshot(): Boolean = hasForegroundSnapshot

    fun currentPackage(): String? = currentForegroundPackage

    fun snapshotAgeMs(now: Long): Long {
        val snapshotTime = lastEventTime
        if (snapshotTime <= 0L) return Long.MAX_VALUE
        return (now - snapshotTime).coerceAtLeast(0L)
    }

    fun isServiceEnabled(
        context: Context,
        serviceClass: Class<out AccessibilityService>,
    ): Boolean {
        val component = ComponentName(context, serviceClass)
        val expectedIds = setOf(
            component.flattenToString(),
            component.flattenToShortString(),
            component.className,
            ".${component.className.substringAfterLast('.')}",
        )
        val accessibilityManager =
            context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        val managerReportsEnabled = accessibilityManager
            ?.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            ?.any { serviceInfo ->
                val service = serviceInfo.resolveInfo?.serviceInfo
                val managerIds = listOfNotNull(
                    serviceInfo.id,
                    service?.let { "${it.packageName}/${it.name}" },
                    service?.let { "${it.packageName}/.${it.name.substringAfterLast('.')}" },
                    service?.name,
                    service?.let { ".${it.name.substringAfterLast('.')}" },
                )
                managerIds.any { it in expectedIds }
            } == true
        if (managerReportsEnabled) return true

        val enabled = Settings.Secure.getInt(
            context.contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        ) == 1
        if (!enabled) return false

        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        return enabledServices.split(':').any {
            expectedIds.any { expected -> it.equals(expected, ignoreCase = true) }
        }
    }

    private fun notifyListeners(packageName: String?, eventTime: Long) {
        listeners.forEach { listener ->
            try {
                listener.onForegroundChanged(packageName, eventTime)
            } catch (e: Exception) {
                Log.w(TAG, "Foreground listener failed", e)
            }
        }
    }
}
