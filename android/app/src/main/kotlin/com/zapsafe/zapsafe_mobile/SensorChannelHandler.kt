package com.zapsafe.zapsafe_mobile

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Day 258 — real IMU stream. Was a synthetic 10 Hz sine wave.
 *
 * m2_motion_v2 takes `[1, 100, 6]`: 100 consecutive samples of
 * `[acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z]` at **50 Hz** — a 2-second
 * window (`day83_m2_motion_v2.py`, `WINDOW_SIZE = 100`). The stub emitted
 * 10 Hz synthetic sines, so a window of 100 samples spanned 10 seconds of
 * data that no accelerometer ever produced. The model would have scored it
 * without complaint.
 *
 * Units matter and are not converted here: Android reports
 * [Sensor.TYPE_ACCELEROMETER] in m/s^2 including gravity, and
 * [Sensor.TYPE_GYROSCOPE] in rad/s. Those are the units the training data
 * was in — the fitted channel means in `m2_motion_v2_report.json`
 * (acc_y ~= 7.61, gyro ~= 0.07) are only consistent with gravity-inclusive
 * m/s^2 and rad/s. Do not switch to TYPE_LINEAR_ACCELERATION, which removes
 * gravity and would shift acc_y by about 9.8 — roughly one standard
 * deviation, silently.
 *
 * Sampling: accelerometer and gyroscope deliver events independently. We
 * hold the most recent gyro reading and emit one fused sample per
 * accelerometer event, which paces the stream at the accelerometer's rate.
 */
class SensorChannelHandler(
    messenger: BinaryMessenger,
    private val context: Context,
) {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.zapsafe/sensors"
        const val EVENT_CHANNEL_NAME  = "com.zapsafe/sensors.events"
        const val TAG = "ZapSafeSensors"

        /** m2_motion_v2's training rate. */
        const val TARGET_RATE_HZ = 50

        /**
         * Requested sensor period. Android treats this as a hint, so the
         * delivered rate is approximate; [MIN_INTERVAL_US] enforces an upper
         * bound so a device running fast does not compress the model's
         * 2-second window into something shorter.
         */
        const val SAMPLING_PERIOD_US = 1_000_000 / TARGET_RATE_HZ  // 20 000

        /** Drop samples arriving sooner than this since the last emit. */
        const val MIN_INTERVAL_US = SAMPLING_PERIOD_US * 8 / 10     // 16 000
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var running = false

    private val sensorManager: SensorManager? =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private var accel: Sensor? = null
    private var gyro: Sensor? = null

    // Latest gyro reading, fused into each accelerometer event.
    @Volatile private var gx = 0.0f
    @Volatile private var gy = 0.0f
    @Volatile private var gz = 0.0f
    @Volatile private var haveGyro = false

    private var lastEmitUs = 0L
    private var emitted = 0L
    private var dropped = 0L

    private val listener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* no-op */ }

        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null || !running) return
            when (event.sensor.type) {
                Sensor.TYPE_GYROSCOPE -> {
                    gx = event.values[0]; gy = event.values[1]; gz = event.values[2]
                    haveGyro = true
                }
                Sensor.TYPE_ACCELEROMETER -> {
                    // event.timestamp is nanos since boot, monotonic.
                    val us = event.timestamp / 1_000
                    if (lastEmitUs != 0L && us - lastEmitUs < MIN_INTERVAL_US) {
                        dropped++
                        return
                    }
                    lastEmitUs = us
                    emitted++
                    val ax = event.values[0]
                    val ay = event.values[1]
                    val az = event.values[2]
                    // A gyro-less device would otherwise emit three constant
                    // zero channels, which the model reads as "perfectly
                    // still" rather than "unknown".
                    val sample = mapOf(
                        "t"  to System.currentTimeMillis(),
                        "ax" to ax.toDouble(),
                        "ay" to ay.toDouble(),
                        "az" to az.toDouble(),
                        "gx" to gx.toDouble(),
                        "gy" to gy.toDouble(),
                        "gz" to gz.toDouble(),
                        "hasGyro" to haveGyro,
                    )
                    mainHandler.post { eventSink?.success(sample) }
                }
            }
        }
    }

    init {
        accel = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyro  = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        MethodChannel(messenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start"       -> result.success(startStreaming())
                "stop"        -> { stopStreaming(); result.success(true) }
                "isStreaming" -> result.success(running)
                "targetRateHz" -> result.success(TARGET_RATE_HZ)
                "hasAccelerometer" -> result.success(accel != null)
                "hasGyroscope"     -> result.success(gyro != null)
                "sampleStats" -> result.success(
                    mapOf("emitted" to emitted, "dropped" to dropped)
                )
                else -> result.notImplemented()
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

    private fun startStreaming(): Boolean {
        if (running) return true
        val sm = sensorManager
        val a = accel
        if (sm == null || a == null) {
            Log.w(TAG, "no accelerometer available — cannot stream IMU")
            return false
        }
        running = true
        lastEmitUs = 0L
        sm.registerListener(listener, a, SAMPLING_PERIOD_US)
        gyro?.let { sm.registerListener(listener, it, SAMPLING_PERIOD_US) }
            ?: Log.w(TAG, "no gyroscope — gyro channels will read 0")
        Log.i(TAG, "IMU streaming at ~${TARGET_RATE_HZ}Hz (gyro=${gyro != null})")
        return true
    }

    private fun stopStreaming() {
        if (!running) return
        running = false
        haveGyro = false
        sensorManager?.unregisterListener(listener)
        Log.i(TAG, "IMU stopped · emitted=$emitted dropped=$dropped")
    }
}
