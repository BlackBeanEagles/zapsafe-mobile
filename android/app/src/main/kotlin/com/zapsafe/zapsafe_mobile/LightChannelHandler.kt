package com.zapsafe.zapsafe_mobile

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Day 274 — bridges Flutter to [LightSensorService], mirroring
 * [AudioChannelHandler]'s split between capture logic and channel
 * plumbing.
 *
 *   • MethodChannel `com.zapsafe/light`        — control surface
 *   • EventChannel  `com.zapsafe/light.events` — per-reading `{t, lux}`
 *
 * See [LightSensorService]'s doc comment for why this reports raw lux
 * (not the `k_confinement` model's `light` scalar directly) and why no
 * manifest permission is needed.
 */
class LightChannelHandler(
    messenger: BinaryMessenger,
    private val context: Context,
) {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.zapsafe/light"
        const val EVENT_CHANNEL_NAME  = "com.zapsafe/light.events"
        const val TAG = "ZapSafeLight"
    }

    private val service = LightSensorService()
    private var eventSink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val ok = service.start(context) { lux, t -> emitReading(lux, t) }
                    Log.i(TAG, "Start requested -> $ok")
                    result.success(ok)
                }
                "stop" -> {
                    service.stop()
                    result.success(true)
                }
                "isStreaming"     -> result.success(service.isRunning)
                "hasLightSensor"  -> result.success(service.hasLightSensor(context))
                else              -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun emitReading(lux: Float, timestampMs: Long) {
        eventSink?.success(
            mapOf(
                "t"   to timestampMs,
                "lux" to lux.toDouble(),
            )
        )
    }
}
