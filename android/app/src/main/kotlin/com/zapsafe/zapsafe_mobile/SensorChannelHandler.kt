package com.zapsafe.zapsafe_mobile

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin

/**
 * Day 23 — Stub IMU stream handler.
 *
 * Emits a synthetic 10-Hz sine waveform on the EventChannel
 * `com.zapsafe/sensors.events` so the Dart side can be exercised end-to-end
 * before the real `SensorManager` code lands in Day 28. Start / stop / is-
 * streaming are controlled via the MethodChannel `com.zapsafe/sensors`.
 *
 * Why a stub: hardware-driven testing requires a real device. The stub
 * shape (Map with t/ax/ay/az/gx/gy/gz keys) matches what `SensorChannel`
 * expects, so swapping in the real implementation later is invisible to
 * Flutter consumers.
 */
class SensorChannelHandler(messenger: BinaryMessenger) {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.zapsafe/sensors"
        const val EVENT_CHANNEL_NAME  = "com.zapsafe/sensors.events"
        const val EMIT_INTERVAL_MS    = 100L  // 10 Hz
    }

    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var running = false
    private var tick = 0L

    init {
        MethodChannel(messenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start"        -> { running = true;  scheduleEmit(); result.success(true) }
                "stop"         -> { running = false; result.success(true) }
                "isStreaming"  -> result.success(running)
                else           -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    if (running) scheduleEmit()
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun scheduleEmit() {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed(::emit, EMIT_INTERVAL_MS)
    }

    private fun emit() {
        if (!running || eventSink == null) return
        tick++
        // Synthetic waveform — phase-shifted sines so each axis is distinct
        // when sketched on a chart. Real sensor data will replace this.
        val phase = tick * 0.1
        eventSink!!.success(
            mapOf(
                "t"  to System.currentTimeMillis(),
                "ax" to sin(phase),
                "ay" to sin(phase + 1.0),
                "az" to sin(phase + 2.0) + 9.81,  // +g so it looks gravity-correct
                "gx" to sin(phase * 0.7),
                "gy" to sin(phase * 0.7 + 1.5),
                "gz" to sin(phase * 0.7 + 3.0)
            )
        )
        scheduleEmit()
    }
}
