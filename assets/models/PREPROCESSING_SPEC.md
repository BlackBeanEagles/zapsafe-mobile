# Model Preprocessing Spec (Day 257)

Measured directly from the exported `.tflite` files and the training
scripts — not inferred from documentation. Every number here was verified
by running the real models against real audio from
`ml_datasets/audio_events/DS07_AudioSet/` (65,897 clips).

Get any of this wrong and the model returns confident nonsense rather
than an error, which is the reason this file exists.

## m1_scream_v2 — `scream_classifier_v1.tflite`

Real trained model, 2,811 KB. Replaces a 658-byte placeholder that had
been shipping since the assets were first created.

| | |
|---|---|
| Reported AUC | 0.9101 |
| Precision / recall (scream) | 0.9424 / 0.9529 |
| Targets | 0.90 / 0.88 — both met |
| Input tensor | `[1, 128, 131, 1]` float32 |
| Output tensor | `[1, 1]` float32, sigmoid probability |

**Preprocessing** (from `m1_train_v2.py`, confirmed against
`ZapSafe_M1_v2_Scream.ipynb`):

```
sample rate   22050 Hz, mono
duration      3 s  -> pad or truncate to exactly 66150 samples
mel           librosa.feature.melspectrogram(n_mels=128, n_fft=2048, hop_length=512)
scale         librosa.power_to_db(mel, ref=np.max)
normalise     (db - db.min()) / (db.max() - db.min() + 1e-9)   # per-clip min-max
frames        pad to 131 (see below)
```

### The 131 vs 130 discrepancy

The training pipeline as written produces **130** frames
(`1 + 66150 // 512`), but the exported model expects **131**. The
training script and notebook agree with each other, so the exported model
was built with something marginally different — a librosa version or a
duration rounding.

Measured impact: padding the missing frame with zeros versus repeating
the last frame changes the output by at most **0.0195** across 10 real
clips, and is usually identical. Zero-pad and move on; this is not worth
chasing.

## m2_motion_v2 — `motion_anomaly_v1.tflite`

| | |
|---|---|
| Input tensor | `[1, 100, 6]` float32 |
| Output tensor | `[1, 1]` float32 |

100 IMU samples x 6 channels (accelerometer xyz + gyroscope xyz).

## m3_scene_analyzer — `scene_analyzer_v1.tflite`

2,811 KB, real. Image classifier; see `models/components/m3_metadata.json`.

## Do NOT ship m9_dcs_fusion

`m9_dcs_fusion_v1.tflite` is 2 KB and its own report records
`production_pass: false` — trained on synthetic data and failed its gate.
`models/M9_STATUS.md` says the same. It is deliberately not copied into
assets.

---

# The blocker: the native pipeline cannot feed these models

`android/.../MfccExtractor.kt` and `AudioCaptureService.kt` produce
something structurally different from what m1 expects. Every parameter
differs:

| | Native today | m1 requires |
|---|---|---|
| Sample rate | 16,000 Hz | **22,050 Hz** |
| Window | 450 ms (7,200 samples) | **3 s (66,150)** |
| FFT size | 8,192 | **2,048** |
| Mel bands | **26** | **128** |
| Output | one MFCC vector | **128 x 131 spectrogram** |

So this is not a Dart wiring task. It requires rewriting the native audio
feature extraction to emit librosa-compatible mel spectrograms:

1. Capture (or resample) at 22,050 Hz
2. Buffer a rolling 3-second window instead of 450 ms
3. STFT with n_fft=2048, hop=512, centred, producing 131 frames
4. A **128-band mel filterbank matching librosa's** — note librosa
   defaults to the Slaney scale and `norm='slaney'`; an HTK-style
   filterbank will produce plausible-looking output that the model
   scores wrongly
5. `power_to_db(ref=max)` then per-clip min-max normalisation

Step 4 is where this silently goes wrong. The correct way to verify is
not "does it run" but: compute features for the same wav file in both
Python and Kotlin and assert they match to a small tolerance. Without
that check there is no way to distinguish a working pipeline from a
broken one, because both produce numbers in the right shape and range.

## Suggested order

Ship **m1_scream alone** first. It is the highest-value model in the app
and one pipeline to get right. m2_motion is far easier (raw IMU samples,
no spectrogram) and is a reasonable second. m3_scene needs a camera frame
path, which is a separate concern again.
