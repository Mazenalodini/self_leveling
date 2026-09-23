package com.selfleveling.self_leveling

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restarts the TrackingService after device reboot.
 * Requires RECEIVE_BOOT_COMPLETED permission in the manifest.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i("SL.BootReceiver", "Device booted — restarting TrackingService")

            // Only restart if native runtime activation was explicitly requested.
            val runtimeStore = NativeRuntimeStore(context)
            val wasTracking = runtimeStore.isEngineActivationRequested()

            if (wasTracking) {
                val serviceIntent = Intent(context, TrackingService::class.java)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    Log.e("SL.BootReceiver", "Failed to restart service", e)
                }
            }
        }
    }
}
