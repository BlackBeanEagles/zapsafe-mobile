package com.zapsafe.zapsafe_mobile

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        // Mirrored on the Flutter side in lib/data/services/background_service.dart.
        const val CHANNEL = "com.zapsafe/background_service"
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
        SensorChannelHandler(messenger)
        AudioChannelHandler(messenger)

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
