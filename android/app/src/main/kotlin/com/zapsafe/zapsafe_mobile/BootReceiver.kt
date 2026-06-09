package com.zapsafe.zapsafe_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Day 22 — Restarts [ZapSafeService] after a device reboot so the safety
 * engine doesn't go silent the next time the user turns their phone on.
 *
 * Registered in `AndroidManifest.xml` against:
 *   - `android.intent.action.BOOT_COMPLETED` (cold boot)
 *   - `android.intent.action.QUICKBOOT_POWERON` (HTC / some OEMs)
 *   - `android.intent.action.MY_PACKAGE_REPLACED` (after our own APK upgrade)
 *
 * Requires the `RECEIVE_BOOT_COMPLETED` permission (already declared in
 * the manifest in Day 21).
 *
 * Today the receiver always restarts the service. Once user onboarding has
 * landed, Day 23+ will gate this on a SharedPreferences flag like
 * `zapsafe.service.user_opted_in` so we don't run the engine for a user
 * who hasn't consented yet.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "ZapSafeBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "Boot signal received: $action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> startService(context)
            else -> Log.w(TAG, "Ignoring unexpected boot action: $action")
        }
    }

    private fun startService(context: Context) {
        val serviceIntent = Intent(context, ZapSafeService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "ZapSafeService start requested post-boot")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart ZapSafeService: ${e.message}")
        }
    }
}
