package com.zapsafe.zapsafe_mobile

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

/**
 * Day 24 — Method channel for the LP4 watchdog control surface.
 *
 * Methods:
 *   - `enqueue`              — schedule the periodic worker (15-min period,
 *                              KEEP existing if already queued).
 *   - `cancel`               — cancel the unique periodic work.
 *   - `lastHeartbeatMs`      — millis since epoch when ZapSafeService last pinged.
 *   - `secondsSinceLastPing` — convenience: (now - lastHeartbeat) / 1000.
 *                              Returns null if no heartbeat has ever been written.
 *   - `thresholdMs`          — the LP4 threshold this build is configured with.
 */
class WatchdogChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger
) {
    companion object {
        const val CHANNEL_NAME = "com.zapsafe/watchdog"
    }

    init {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "enqueue"              -> result.success(enqueue())
                "cancel"               -> result.success(cancel())
                "lastHeartbeatMs"      -> result.success(lastHeartbeatMs())
                "secondsSinceLastPing" -> result.success(secondsSinceLastPing())
                "thresholdMs"          -> result.success(WatchdogWorker.THRESHOLD_MS)
                "isEnqueued"           -> result.success(isEnqueued())
                else                   -> result.notImplemented()
            }
        }
    }

    /**
     * Schedules the periodic watchdog. Returns true on success.
     * Uses `KEEP` so calling enqueue() repeatedly is a no-op once registered.
     */
    private fun enqueue(): Boolean {
        return try {
            val request = PeriodicWorkRequestBuilder<WatchdogWorker>(
                15, TimeUnit.MINUTES
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WatchdogWorker.UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun cancel(): Boolean {
        return try {
            WorkManager.getInstance(context)
                .cancelUniqueWork(WatchdogWorker.UNIQUE_WORK_NAME)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun lastHeartbeatMs(): Long? {
        val prefs = context.getSharedPreferences(
            WatchdogWorker.HEARTBEAT_PREFS,
            Context.MODE_PRIVATE
        )
        val v = prefs.getLong(WatchdogWorker.HEARTBEAT_KEY, 0L)
        return if (v == 0L) null else v
    }

    private fun secondsSinceLastPing(): Long? {
        val last = lastHeartbeatMs() ?: return null
        return (System.currentTimeMillis() - last) / 1000
    }

    /**
     * Day 25 — true when the periodic work is currently enqueued (in
     * `ENQUEUED` or `RUNNING` state). Synchronous via `.get()` because the
     * channel handler runs on a worker thread, not the main thread.
     */
    private fun isEnqueued(): Boolean {
        return try {
            val infos = WorkManager.getInstance(context)
                .getWorkInfosForUniqueWork(WatchdogWorker.UNIQUE_WORK_NAME)
                .get()
            infos.any {
                it.state == WorkInfo.State.ENQUEUED ||
                    it.state == WorkInfo.State.RUNNING
            }
        } catch (e: Exception) {
            false
        }
    }
}
