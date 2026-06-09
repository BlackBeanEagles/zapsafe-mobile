package com.zapsafe.zapsafe_mobile

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Day 27 — pure-Kotlin acoustic-feature extractor.
 *
 * Produces, per 450 ms Hann-windowed frame:
 *   • 13 MFCC coefficients (the canonical speech-recognition front-end)
 *   • Zero-Crossing Rate         (cheap voicing / fricative indicator)
 *   • Spectral Centroid          (broadband brightness, helps separate
 *                                 scream / shout from low-energy speech)
 *
 * Total = 15 scalars. These get serialised as a `Map<String, Any>` and
 * emitted over the `com.zapsafe/audio.features` EventChannel. Day 31's
 * TFLite scream classifier consumes them as its input layer.
 *
 * Algorithm:
 *   1. Zero-pad / truncate the 7 200-sample frame to FFT_SIZE = 8192
 *      (next power of 2 above the window length).
 *   2. Cooley-Tukey radix-2 in-place FFT (real + imag DoubleArrays).
 *   3. Magnitude spectrum over the first `N/2 + 1` bins.
 *   4. Mel filterbank → 26 log-mel energies.
 *   5. DCT-II → 13 MFCC coefficients (drop bin 0? we keep it for energy).
 *   6. ZCR on the raw `ShortArray` (sign-flip count / length).
 *   7. Spectral centroid: Σ(mag·freq) / Σ(mag) over the positive half.
 *
 * Buffers are reused between calls so we don't allocate ~128 KB / second.
 */
object MfccExtractor {

    // ── Constants ──────────────────────────────────────────────────────────
    const val FFT_SIZE        = 8192
    const val MEL_BINS        = 26
    const val MFCC_COUNT      = 13
    const val SAMPLE_RATE_HZ  = AudioCaptureService.SAMPLE_RATE_HZ
    private const val NYQUIST = SAMPLE_RATE_HZ / 2.0
    private const val HALF_FFT = FFT_SIZE / 2 + 1

    // ── Pre-computed lookup tables ─────────────────────────────────────────
    private val melFilterbank: Array<DoubleArray> = buildMelFilterbank()
    private val dctMatrix:      Array<DoubleArray> = buildDctMatrix()

    // ── Re-usable working buffers (thread-confined: capture loop only) ─────
    private val real = DoubleArray(FFT_SIZE)
    private val imag = DoubleArray(FFT_SIZE)
    private val mags = DoubleArray(HALF_FFT)
    private val logMel = DoubleArray(MEL_BINS)

    /**
     * Extracts MFCC + ZCR + spectral centroid from a 16-bit PCM frame.
     * Call sites must invoke this from a single thread — the buffers are
     * shared and not synchronised. The capture loop in
     * [AudioCaptureService] is that single thread.
     */
    fun extract(samples: ShortArray, sampleCount: Int): AudioFeatures {
        // 1. Copy / pad / normalise into the real buffer.
        val n = minOf(sampleCount, FFT_SIZE)
        for (i in 0 until n) {
            real[i] = samples[i].toDouble() / 32768.0
        }
        for (i in n until FFT_SIZE) real[i] = 0.0
        for (i in 0 until FFT_SIZE) imag[i] = 0.0

        // 2. FFT in-place.
        fftRadix2(real, imag)

        // 3. Magnitude spectrum over positive half.
        for (k in 0 until HALF_FFT) {
            mags[k] = sqrt(real[k] * real[k] + imag[k] * imag[k])
        }

        // 4. Mel filterbank → log-mel.
        for (b in 0 until MEL_BINS) {
            var sum = 0.0
            val filter = melFilterbank[b]
            for (k in 0 until HALF_FFT) {
                sum += mags[k] * filter[k]
            }
            // `ln(max(x, 1e-10))` keeps log finite on silent bins.
            logMel[b] = ln(maxOf(sum, 1e-10))
        }

        // 5. DCT-II → 13 MFCC.
        val mfcc = DoubleArray(MFCC_COUNT)
        for (c in 0 until MFCC_COUNT) {
            var sum = 0.0
            val row = dctMatrix[c]
            for (b in 0 until MEL_BINS) {
                sum += logMel[b] * row[b]
            }
            mfcc[c] = sum
        }

        // 6. Zero-crossing rate on raw PCM (signs only).
        var crossings = 0
        for (i in 1 until n) {
            if ((samples[i - 1] >= 0) != (samples[i] >= 0)) crossings++
        }
        val zcr = if (n > 0) crossings.toDouble() / n else 0.0

        // 7. Spectral centroid in Hz.
        var num = 0.0
        var den = 0.0
        for (k in 1 until HALF_FFT) {
            val freq = k * SAMPLE_RATE_HZ.toDouble() / FFT_SIZE
            num += mags[k] * freq
            den += mags[k]
        }
        val centroid = if (den > 0) num / den else 0.0

        return AudioFeatures(mfcc, zcr, centroid)
    }

