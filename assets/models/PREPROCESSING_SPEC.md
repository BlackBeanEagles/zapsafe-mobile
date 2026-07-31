# Model Preprocessing Spec (Day 257, revised Day 258)

Measured directly from the exported `.tflite` files and the training
scripts — not inferred from documentation.

Get any of this wrong and the model returns confident nonsense rather
than an error, which is the reason this file exists.

> **Start with the "READ THIS FIRST" section below** before relying on any
> model's reported accuracy. Two of the three models measured against real
> data do not match their own reports.
>
> Note on the dataset: `DS07_AudioSet/train_wav` holds **9,927** wav files
> locally. The 65,897 figure that used to appear here is the row count of the
> AudioSet segment CSVs, not files on disk.
>
> **Current status (Day 273, updated — this line is the source of truth,
> not the "0 of 20" claim further down, which is Day 259's snapshot and is
> now stale):** 7 models are wired, tested end-to-end, and backend-connected
> — `m1_scream_v2`, `m2_motion_v2`, `mg_gunshot` (AUC 0.9225), `motion_b`
> (test AUC 0.9808), `s_crowd_panic` (AUC 0.87, first two-input audio+IMU
> fusion detector), `i_vehicle_crash` (AUC 0.9622 fp32 / 0.8733 int8, second
> two-input audio+IMU fusion detector, Day 271), and
> `k_confinement_decorrelated` (AUC 0.9959, Day 272 retrain + Day 273
> wiring — see below). `m_glass_breaking` is real-data-improved (AUC 0.37 ->
> 0.75) but not shippable (recall 0.54, real data locally exhausted).
>
> `k_confinement`'s originally-shipped-staging model was an unresolved
> architecture problem (gated almost entirely on its `light` input, ignoring
> motion) — Day 272 fixed this with a decorrelated retrain (light/label
> confound removed on real PAMAP2/MotionSense IMU data; decisive check:
> output std at a realistic lit light value went from 0.0000 collapsed to
> 0.4775, with a real +0.2811 high-vs-low-motion discrimination gap), and
> Day 273 wired it in as `KConfinementDetector`/`KConfinementFusionPipeline`.
> **Important caveat, stated plainly**: this app has no ambient-light
> sensor integration (`sensors_plus: ^4.0.0`, this app's pinned version,
> does not expose one), so the model's `light` input is currently a fixed,
> documented placeholder value (0.5), not a real sensor reading — IMU is
> real, light is not. See `DAY273_K_CONFINEMENT_WIRING.md` and
> `k_confinement_pipeline.dart`'s class doc for the full explanation. Full
> evidence trail: `WEEK_ML_TRIAGE_SUMMARY.md`, `DAY260*.md` through
> `DAY265*.md`, `DAY271_VEHICLE_CRASH_WIRING.md`,
> `DAY272_K_CONFINEMENT_DECORRELATED_RETRAIN.md`,
> `DAY273_K_CONFINEMENT_WIRING.md` in this same folder.

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

### STFT centre padding is ZEROS, not reflect

`librosa.stft`'s default `pad_mode` changed from `'reflect'` to
`'constant'` in **librosa 0.10**. The fixture was generated with librosa
0.11, so zero-padding is what the golden values encode.

This one is worth stating explicitly because of how it fails. Reflect
padding is not a typo or a broken FFT — it is correct code implementing
the older default, and it changes **only the first two and last two
frames** of 130. Every structural property survives: shape, `[0,1]`
range, Slaney scale, determinism, low-band energy dominance. The mean
shifts by 0.002. The only thing that catches it is elementwise
comparison against librosa, which is why `test/fixtures/mel_golden.json`
exists.

If the model turns out to have been trained under librosa < 0.10, this
flips back to reflect — regenerate the fixture from the training
environment's librosa rather than changing the Dart by hand.

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

# READ THIS FIRST — measured accuracy does not match the reports (Day 258)

Every model below was run against **real audio** (`DS07_AudioSet/train_wav`,
9,927 wavs locally — the 65,897 figure is the CSV row count, not files on
disk) and against real IMU data (`DS11_UCI-HAR`). Two of the audio models do
not do what their reports claim.

