package com.zapsafe.zapsafe_mobile

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sqrt

/**
 * Day 26 — Audio capture pipeline.
 *
 * Records 16 kHz mono 16-bit PCM via [AudioRecord], maintains a 450 ms
 * sliding window (= 7 200 samples), gates each window through a
 * root-mean-square VAD check, and applies a Hann window to the gated
 * samples in preparation for the FFT / MFCC pipeline that lands on Day 27.
 *
 * The service emits one [AudioFrame] per window (~450 ms cadence, give or
 * take buffer-fill latency). Frames that fall below the VAD threshold are
 * still emitted with `voiced = false` so the Flutter side can render
 * silence as well as speech — it's cheaper than dropping them entirely and
 * the UI suppress-counter exists specifically to show this.
 *
 * Thread model: [AudioRecord.read] blocks. We spawn a single capture
 * thread and post each frame back to the main thread before invoking the
 * caller's callback, because EventChannel sinks aren't thread-safe.
 */
class AudioCaptureService {

    companion object {
        const val TAG = "ZapSafeAudioCapture"
        const val SAMPLE_RATE_HZ = 16_000
        const val WINDOW_MS = 450
        const val WINDOW_SAMPLES = SAMPLE_RATE_HZ * WINDOW_MS / 1000  // 7 200

        /**
         * RMS threshold for the VAD gate. 16-bit PCM samples range [-32768, 32767].
         * A whisper at typical phone-mic gain measures ~ 80; conversation hovers
         * around 1 200; silence with phone in pocket is < 80. We pick 300 so
         * we catch quiet speech without firing on HVAC + ambient hiss.
         */
        const val VAD_RMS_THRESHOLD = 300.0
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var running = false
    private var captureThread: Thread? = null
    private var recorder: AudioRecord? = null

    val isRunning: Boolean get() = running

    // Pre-computed Hann window — re-used on every frame to avoid per-frame
    // trig calls. Hann is a smooth cosine taper that suppresses spectral
    // leakage when we run an FFT (Day 27). Coefficients are in [0, 1].
    private val hannWindow: DoubleArray = DoubleArray(WINDOW_SAMPLES) { i ->
        0.5 * (1.0 - cos(2.0 * PI * i / (WINDOW_SAMPLES - 1)))
    }

    /**
     * Starts the capture loop. Returns true if [AudioRecord] initialised and
     * began recording; false if the `RECORD_AUDIO` permission is missing,
     * the buffer is too small, or another error occurred.
     *
     * [onFrame] fires once per 450 ms window with summary stats.
     * [onFeatures] (Day 27) fires only for voiced windows with the MFCC +
     * ZCR + spectral-centroid feature vector — that's the input layer of
     * the Day 31 scream classifier.
     */
    fun start(
        onFrame: (AudioFrame) -> Unit,
        onFeatures: ((AudioFeatures, Long) -> Unit)? = null,
    ): Boolean {
        if (running) return true

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            Log.w(TAG, "AudioRecord.getMinBufferSize returned $minBuffer — abort")
            return false
        }
        // We want at least 2× our window so the reader can run ahead of the
        // capture thread without blocking. Use the larger of the two.
        val bufferBytes = maxOf(minBuffer, WINDOW_SAMPLES * 2 * Short.SIZE_BYTES)

        try {
            recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE_HZ,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferBytes,
            ).also {
                if (it.state != AudioRecord.STATE_INITIALIZED) {
                    Log.w(TAG, "AudioRecord did not initialise — likely missing permission")
                    it.release()
                    recorder = null
                    return false
                }
                it.startRecording()
            }
        } catch (e: SecurityException) {
            // Missing RECORD_AUDIO permission.
            Log.w(TAG, "RECORD_AUDIO permission denied: ${e.message}")
            recorder?.release()
            recorder = null
            return false
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "AudioRecord rejected our config: ${e.message}")
            return false
        }

        running = true
        captureThread = Thread({ runLoop(onFrame, onFeatures) }, "ZapSafeAudioCapture").also {
            it.priority = Thread.MAX_PRIORITY - 1
            it.start()
        }
        Log.i(TAG, "Capture started · ${SAMPLE_RATE_HZ}Hz · ${WINDOW_MS}ms window")
        return true
    }

    /** Stops the capture loop. Idempotent. */
    fun stop() {
        if (!running) return
        running = false
        captureThread?.join(500)
        captureThread = null
        recorder?.also {
            try {
                if (it.recordingState == AudioRecord.RECORDSTATE_RECORDING) it.stop()
            } catch (_: Exception) { /* swallow */ }
            it.release()
        }
        recorder = null
        Log.i(TAG, "Capture stopped")
    }

    private fun runLoop(
        onFrame: (AudioFrame) -> Unit,
        onFeatures: ((AudioFeatures, Long) -> Unit)?,
    ) {
        val buf = ShortArray(WINDOW_SAMPLES)

        while (running) {
            val read = try {
                recorder?.read(buf, 0, WINDOW_SAMPLES) ?: 0
            } catch (e: Exception) {
                Log.w(TAG, "read failed: ${e.message}")
                break
            }
            if (read <= 0) continue
            val timestampMs = System.currentTimeMillis()

            // ── RMS energy over the un-windowed frame ─────────────────
            var sumSquares = 0.0
            for (i in 0 until read) {
                val s = buf[i].toDouble()
                sumSquares += s * s
            }
            val rms = if (read > 0) sqrt(sumSquares / read) else 0.0
            val voiced = rms > VAD_RMS_THRESHOLD

            // ── Hann taper · prep for FFT ─────────────────────────────
            if (voiced) {
                val end = minOf(read, WINDOW_SAMPLES)
                for (i in 0 until end) {
                    buf[i] = (buf[i].toDouble() * hannWindow[i])
                        .toInt()
                        .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                        .toShort()
                }
            }

            val frame = AudioFrame(
                timestampMs = timestampMs,
                rmsEnergy   = rms,
                voiced      = voiced,
                sampleCount = read,
                windowMs    = WINDOW_MS,
                threshold   = VAD_RMS_THRESHOLD,
            )
            mainHandler.post { onFrame(frame) }

            // ── Day 27 · features on voiced frames only ──────────────
            if (voiced && onFeatures != null) {
                val features = MfccExtractor.extract(buf, read)
                mainHandler.post { onFeatures(features, timestampMs) }
            }
        }
    }
}

/**
 * One window worth of capture metadata. PCM samples are not shipped to
 * Flutter (would be wasteful — Day 27 extracts the MFCC features natively).
 */
data class AudioFrame(
    val timestampMs: Long,
    val rmsEnergy: Double,
    val voiced: Boolean,
    val sampleCount: Int,
    val windowMs: Int,
    val threshold: Double,
)