    // ── In-place Cooley-Tukey radix-2 FFT ───────────────────────────────────
    private fun fftRadix2(re: DoubleArray, im: DoubleArray) {
        val n = re.size
        // Bit-reversal permutation.
        var j = 0
        for (i in 0 until n - 1) {
            if (i < j) {
                var tmp = re[i]; re[i] = re[j]; re[j] = tmp
                tmp = im[i]; im[i] = im[j]; im[j] = tmp
            }
            var m = n shr 1
            while (m >= 1 && j >= m) {
                j -= m
                m = m shr 1
            }
            j += m
        }
        // Butterfly.
        var len = 2
        while (len <= n) {
            val halfLen = len shr 1
            val angleStep = -2.0 * PI / len
            var i = 0
            while (i < n) {
                for (k in 0 until halfLen) {
                    val angle = angleStep * k
                    val cs = cos(angle); val sn = sin(angle)
                    val tR = re[i + k + halfLen] * cs - im[i + k + halfLen] * sn
                    val tI = re[i + k + halfLen] * sn + im[i + k + halfLen] * cs
                    re[i + k + halfLen] = re[i + k] - tR
                    im[i + k + halfLen] = im[i + k] - tI
                    re[i + k] = re[i + k] + tR
                    im[i + k] = im[i + k] + tI
                }
                i += len
            }
            len = len shl 1
        }
    }

    // ── Mel filterbank construction ─────────────────────────────────────────
    private fun buildMelFilterbank(): Array<DoubleArray> {
        val maxMel = hzToMel(NYQUIST)
        // MEL_BINS triangular filters require MEL_BINS + 2 mel boundaries.
        val melPoints = DoubleArray(MEL_BINS + 2) { i ->
            i * maxMel / (MEL_BINS + 1)
        }
        val binPoints = IntArray(MEL_BINS + 2) { i ->
            (melToHz(melPoints[i]) * FFT_SIZE / SAMPLE_RATE_HZ).toInt()
                .coerceIn(0, HALF_FFT - 1)
        }
        return Array(MEL_BINS) { b ->
            DoubleArray(HALF_FFT).also { fb ->
                val left   = binPoints[b]
                val center = binPoints[b + 1]
                val right  = binPoints[b + 2]
                if (center > left) {
                    for (k in left until center) {
                        fb[k] = (k - left).toDouble() / (center - left).toDouble()
                    }
                }
                if (right > center) {
                    for (k in center until right) {
                        fb[k] = (right - k).toDouble() / (right - center).toDouble()
                    }
                }
            }
        }
    }

    // ── DCT-II matrix (orthonormal) ─────────────────────────────────────────
    private fun buildDctMatrix(): Array<DoubleArray> {
        return Array(MFCC_COUNT) { c ->
            DoubleArray(MEL_BINS) { b ->
                cos(PI * c * (b + 0.5) / MEL_BINS)
            }
        }
    }

    private fun hzToMel(hz: Double): Double = 2595.0 * log10(1.0 + hz / 700.0)
    private fun melToHz(mel: Double): Double = 700.0 * (10.0.pow(mel / 2595.0) - 1.0)
}

/**
 * Output of one feature-extraction pass. Shipped over EventChannel as a Map.
 * MFCC is a fixed-size array of [MfccExtractor.MFCC_COUNT] doubles.
 */
data class AudioFeatures(
    val mfcc: DoubleArray,
    val zcr: Double,
    val spectralCentroidHz: Double,
)