| model | reported | measured on real audio | verdict |
|---|---|---|---|
| m1_scream_v2 | AUC 0.9101 | **AUC 0.569** (AudioSet, strict Screaming/Yell/Shout labels, sliding 3 s window) | works on clean speech, collapses on real-world audio |
| m1_scream_v2 | — | **AUC 0.865**, 41.7 % recall @ 0 % FPR (RAVDESS, clean acted) | this is its actual operating domain |
| m1_pocket_muffled | AUC 0.9759, pocket_recall 1.0 | **AUC 0.500 — constant 1.000 output** on pocket-muffled audio | do NOT ship |
| m2_motion_v2 | AUC 0.98, fall_recall 1.0 | walking 0.004 / injected fall 0.980 on real UCI-HAR | works |

Two things to understand about the audio numbers:

**The reported metrics are inflated by the eval split.** m1_scream_v2's own
report records `support_positive: 1613, support_negative: 343` — an 82.5 %
positive test set. A model that answered "scream" to everything would score
precision 0.825 there, so the reported 0.9424 is barely above the trivial
baseline. m1_pocket_muffled's `pocket_recall: 1.0` on 100 pocket samples is
what a constant-yes model scores, and measurement confirms it *is* constant-yes
on pocket audio — it returns 1.000 for neutral speech as readily as for
screams.

**m1_scream_v2 is not broken, it fails to generalise.** Preprocessing is
confirmed correct (librosa parity to 1e-6 on real audio, see
`test/mel_real_audio_parity_test.dart`) and the model reaches AUC 0.865 on
clean acted RAVDESS — the distribution it was trained on. It drops to 0.569 on
noisy YouTube audio. That is domain shift, and it needs retraining with
real-world negatives, not more wiring.

**Consequence for the app:** m1_scream_v2 must not be a standalone trigger at
`threshold = 0.5`. On real audio no threshold gives a usable pair — 55 %
recall costs 25 % false-positive rate. Treat it as one weak input to a fusion
decision, and re-validate on real audio before promoting it.

## Do not trust a report; measure

The pattern above held for 2 of 3 models checked. Before wiring any further
model, run it against real data first — wiring is a few hours, and wiring a
model that turns out to emit a constant is worse than not wiring it, because
the app then looks like it has a detector.

---

# Status: m1 is wired (Day 257)

The mel pipeline was implemented **in Dart**, not Kotlin —
`lib/data/services/mel_spectrogram.dart`, verified elementwise against
librosa by `test/mel_spectrogram_test.dart` (12 tests, including the
parity check). `lib/data/services/scream_detector_v2.dart` owns the
conversion from raw PCM to the `[1,128,131,1]` tensor and runs the
model; it is loaded by `ModelBundleService`, `DCSInferenceEngine`, and
`realInterpreterProvider`.

Doing it in Dart means one implementation to keep in parity with librosa
instead of one per platform, and the parity test runs in normal CI
rather than needing an instrumented Android run.

## Capture is fixed (Day 258)

`AudioCaptureService.kt` now requests **22,050 Hz** and maintains a rolling
**3-second** window with a 1-second hop, emitted as raw int16 on
`com.zapsafe/audio.pcm`. Three details are load-bearing:

1. **The window is filled before the Hann taper.** The legacy 450 ms MFCC path
   applies a Hann window in place to the same buffer. `MelSpectrogram` applies
   its own periodic Hann per STFT frame, so shipping tapered samples would
   window the signal twice — right shape, wrong numbers.
2. **The window is not VAD-gated.** Dropping quiet stretches would splice
   together samples that were never adjacent in time.
3. **The capture rate is reported, not assumed.** `AudioRecord` may refuse
   22,050 Hz; the fallback is 44,100 Hz and the actual rate ships with every
   window as `sr`. `audio_resampler.dart` converts to 22,050 Hz — a port of
   `scipy.signal.resample_poly`, parity-tested tap-for-tap against scipy
   (`test/audio_resampler_test.dart`). Naive decimation would alias 17 kHz
   content down to ~5 kHz, straight into the band a scream occupies.

