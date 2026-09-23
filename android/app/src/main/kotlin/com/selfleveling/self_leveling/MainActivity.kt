package com.selfleveling.self_leveling

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — the bridge between Flutter and Kotlin native layer.
 *
 * Provides:
 *   - MethodChannel ("com.selfleveling/system") for request/response calls
 *   - EventChannel ("com.selfleveling/state_stream") for real-time native → Flutter state push
 *
 * Architecture principle:
 *   - Android Native owns runtime enforcement and live state.
 *   - Flutter consumes runtime snapshots and sends user-driven commands.
 */
class MainActivity : FlutterActivity() {
    private lateinit var usageStatsHelper: UsageStatsHelper
    private lateinit var usageSnapshotStore: NativeUsageSnapshotStore
    private lateinit var overlayManager: OverlayManager
    private lateinit var runtimeStore: NativeRuntimeStore

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 1001
        
        @Volatile
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usageStatsHelper = UsageStatsHelper(this)
        usageSnapshotStore = NativeUsageSnapshotStore(this, usageStatsHelper)
        overlayManager = OverlayManager(this)
        runtimeStore = NativeRuntimeStore(this)

        // ═══════════════════════════════════════════
        // EventChannel — real-time native → Flutter state stream
        // ═══════════════════════════════════════════
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RuntimeChannels.STATE_STREAM)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return
                    // EventChannel emits RuntimeStateSnapshot payloads only.
                    try {
                        events.success(TrackingService.currentNativeState.toMap())
                    } catch (_: Exception) {
                        TrackingService.clearStateListener()
                        return
                    }
                    // Register listener for future updates
                    TrackingService.setStateListener { state ->
                        events.success(state.toMap())
                    }
                }

                override fun onCancel(arguments: Any?) {
                    TrackingService.setStateListener(null)
                }
            })

        // ═══════════════════════════════════════════
        // MethodChannel — request/response calls
        // ═══════════════════════════════════════════
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RuntimeChannels.METHOD)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Usage Stats ──
                RuntimeMethods.HAS_USAGE_STATS_PERMISSION -> {
                    result.success(usageStatsHelper.hasPermission())
                }
                RuntimeMethods.REQUEST_USAGE_STATS_PERMISSION -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                RuntimeMethods.GET_USAGE_STATS -> {
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    val stats = usageStatsHelper.getUsageStats(startTime, endTime)
                    result.success(stats)
                }
                RuntimeMethods.REFRESH_USAGE_SNAPSHOT -> {
                    val days = call.argument<Int>("days") ?: 1
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    Thread {
                        val refreshResult = usageSnapshotStore.refreshRecentDays(days, endTime)
                        runOnUiThread {
                            result.success(refreshResult.toMap())
                        }
                    }.start()
                }
                RuntimeMethods.GET_CURRENT_APP -> {
                    result.success(usageStatsHelper.getCurrentForegroundApp())
                }

                // ── Foreground Service ──
                RuntimeMethods.START_ENGINE -> {
                    if (TrackingService.isRunning) {
                        runtimeStore.setEngineActivationRequested(true)
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    try {
                        runtimeStore.setEngineActivationRequested(true)
                        val serviceIntent = Intent(this, TrackingService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        runtimeStore.setEngineActivationRequested(false)
                        result.success(false)
                    }
                }
                RuntimeMethods.STOP_ENGINE -> {
                    runtimeStore.setEngineActivationRequested(false)
                    runtimeStore.clearRuntimeSnapshot()
                    result.success(stopService(Intent(this, TrackingService::class.java)))
                }
                RuntimeMethods.IS_ENGINE_RUNNING -> {
                    result.success(TrackingService.isRunning)
                }

                // ── Overlay Permission ──
                RuntimeMethods.HAS_OVERLAY_PERMISSION -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                RuntimeMethods.REQUEST_OVERLAY_PERMISSION -> {
                    if (!Settings.canDrawOverlays(this)) {
                        startActivity(Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ))
                    }
                    result.success(null)
                }
                RuntimeMethods.HAS_ACCESSIBILITY_PERMISSION -> {
                    result.success(
                        AccessibilityForegroundMonitor.isServiceEnabled(
                            this,
                            ForegroundAccessibilityService::class.java,
                        )
                    )
                }
                RuntimeMethods.REQUEST_ACCESSIBILITY_PERMISSION -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                RuntimeMethods.SHOW_OVERLAY -> {
                    overlayManager.showOverlay(call.argument<String>("message"))
                    result.success(null)
                }
                RuntimeMethods.HIDE_OVERLAY -> {
                    overlayManager.hideOverlay()
                    result.success(null)
                }

                // ── Notification Permission (Android 13+) ──
                RuntimeMethods.HAS_NOTIFICATION_PERMISSION -> {
                    result.success(hasNotificationPermission())
                }
                RuntimeMethods.REQUEST_NOTIFICATION_PERMISSION -> {
                    requestNotificationPermission()
                    result.success(null)
                }

                // ── Policy refresh signal ──
                RuntimeMethods.REFRESH_POLICIES -> {
                    TrackingService.currentInstance?.requestLimitsRefresh()
                    result.success(TrackingService.isRunning)
                }

                // ── Typed runtime-readiness snapshot ──
                RuntimeMethods.GET_RUNTIME_READINESS -> {
                    result.success(
                        RuntimeReadinessSnapshot(
                            usageStatsGranted = usageStatsHelper.hasPermission(),
                            overlayGranted = Settings.canDrawOverlays(this),
                            accessibilityGranted = AccessibilityForegroundMonitor.isServiceEnabled(
                                this,
                                ForegroundAccessibilityService::class.java,
                            ),
                            notificationGranted = hasNotificationPermission(),
                            activationRequested = runtimeStore.isEngineActivationRequested(),
                            engineRunning = TrackingService.isRunning,
                        ).toMap()
                    )
                }

                // ── App Classification (canonical AppCategory contract) ──
                RuntimeMethods.CLASSIFY_APP -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val category = AppClassifier.classify(packageName, emptyMap())
                    result.success(category)
                }

                // ── Get current native system state (one-shot) ──
                RuntimeMethods.GET_RUNTIME_SNAPSHOT -> {
                    val snapshot = if (TrackingService.isRunning) {
                        TrackingService.currentNativeState
                    } else {
                        runtimeStore.restoreRuntimeSnapshot()
                    }
                    result.success(snapshot.toMap())
                }

                // ── Focus Mode — stricter native policy, not pause ──
                RuntimeMethods.SET_FOCUS_MODE -> {
                    val active = call.argument<Boolean>("active") ?: false
                    runtimeStore.setFocusModePersisted(active)
                    // Find the running TrackingService instance and set the flag
                    TrackingService.currentInstance?.isFocusModeActive = active
                    result.success(active)
                }

                // ── Keep Screen On (for focus sessions) ──
                "setKeepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!hasNotificationPermission()) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        TrackingService.clearStateListener()
        methodChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        TrackingService.clearStateListener()
        methodChannel = null
        super.onDestroy()
    }
}
