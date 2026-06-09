package com.zapsafe.zapsafe_mobile

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Day 24 — LP4 watchdog.
 *
 * WorkManager runs this once every 15 minutes (the OS-imposed minimum) and
 * the worker checks the last heartbeat from `ZapSafeService` against the
 * 30-second threshold. If the service has gone silent, the worker fires up
 * a fresh `startForegroundService` so the safety engine doesn't stay dead.
 *
 * LP4 (App Watchdog) targets:
 *  - Android: ≤ 30 seconds to recover from a silent kill
 *  - iOS:     ≤ 45 seconds (Apple's BG-task latency cap)
 *
 * 30 seconds is much shorter than WorkManager's 15-min schedule, so the
 * worker IS still useful even when the gap is large — between scheduled
 * runs, `START_STICKY` on the service is the primary recovery mechanism.
 * WorkManager only catches the edge case where START_STICKY also fails
 * (battery pulled, OOM-killer, etc.).
 */
class WatchdogWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        const val TAG = "ZapSafeWatchdog"
        const val UNIQUE_WORK_NAME = "zapsafe_watchdog"
        const val HEARTBEAT_PREFS  = "zapsafe_engine"
        const val HEARTBEAT_KEY    = "last_heartbeat_ms"

        /** LP4 threshold — the engine must ping at least this often. */
        const val THRESHOLD_MS = 30_000L
    }

    override fun doWork(): Result {
        val prefs = applicationContext
            .getSharedPreferences(HEARTBEAT_PREFS, Context.MODE_PRIVATE)
        val lastPing = prefs.getLong(HEARTBEAT_KEY, 0L)
        val now = System.currentTimeMillis()
        val sinceLast = if (lastPing == 0L) Long.MAX_VALUE else now - lastPing

        val needsRestart = sinceLast > THRESHOLD_MS
        Log.i(
            TAG,
            "Heartbeat check · last=${lastPing} now=${now} " +
                "since=${sinceLast}ms threshold=${THRESHOLD_MS}ms " +
                "needsRestart=$needsRestart"
        )

        if (needsRestart) {
            try {
                val intent = Intent(applicationContext, ZapSafeService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }
                Log.i(TAG, "ZapSafeService restart requested by watchdog")
            } catch (e: Exception) {
                Log.e(TAG, "Watchdog restart failed: ${e.message}")
                // Don't return Result.failure — that prevents future runs.
                // retry() asks WorkManager to back off and try again.
                return Result.retry()
            }
        }

        return Result.success()
    }
}