`MfccExtractor` derives its sample rate from `AudioCaptureService`, so the
legacy path follows automatically — but its Nyquist moved from 8 kHz to
11.025 kHz, widening the 26-bin filterbank. The heuristic gates are in
physical Hz so they stay meaningful, but they were tuned at 16 kHz and are
worth re-checking.

## m2_motion_v2 is wired (Day 258)

`SensorChannelHandler.kt` emitted a **synthetic 10 Hz sine wave** until now.
It reads real `TYPE_ACCELEROMETER` + `TYPE_GYROSCOPE` at ~50 Hz, fusing the
latest gyro reading into each accelerometer event.
`MotionWindowBuffer` collects 100 samples (2 s) with a 25-sample hop;
`MotionDetectorV2` standardises by the fixed per-channel constants from
`m2_motion_v2_report.json` and runs the model.

Use `TYPE_ACCELEROMETER`, **not** `TYPE_LINEAR_ACCELERATION`: the fitted
`norm_mean[1] = 7.61` is only consistent with gravity being present. Removing
gravity shifts that channel by ~9.8, about one standard deviation, silently.

Skipping the standardisation is the silent failure here. Measured on a real
UCI-HAR window with an injected fall: **0.980 normalised, 0.000 raw.** The
detector simply never fires.

The table below records what the native side used to do.

# The original blocker: the native pipeline cannot feed these models

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

Steps 3-5 below are now done in Dart (see Status above). Steps 1-2 are
the remaining native work:

1. Capture (or resample) at 22,050 Hz — **outstanding**
2. Buffer a rolling 3-second window instead of 450 ms — **outstanding**
3. ~~STFT with n_fft=2048, hop=512, centred, producing 131 frames~~ done
4. ~~A **128-band mel filterbank matching librosa's**~~ done — note
   librosa defaults to the Slaney scale and `norm='slaney'`; an HTK-style
   filterbank will produce plausible-looking output that the model
   scores wrongly
5. ~~`power_to_db(ref=max)` then per-clip min-max normalisation~~ done

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

---

# Remaining models — measured tensor shapes (Day 258)

Read off the real `.tflite` files in
`kaggle_notebooks/day108_int4_m9_push/.../tflite_staging/`. **None of these
share m1's geometry**, so `mel_spectrogram.dart` is reusable only for the mel
computation itself — every one needs its own resize / channel / window step.

