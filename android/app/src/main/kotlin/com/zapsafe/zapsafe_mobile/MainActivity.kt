package com.zapsafe.zapsafe_mobile

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        // Mirrored on the Flutter side in lib/data/services/background_service.dart.
        const val CHANNEL = "com.zapsafe/background_service"
    }

    // Fix for Day 336's real security finding: FLAG_SECURE was never set,
    // so the entire app (evidence vault, SOS status, emergency contacts,
    // location) was screenshot-able and recordable, and appeared in the
    // Recents thumbnail. Applied app-wide (not per-screen) since almost
    // every screen in a personal-safety app shows sensitive data — this
    // matches standard practice for banking/password-manager apps. Every
    // screen is now covered; there's no separate "sensitive screens only"
    // list to keep in sync as new screens get added.
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Day 21 — foreground service control channel.
        MethodChannel(messenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> handleStart(result)
                    "stop" -> handleStop(result)
                    "isRunning" -> result.success(isServiceRunning())
                    else -> result.notImplemented()
                }
            }

        // Day 23 — register the new platform channels. Each handler owns its
        // own MethodChannel (and EventChannel for sensors). Construction has
        // a side effect of wiring `setMethodCallHandler` / `setStreamHandler`.
        // Day 258: needs a Context to reach SensorManager — the IMU stream is
        // real hardware now, not the synthetic sine it used to emit.
        SensorChannelHandler(messenger, applicationContext)
        AudioChannelHandler(messenger)

        // Day 274 — real ambient-light sensor channel (Sensor.TYPE_LIGHT,
        // no sensors_plus dependency needed). Android-only: iOS exposes no
        // equivalent OS API, see light_sensor_channel.dart.
        LightChannelHandler(messenger, applicationContext)

        // Day 24 — LP4 watchdog control surface.
        WatchdogChannelHandler(applicationContext, messenger)
    }

    private fun handleStart(result: MethodChannel.Result) {
        val intent = Intent(this, ZapSafeService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        result.success(true)
    }

    private fun handleStop(result: MethodChannel.Result) {
        stopService(Intent(this, ZapSafeService::class.java))
        result.success(true)
    }

    /**
     * Pre-API-26, ActivityManager.getRunningServices returns running services
     * for our app. API 26+ this list is restricted to the caller's own
     * services — which is exactly what we want.
     */
    @Suppress("DEPRECATION")
    private fun isServiceRunning(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val name = ZapSafeService::class.java.name
        return am.getRunningServices(Int.MAX_VALUE)
            .any { it.service.className == name }
    }
}
