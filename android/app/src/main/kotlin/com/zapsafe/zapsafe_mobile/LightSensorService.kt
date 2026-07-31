package com.zapsafe.zapsafe_mobile

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Day 274 — real ambient-light sensor capture.
 *
 * Follows [AudioCaptureService]'s split (capture logic here, channel
 * bridging in [LightChannelHandler]) and [SensorChannelHandler]'s direct
 * `SensorManager` usage (no `sensors_plus` dependency needed — this app's
 * pinned `sensors_plus: ^4.0.0` does not expose an ambient-light stream at
 * all; [Sensor.TYPE_LIGHT] has been in the platform `SensorManager` API
 * since API level 1, so a small native platform channel is the real,
 * available path, not a plugin upgrade).
 *
 * [Sensor.TYPE_LIGHT] reports illuminance in SI lux — NOT the
 * `k_confinement` model's trained `light` scalar (roughly `0.0`-`0.9`,
 * an unnormalized "darkness fraction" the training scripts invented, never
 * calibrated against real measured lux — see
 * `DAY269_K_CONFINEMENT_SCOPING.md` and `day272_k_confinement_decorrelated
 * .py`'s own `decorrelate_light()` docstring: "No real ambient-light/lux
 * dataset exists locally"). This service reports raw lux only; the
 * lux -> model-scalar mapping is a Dart-side heuristic
 * (`light_sensor_channel.dart`'s `luxToModelLight`), not something this
 * native layer should guess at.
 *
 * No `RECORD_AUDIO`-style dangerous permission applies to
 * [Sensor.TYPE_LIGHT] — ambient light has been a normal (non-dangerous)
 * Android sensor since API 1, so no manifest permission is required.
 */
class LightSensorService {

    companion object {
        const val TAG = "ZapSafeLightSensor"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var running = false
    private var sensorManager: SensorManager? = null
    private var lightSensor: Sensor? = null

    val isRunning: Boolean get() = running

    private var onReading: ((lux: Float, timestampMs: Long) -> Unit)? = null

    private val listener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* no-op */ }

        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null || !running) return
            val lux = event.values[0]
            mainHandler.post { onReading?.invoke(lux, System.currentTimeMillis()) }
        }
    }

    /** True if this device reports a [Sensor.TYPE_LIGHT] sensor at all. */
    fun hasLightSensor(context: Context): Boolean {
        val sm = sensorManager
            ?: (context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager).also {
                sensorManager = it
            }
        val sensor = lightSensor ?: sm?.getDefaultSensor(Sensor.TYPE_LIGHT).also { lightSensor = it }
        return sensor != null
    }

    /**
     * Starts streaming. Returns false if no light sensor is present on this
     * device — a real, expected outcome on many phones/emulators, not an
     * error. Callers (the Dart side) must fall back to the documented
     * placeholder in that case, exactly as before this session for devices
     * without one.
     */
    fun start(context: Context, onReading: (lux: Float, timestampMs: Long) -> Unit): Boolean {
        if (running) return true
        if (!hasLightSensor(context)) {
            Log.w(TAG, "no ambient light sensor on this device")
            return false
        }
        this.onReading = onReading
        running = true
        sensorManager?.registerListener(listener, lightSensor, SensorManager.SENSOR_DELAY_NORMAL)
        Log.i(TAG, "light sensor streaming started")
        return true
    }

    fun stop() {
        if (!running) return
        running = false
        sensorManager?.unregisterListener(listener)
        onReading = null
        Log.i(TAG, "light sensor streaming stopped")
    }
}