| model | input | notes |
|---|---|---|
| `m_glass_breaking` | `[1,96,96,3]` int8 | mel resized to 96x96, 3 channels |
| `n_breathing_distress` | `[1,96,96,3]` f32 | same family |
| `m4_vocal_stress_en` | `[1,96,96,3]` int8 | same family |
| `m5_vocal_stress_apac` | `[1,96,96,3]` int8 | same family |
| `j_whisper_distress` | `[1,96,96,3]` int8 | same family |
| `mg_gunshot` | `[1,128,128,3]` int8 | mel resized to 128x128 |
| `i_vehicle_crash` | `[1,64,64,3]` int8 | mel resized to 64x64 |
| `m1_scream_b` / `_adversarial` | `[1,128,87,3]` f32 | the day82 lineage: **1.0 s** audio, mel resized to 128x87, 3 identical channels, min-max `1e-8` |
| `m2_motion_b`, `m2_motion_adversarial`, `o_running_fleeing`(+f32) | `[1,128,6]` (single input) | **128** IMU samples, not the 100 m2_motion_v2 uses. Confirmed single-input via `interpreter.get_input_details()` on Day 260B — no hidden second input for these three. |
| `k_confinement`, `k_best` | **two inputs**: `serving_default_imu:0 [1,128,6]` **and** `serving_default_light:0 [1,32,1]` | NOT a single-input model — corrected Day 260, see `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 3. `light` is a broadcast ambient-light scalar (0.0=dark/confinement, 0.85-0.9=normal lit), per `day92_k_confinement.py`. Feeding only `imu` leaves `light` as allocator garbage, not an error. |
| `s_crowd_panic_a/b/c/d`, `s_best` (+f32 variants) | **two inputs**: `serving_default_imu:0 [1,128,6]` **and** `serving_default_mel:0 [1,64,64,1]` | NOT a single-input model — corrected Day 260B, see `DAY260B_HIDDEN_INPUT_CHECK.md`. `mel` is a real 64x64 audio mel-spectrogram (2.0s @16kHz, n_mels=64, fmax=8000, power_to_db, no further normalisation), a genuine second real-data modality per `day95_s_crowd_panic.py` / `day102_s_sweep.py` — not a constant, so there is no single "physically correct" value to broadcast; every real inference needs a real, time-matched audio clip alongside the IMU window. |
| `m3_scene_adversarial`, `m3_lighting_augmented` | `[1,128,128,3]` f32 -> `[1,3]` | 3-class, unlike shipped m3's `[1,224,224,3]` uint8 -> `[1,1]` |
| `m8_blink_liveness` | `[1,24,12]` f32 | 24 frames x 12 landmark features — needs a face-landmark path |
| `m7_nlp_context_enhanced` | `[1,64]` **int32** | token IDs; needs the training tokenizer + vocab, which is not in the staging dir |
| `h_aggressive_speech_crosslang` | `[1,38]` f32 | 38 prosodic features |
| `w_*_fusion` (6 heads) | `[1,4]` f32 | take 4 upstream model scores; only useful once their inputs are trustworthy |
| `m9_dcs_fusion_v0` | `[1,28]` f32 | **do not ship** — `production_pass: false` |

Two families dominate (`96x96x3` and `128x6`), so recovering those two
preprocessing paths unlocks most of the list.

**Validate before wiring.** Of the three models measured against real data so
far, two did not match their reports. The cost order is: measuring a model
against real audio is minutes, wiring one is hours. Do the cheap step first —
`scripts/` has no harness for this yet, but the Python in this session's
transcript is a starting point.

---

# Day 259 — full real-data triage of the remaining staged models

**This section is a point-in-time snapshot, since superseded — see the
"Current status (Day 265)" callout at the top of this file for what's
actually wired today. Several models below (`mg_gunshot`, `s_crowd_panic`,
`m_glass_breaking`) were re-tested and, in two cases, fixed and shipped
after this section was written — do not treat "0 of 20 pass" as current.**

Ran every model whose training config could be recovered against real,
labelled data (`DS07_AudioSet/train_wav`, `DS21_ESC-50`, `DS11_UCI-HAR`).
Harness: for each model, decode its own family's recovered preprocessing,
score ~60 real positive + ~60 real negative clips, and report AUC, score
std-dev, and an automatic constant-output flag (std < 1e-4).

**Result: 0 of 20 additional models pass. Nothing new was wired.**

| model | family | AUC | score std | verdict |
|---|---|---|---|---|
| `j_whisper_distress_bn_ur_ar_crosslang` | 96x96 mel (day101) | 0.613 | 0.214 | recall 64% costs FPR 52% — no usable threshold |
| `j_whisper_distress_adversarial_f32` | 96x96 mel | 0.437 | 0.141 | **worse than chance** |
| `m4_vocal_stress_en_adversarial` | 96x96 mel | 0.667 | 0.013 | pos/neg medians **identical** — quantisation noise, not signal |
| `m5_vocal_stress_apac_adversarial` | 96x96 mel | 0.667 | 0.018 | same — medians identical |
| `n_breathing_distress` | 96x96 mel | 0.703 | 0.088 | genuine signal but 0% recall at 0.5 (needs threshold ~0.35) — UNSURE, not chased further |
| `n_breathing_distress_f32` | 96x96 mel | 0.659 | 0.091 | same family, weaker |
| `m_glass_breaking` | 96x96 mel (own config) | 0.500 | **0.0** | **exactly constant** — ⚠️ **RECONCILED on Day 260C: reproduces closely on real AudioSet glass/shatter/smash audio (AUC 0.37-0.47, int8 medians identical); model is fine on ESC-50 (in-distribution) only — see `DAY260C_HARNESS_RECONCILIATION.md`** |
| `m_best` | 96x96 mel | 0.500 | **0.0** | **exactly constant** (identical to above) — same Day 260C reconciliation applies |
| `mg_gunshot` | 128x128 mel | 0.500 | **0.0** | **exactly constant** |
| `mg_gunshot_f32` | 128x128 mel | 0.373 | 0.022 | worse than chance |
| `i_vehicle_crash` | 64x64 mel | 0.408 | 0.0019 | worse than chance, near-constant |
| `i_vehicle_crash_f32` | 64x64 mel | 0.753 | **2.9e-6** | AUC looks fine; std is 6-decimal-place noise — **constant in practice** |
| `k_confinement`, `k_best` | IMU [1,128,6] | — | **0.0** | **exactly constant** on real UCI-HAR — ⚠️ **measured with an undocumented second input (`light`) left unset; see Day 260 correction below, verdict does not hold as originally stated** |
| `o_running_fleeing`(+f32) | IMU [1,128,6] | — | 0 on fall-injected | responds to real walking data (std 0.18) but **collapses to exactly 0** the instant a real fall is injected — wrong-direction, unusable — ⚠️ **single-input confirmed (no hidden input) on Day 260B; RECONCILED on Day 260C: reproduces almost exactly on real SisFall fall-impact data, while the model's own panic-running augmentation correctly moves the score up — model detects panic running, not falls, so near-zero on real falls is arguably in-spec, not a defect — see `DAY260C_HARNESS_RECONCILIATION.md`** |
| `s_crowd_panic_a`, `s_best` | IMU [1,128,6] | — | 0.001–0.003 | noise-floor variance; fall injection moves score the **wrong way** — ⚠️ **measured with an undocumented second input (`mel`, a real audio spectrogram) left unset; see Day 260B correction below — direction verdict CONFIRMED with both inputs correct, but the std/"noise-floor" figure was wrong (real std is 0.04–0.10, not 0.001–0.003)** |
| `m2_motion_b`, `m2_motion_adversarial` | IMU [1,128,6] | — | **0.0** | **exactly constant** — confirmed single-input (no hidden input) on Day 260B; verdict itself not retested |

Every one of these was checked against its **own recovered training
config** (see per-family constants below), not a guess — the failure is in
the model, not the preprocessing.

## Why so many are constant

Three of the four exactly-constant image models (`m_glass_breaking`,
`m_best`, `mg_gunshot`) and all three exactly-constant IMU models
(`k_confinement`, `k_best`, `m2_motion_b`, `m2_motion_adversarial`) are
int8-quantised. A plausible mechanism: post-training quantisation collapsed
already-marginal logits into a single output bucket. This is exactly the
`m1_pocket_muffled` failure mode from Day 258, now confirmed across 7 more
models — quantisation does not merely lose precision here, it can erase the
signal entirely while the file still loads, runs, and returns a
plausible-looking `[0,1]` float.

**Correction (Day 260 / Day 260B — see `DAY260_QUANTIZATION_ROOTCAUSE.md`
and `DAY260B_HIDDEN_INPUT_CHECK.md`):** this "int8-quantisation collapse"
explanation does not hold up for every model in this list.
`m2_motion_b`/`m2_motion_adversarial` are, per real
`interpreter.get_input_details()`, **not int8-quantised at all** — both are
plain float32 tflite files. And `k_confinement`/`k_best`'s "exactly
constant" result and `s_crowd_panic_a`/`s_best`'s "wrong-direction, noise-
floor variance" result were both measured with an **undocumented second
input left unset** (TFLite silently fills it with allocator garbage rather
than erroring) — `k_confinement` needs `light [1,32,1]`,
`s_crowd_panic_*` needs `mel [1,64,64,1]`. With both inputs set correctly:
`k_confinement` turns out to be real and non-degenerate but almost entirely
light-gated (not a quantisation bug); `s_crowd_panic_*`'s wrong-direction
verdict is **confirmed** even with the real second input supplied (so that
one *is* a genuine model problem, just not a "noise-floor"-sized one — real
std is 0.04–0.10, and the direction is wrong in both fp32 and int8, so
quantisation isn't the cause there either). `o_running_fleeing` was
confirmed to have no hidden input at all, and its "wrong-direction, collapses
to 0" result did not reproduce with real UCI-HAR data and the model's own
panic-augmentation function — still unexplained, not resolved. Bottom line:
treat the "why so many are constant" narrative above as **superseded** for
`m2_motion_b`, `m2_motion_adversarial`, `k_confinement`, `k_best`,
`o_running_fleeing`, `s_crowd_panic_a`, `s_best` specifically — re-read the
two follow-up docs before making any retrain/retire call on these seven.

**Further correction (Day 260C — see
`DAY260C_HARNESS_RECONCILIATION.md`):** the `m_glass_breaking`/`m_best`
ESC-50 discrepancy (Finding 1 in `DAY260_QUANTIZATION_ROOTCAUSE.md`) and the
`o_running_fleeing` discrepancy above are both now reconciled with real data,
and **neither indicates a bug in Day 259's harness.** Real AudioSet
glass/shatter/smash audio reproduces Day 259's near-constant, at-or-below-
chance verdict for `m_glass_breaking`/`m_best` (the model is good in-domain
on ESC-50, not out-of-domain). Real SisFall fall-impact IMU data reproduces
Day 259's "collapses to exactly 0" verdict for `o_running_fleeing` almost
exactly (the model was trained to detect panic running, not falls, and
correctly outputs near-zero on a real physical event it was never trained
to recognize as positive). **Blast radius: Day 259's other 18 verdicts
should be treated as trustworthy** — the pattern found was "harder/
differently-labelled real data reproduces Day 259," not "Day 259's harness
was broken." The only two models with a confirmed harness-side bug remain
`k_confinement`/`k_best` and `s_crowd_panic_a`/`s_best` (undocumented second
input), already corrected above. `m2_motion_b`/`m2_motion_adversarial`
remain the one genuinely open item — never retested against any real data
at all — see `DAY260C_HARNESS_RECONCILIATION.md`'s "what should be
re-tested next" section.

## Recovered per-family configs (for next time)

```
day101_common (96x96x3):  sr=16000  duration=3.0s  n_mels=96  n_fft=2048
                           hop=512  fmax=4000  minmax 1e-8
                           -> j_whisper_distress*, m4_vocal_stress_en*,
                              m5_vocal_stress_apac*, n_breathing_distress*

