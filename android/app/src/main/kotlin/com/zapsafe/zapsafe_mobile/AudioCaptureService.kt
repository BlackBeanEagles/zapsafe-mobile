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

        /**
         * Day 257 — was 16 kHz. m1_scream_v2 was trained on librosa features
         * at 22.05 kHz and the Dart mel pipeline does not resample, so
         * capturing at any other rate starves the model.
         *
         * [MfccExtractor] derives its own `SAMPLE_RATE_HZ` from this constant,
         * so its frequency maths follows automatically and spectral-centroid
         * values stay in true Hz. Its Nyquist does move (8 kHz -> 11.025 kHz),
         * which widens the legacy 26-bin mel filterbank; the heuristic gates
         * are expressed in physical Hz so they remain meaningful, but they
         * were tuned at 16 kHz and are worth re-checking on real audio.
         */
        const val SAMPLE_RATE_HZ = 22_050

        /**
         * Rates we will accept from [AudioRecord], in preference order.
         * 22 050 needs no resampling at all. 44 100 is near-universally
         * supported and decimates to 22 050 by exactly 2, which is a clean
         * halfband filter rather than a rational approximation.
         */
        val ACCEPTED_CAPTURE_RATES = intArrayOf(22_050, 44_100)

        const val WINDOW_MS = 450
        const val WINDOW_SAMPLES = SAMPLE_RATE_HZ * WINDOW_MS / 1000  // 9 922

        /** 3 s at [SAMPLE_RATE_HZ] — exactly what m1_scream_v2 expects. */
        const val MEL_WINDOW_SAMPLES = SAMPLE_RATE_HZ * 3  // 66 150

        /**
         * How far the rolling window advances between emissions. 1 s gives a
         * fresh 3 s window every second with 2 s of overlap, so a scream near
         * a window boundary still lands whole inside the next one.
         */
        const val MEL_HOP_SAMPLES = SAMPLE_RATE_HZ  // 22 050

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

    /**
     * The rate [AudioRecord] actually gave us — one of
     * [ACCEPTED_CAPTURE_RATES], not necessarily [SAMPLE_RATE_HZ]. Shipped to
     * Flutter with every PCM window so the Dart side knows whether it has to
     * decimate. Never assume this equals [SAMPLE_RATE_HZ].
     */
    @Volatile var captureRateHz: Int = SAMPLE_RATE_HZ
        private set

    val isRunning: Boolean get() = running

    // ── Rolling raw-PCM window for the mel / m1_scream_v2 path ─────────────
    //
    // Deliberately separate from the 450 ms MFCC buffer, and deliberately
    // filled BEFORE the Hann taper below. mel_spectrogram.dart applies its
    // own periodic Hann per STFT frame; shipping pre-tapered samples would
    // window the signal twice and produce a spectrum of exactly the right
    // shape that the model scores wrongly.
    private var melRing: ShortArray = ShortArray(0)
    private var melWrite = 0        // next write index, wraps
    private var melFilled = 0       // samples written since last emit
    private var melTotal = 0        // samples ever written (warm-up check)

    private fun melCapacity(): Int =
        MEL_WINDOW_SAMPLES * captureRateHz / SAMPLE_RATE_HZ

    private fun melHop(): Int =
        MEL_HOP_SAMPLES * captureRateHz / SAMPLE_RATE_HZ

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
        onPcmWindow: ((PcmWindow) -> Unit)? = null,
    ): Boolean {
        if (running) return true

        // Pick the first rate the device will actually give us. Asking for
        // 22 050 and silently getting something else is how the model ends up
        // being fed the wrong thing, so the chosen rate is recorded and
        // shipped to Dart rather than assumed.
        var chosenRate = 0
        var minBuffer = 0
        for (rate in ACCEPTED_CAPTURE_RATES) {
            val size = AudioRecord.getMinBufferSize(
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (size > 0) {
                chosenRate = rate
                minBuffer = size
                break
            }
            Log.w(TAG, "rate ${rate}Hz unsupported (getMinBufferSize=$size)")
        }
        if (chosenRate == 0) {
            Log.w(TAG, "no accepted capture rate available — abort")
            return false
        }
        captureRateHz = chosenRate

        // We want at least 2× our window so the reader can run ahead of the
        // capture thread without blocking. Use the larger of the two.
        val bufferBytes = maxOf(minBuffer, WINDOW_SAMPLES * 2 * Short.SIZE_BYTES)

        try {
            recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                chosenRate,
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

        // Size the rolling buffer for the rate we actually got.
        melRing = ShortArray(melCapacity())
        melWrite = 0
        melFilled = 0
        melTotal = 0

        running = true
        captureThread = Thread(
            { runLoop(onFrame, onFeatures, onPcmWindow) },
            "ZapSafeAudioCapture",
        ).also {
            it.priority = Thread.MAX_PRIORITY - 1
            it.start()
        }
        Log.i(
            TAG,
            "Capture started · ${captureRateHz}Hz " +
                "(model wants ${SAMPLE_RATE_HZ}Hz) · ${WINDOW_MS}ms window · " +
                "mel window ${melCapacity()} samples, hop ${melHop()}",
        )
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
        onPcmWindow: ((PcmWindow) -> Unit)?,
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

            // ── Rolling 3 s window for m1_scream_v2 ───────────────────
            //
            // MUST come before the Hann taper below, which mutates `buf`
            // in place. Also unconditional on `voiced`: the model needs a
            // continuous 3 s of audio, and dropping quiet stretches would
            // splice together samples that were never adjacent.
            if (onPcmWindow != null) {
                appendToMelRing(buf, read)
                if (melTotal >= melRing.size && melFilled >= melHop()) {
                    melFilled = 0
                    val window = PcmWindow(
                        timestampMs = timestampMs,
                        sampleRateHz = captureRateHz,
                        pcm = snapshotMelRing(),
                    )
                    mainHandler.post { onPcmWindow(window) }
                }
            }

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

    /** Copies `count` raw samples into the ring, wrapping as needed. */
    private fun appendToMelRing(src: ShortArray, count: Int) {
        val cap = melRing.size
        if (cap == 0) return
        var i = 0
        while (i < count) {
            val chunk = minOf(count - i, cap - melWrite)
            System.arraycopy(src, i, melRing, melWrite, chunk)
            melWrite = (melWrite + chunk) % cap
            i += chunk
        }
        melFilled += count
        // Saturate rather than overflow on a long-running capture.
        melTotal = if (melTotal > cap) cap + 1 else melTotal + count
    }

    /**
     * Unrolls the ring into a little-endian 16-bit byte array, oldest sample
     * first. Byte array rather than a short list because this crosses a
     * platform channel every hop — 132 KB as bytes, versus a boxed
     * `List<Int>` of 66 150 entries.
     */
    private fun snapshotMelRing(): ByteArray {
        val cap = melRing.size
        val out = ByteArray(cap * 2)
        for (n in 0 until cap) {
            val s = melRing[(melWrite + n) % cap].toInt()
            out[n * 2] = (s and 0xFF).toByte()
            out[n * 2 + 1] = ((s shr 8) and 0xFF).toByte()
        }
        return out
    }
}

/**
 * One rolling window of raw, un-windowed 16-bit PCM destined for the Dart mel
 * pipeline.
 *
 * [sampleRateHz] is the rate the samples are actually at, which may not be
 * [AudioCaptureService.SAMPLE_RATE_HZ]. Dart resamples when they differ —
 * see `audio_resampler.dart`.
 */
data class PcmWindow(
    val timestampMs: Long,
    val sampleRateHz: Int,
    val pcm: ByteArray,
) {
    // ByteArray in a data class: identity equals/hashCode are wrong, and
    // content-based ones on 132 KB are a footgun. Neither is needed.
    override fun equals(other: Any?): Boolean = this === other
    override fun hashCode(): Int = System.identityHashCode(this)
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
