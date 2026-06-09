package com.zapsafe.zapsafe_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ZapSafe's always-on Android foreground service.
 *
 * Day 21 = scaffold only. The DCS pipeline (audio capture, sensor read,
 * passive trigger evaluation) lands in Days 22+. Today's job is to prove
 * the service can:
 *   1. Be started from Flutter via [MainActivity.CHANNEL]
 *   2. Show a persistent foreground notification
 *   3. Survive process death via START_STICKY
 *
 * The notification IS the lifeline — Android 8+ kills any service that
 * doesn't promote itself to foreground within ~10 seconds.
 */
class ZapSafeService : Service() {
    companion object {
        const val TAG = "ZapSafeService"
        const val CHANNEL_ID = "zapsafe_foreground"
        const val CHANNEL_NAME = "ZapSafe Safety Engine"
        const val NOTIFICATION_ID = 4242

        // Heartbeat plumbing (Day 24 LP4)
        const val HEARTBEAT_INTERVAL_MS = 10_000L
        const val HEARTBEAT_PREFS = WatchdogWorker.HEARTBEAT_PREFS
        const val HEARTBEAT_KEY   = WatchdogWorker.HEARTBEAT_KEY
    }

    private val heartbeatHandler = Handler(Looper.getMainLooper())
    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            writeHeartbeat()
            heartbeatHandler.postDelayed(this, HEARTBEAT_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.i(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand startId=$startId flags=$flags")
        startForeground(NOTIFICATION_ID, buildNotification())
        startDCSPipeline()
        startHeartbeat()
        // START_STICKY: if the system kills us, restart with a null intent
        // once resources free up. This is what keeps the safety engine alive.
        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "Service destroyed")
        heartbeatHandler.removeCallbacks(heartbeatRunnable)
        super.onDestroy()
    }

    /**
     * Day 24 — start the heartbeat loop. Runs immediately, then every
     * [HEARTBEAT_INTERVAL_MS] forever. The watchdog reads this timestamp
     * to decide whether to restart us.
     */
    private fun startHeartbeat() {
        heartbeatHandler.removeCallbacks(heartbeatRunnable)
        heartbeatHandler.post(heartbeatRunnable)
    }

    private fun writeHeartbeat() {
        try {
            val prefs = getSharedPreferences(HEARTBEAT_PREFS, Context.MODE_PRIVATE)
            prefs.edit().putLong(HEARTBEAT_KEY, System.currentTimeMillis()).apply()
        } catch (e: Exception) {
            Log.w(TAG, "Heartbeat write failed: ${e.message}")
        }
    }

    /**
     * Required on Android O+ for any visible notification. Importance.LOW so
     * the persistent notification doesn't beep — the user already opted in to
     * "ZapSafe is protecting you" being visible 24/7.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Idempotent: createNotificationChannel is no-op if the channel exists.
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "ZapSafe is running in the background to keep you safe."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent()
        val contentPi = PendingIntent.getActivity(this, 0, openIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ZapSafe is protecting you")
            .setContentText("Safety engine active · tap to open")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentPi)
            .build()
    }

    /**
     * Day 21 stub. Full DCS pipeline (Defensive Continuous Streaming) is
     * built out across Days 22-30 — audio buffer, IMU read, TFLite trigger
     * inference, location ping, evidence flush.
     */
    private fun startDCSPipeline() {
        Log.i(TAG, "DCS pipeline started (stub)")
    }
}