glass_breaking (96x96x3):  sr=16000  duration=2.0s  n_mels=96  fmax=8000
                           minmax 1e-8   (day93_m_glass_breaking.py — own
                           config, NOT the day101 family despite same shape)

gunshot (128x128x3):       sr=16000  duration=3.0s  n_mels=128  fmax=8000
                           minmax 1e-8   (day89_mg_gunshot.py)

vehicle_crash (64x64x3):   sr=16000  duration=2.0s  n_mels=64  fmax=8000
                           minmax 1e-8   (day91_i_vehicle_crash.py)

IMU o/k/s family:          day102_sweep_common.run_imu_sweep applies
                           NO normalisation — raw physical units straight
                           to the model (unlike m2_motion_v2's fixed
                           mean/std). Positive-class labels for k/o/s are
                           partly synthetic bootstrap, not recorded real
                           events — a second, independent reason these
                           would need care even if the constant-output
                           problem were fixed.
```

## Untested, not bad — logged rather than debugged today

- `m3_scene_adversarial`, `m3_lighting_augmented` — no labelled real image
  dataset staged for safe/unsafe scenes.
- `m8_blink_liveness` [1,24,12] — needs a face-landmark extraction pipeline
  that doesn't exist.
- `m7_nlp_context_enhanced` [1,64] int32 — tokenizer/vocab absent from
  staging; unwireable regardless of accuracy.
- `h_aggressive_speech_bn_ur_ar_crosslang` [1,38] — 38 hand-engineered
  prosodic features, a third preprocessing family; not attempted today.
- `w_*_fusion` (6 heads, `[1,4]`) — take 4 upstream model scores as input.
  Not worth testing until upstream models exist that are worth fusing.
- `m9_dcs_fusion` — do not ship (`production_pass: false`).

## Bottom line

`m1_scream_v2` and `m2_motion_v2` remain the only two models wired to this
app, and now the only two connected to the backend
(`POST /api/v1/ml/detection-events/` — see
`ml/test_day259_live_detection_wiring.py` in the backend repo for a real
request/response/DB-row proof). Every other staged model either failed
today's real-data check or could not be checked with data available
locally. Wiring any of them without retraining would mean shipping a
detector that structurally cannot detect anything.
