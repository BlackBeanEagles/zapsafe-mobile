package com.zapsafe.zapsafe_mobile

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Day 26+27 — bridges Flutter to [AudioCaptureService].
 *
 *   • MethodChannel `com.zapsafe/audio`             — control surface
 *   • EventChannel  `com.zapsafe/audio.events`      — per-window [AudioFrame]
 *   • EventChannel  `com.zapsafe/audio.features`    — voiced-frame [AudioFeatures]
 */
class AudioChannelHandler(messenger: BinaryMessenger) {

    companion object {
        const val METHOD_CHANNEL_NAME    = "com.zapsafe/audio"
        const val EVENT_CHANNEL_NAME     = "com.zapsafe/audio.events"
        const val FEATURES_CHANNEL_NAME  = "com.zapsafe/audio.features"
        /** Day 257 — rolling 3 s raw PCM for the m1_scream_v2 mel pipeline. */
        const val PCM_CHANNEL_NAME       = "com.zapsafe/audio.pcm"
        const val TAG = "ZapSafeAudio"
    }

    private val captureService = AudioCaptureService()
    private var frameSink: EventChannel.EventSink? = null
    private var featuresSink: EventChannel.EventSink? = null
    private var pcmSink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val ok = captureService.start(
                        onFrame      = { frame -> emitFrame(frame) },
                        onFeatures   = { features, ts -> emitFeatures(features, ts) },
                        onPcmWindow  = { window -> emitPcmWindow(window) },
                    )
                    Log.i(TAG, "Start requested → $ok")
                    result.success(ok)
                }
                "stop" -> {
                    captureService.stop()
                    Log.i(TAG, "Stop")
                    result.success(true)
                }
                "isRecording"  -> result.success(captureService.isRunning)
                "vadThreshold" -> result.success(AudioCaptureService.VAD_RMS_THRESHOLD)
                "sampleRateHz" -> result.success(AudioCaptureService.SAMPLE_RATE_HZ)
                // The rate actually negotiated with AudioRecord, which may
                // differ from the model's required rate. Dart resamples.
                "captureRateHz"    -> result.success(captureService.captureRateHz)
                "melWindowSamples" -> result.success(AudioCaptureService.MEL_WINDOW_SAMPLES)
                "melHopSamples"    -> result.success(AudioCaptureService.MEL_HOP_SAMPLES)
                "windowMs"     -> result.success(AudioCaptureService.WINDOW_MS)
                "mfccCount"    -> result.success(MfccExtractor.MFCC_COUNT)
                "melBins"      -> result.success(MfccExtractor.MEL_BINS)
                "fftSize"      -> result.success(MfccExtractor.FFT_SIZE)
                else           -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) { frameSink = events }
                override fun onCancel(args: Any?) { frameSink = null }
            }
        )

        EventChannel(messenger, FEATURES_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) { featuresSink = events }
                override fun onCancel(args: Any?) { featuresSink = null }
            }
        )

        EventChannel(messenger, PCM_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) { pcmSink = events }
                override fun onCancel(args: Any?) { pcmSink = null }
            }
        )
    }

    private fun emitFrame(frame: AudioFrame) {
        frameSink?.success(
            mapOf(
                "t"      to frame.timestampMs,
                "rms"    to frame.rmsEnergy,
                "voiced" to frame.voiced,
                "n"      to frame.sampleCount,
                "window" to frame.windowMs,
                "thr"    to frame.threshold,
            )
        )
    }

    /**
     * Ships the raw window as bytes. `pcm` arrives in Dart as a `Uint8List`
     * of little-endian int16 — see `PcmWindow.fromMap` on that side. `sr` is
     * mandatory: the samples are only meaningful alongside their rate.
     */
    private fun emitPcmWindow(window: PcmWindow) {
        pcmSink?.success(
            mapOf(
                "t"    to window.timestampMs,
                "sr"   to window.sampleRateHz,
                "pcm"  to window.pcm,
            )
        )
    }

    private fun emitFeatures(features: AudioFeatures, timestampMs: Long) {
        featuresSink?.success(
            mapOf(
                "t"        to timestampMs,
                "mfcc"     to features.mfcc.toList(),  // → List<Double> on Flutter side
                "zcr"      to features.zcr,
                "centroid" to features.spectralCentroidHz,
            )
        )
    }
}
