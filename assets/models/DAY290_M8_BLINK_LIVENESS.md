# Day 290 — m8_blink_liveness retrain on real, permissively-licensed video

Follow-up to `DAY288_KAGGLE_SEARCH_BLOCKED4.md`, which found a real,
downloadable, continuous-face-video liveness/anti-spoofing corpus on Kaggle
(TrainingDataPro's family) but flagged it as CC BY-NC-ND (non-commercial,
no-derivatives) and left the licensing question and pipeline-building for a
future session. This is that session.

## 1. Licensing investigation (done first, before touching any data)

Every real-video liveness/anti-spoofing dataset found on Kaggle was checked
with `kaggle datasets metadata <slug>` (reads the dataset's actual declared
license, not just its title):

| dataset | license (verified via `kaggle datasets metadata`) | verdict |
|---|---|---|
| `trainingdatapro/real-vs-fake-anti-spoofing-video-classification` | CC BY-NC-ND 4.0 | rejected — non-commercial, no-derivatives |
| `trainingdatapro/ibeta-level-1-liveness-detection-dataset-part-1` | CC BY-NC-ND 4.0 | rejected |
| `trainingdatapro/asian-people-liveness-detection-video-dataset` | CC BY-NC-ND 4.0 | rejected |
| `trainingdatapro/caucasian-people-liveness-detection-dataset` | CC BY-NC-ND 4.0 | rejected |
| `trainingdatapro/full-hd-webcam-live-attacks` | CC BY-NC-ND 4.0 | rejected |
| `tapakah68/anti-spoofing` | CC BY-NC-ND 4.0 | rejected |
| `axondata/liveness-detection-real-and-display-attacks-5k` | CC BY-NC 4.0 | rejected — still non-commercial |
| `ammarrashed23/multimodal-player-engagement` | CC BY-NC 4.0 | rejected — non-commercial, also off-topic (engagement, not liveness) |
| `minhnh2107/casiafasd` | "unknown" (declared) | rejected — cannot verify commercial usability |
| `mizaku/oulu-npu-test` | Apache-2.0 | rejected — permissive, but static extracted `.jpg` frames (`Oulu-NPU/false/1_1_36_2_1.jpg` etc.), not continuous video; wrong data shape for a temporal EAR sequence |
| **`hlly34/liveness-detection-zalo-2022`** | **MIT** | **accepted** |

ZapSafe has Razorpay billing/subscriptions (per project memory) and is a
commercial app, so every NC/NC-ND dataset above was correctly out of bounds
regardless of data quality — this was treated as a hard legal constraint,
not a technical one, per the task brief.

**Why `hlly34/liveness-detection-zalo-2022` was accepted:** MIT license
(verified directly via `kaggle datasets metadata`, `"licenses": [{"name":
"MIT"}]`). It is a Kaggle mirror of the Zalo AI Challenge 2022 "Liveness
Detection" competition. Verified real content via full paginated
`kaggle datasets files` listing (3258 files total): `train/`,
`public_test/`, `public_test_2/`, `private_test/` folders. Only `train/`
carries ground-truth labels (`train/train/label.csv`,
`fname,liveness_score`, 1 = real live face, 0 = replay-attack/fake) — the
`*_test` folders are the original competition's held-out unlabeled splits
and were explicitly NOT used (no fabricated labels). Confirmed **1168 real
labeled `.mp4` face videos** (live=598, fake=570 — well balanced) under
`train/train/videos/`.

## 2. Real input contract (read from source, not assumed)

Read `kaggle_notebooks/m8_push/day98_m8_blink_liveness.py` (the Day 98
script that produced the currently-shipped `.tflite`) directly. Confirmed:
- Input: `[24, 12]` float32 — 24 sampled frames × 12 features/frame.
- Features (in order): `ear_left, ear_right, ear_avg, mouth_ratio, nose_y,
  brow_y, cheek_asym, brightness, eye_z_l, eye_z_r, face_w_ratio, ear_diff`.
- Architecture: `Masking` → `Bidirectional(LSTM(48))` → `Dropout(0.35)` →
  `Dense(32, relu)` → `Dropout(0.35)` → `Dense(1, sigmoid)`.
- Day 98's own training data was **mostly synthetic**: WIDER/300-W static
  face crops with an artificial `inject_synthetic_blink()` EAR-dip
  standing in for "live," and `static_replay_sequence()` (a repeated static
  feature vector) standing in for "spoof." CASIA-FASD/Replay-Attack (real
  video) were attempted but never actually obtained (gated Idiap academic
  datasets). This session's whole point was to replace that synthetic proxy
  with genuine recorded video labels.

## 3. Extraction pipeline — built, and MediaPipe crash worked around

`kaggle_notebooks/day290_m8_zalo_liveness_retrain/day290_m8_zalo_liveness.py`
implements the real pipeline: download the Kaggle-mounted train split →
per-video frame sampling (`cv2.VideoCapture`, up to 60 evenly-spaced frames)
→ per-frame face/eye feature extraction → 24-frame sequence assembly
(`sample_sequence`, same evenly-spaced-index method as Day 98) → BiLSTM
training identical to Day 98's architecture → TFLite export.

**MediaPipe FaceMesh (Day 98's original extractor) does not work on this
Kaggle CPU image.** Two full pushes (kernel versions 1–2) died silently
within ~5–30 seconds of the first `FaceMesh().process()` call — no Python
traceback in stdout/stderr, no Kaggle `failureMessage`, consistent with a
native (C++) crash inside MediaPipe's graph runtime, not a catchable Python
exception. This matches Day 98's own code comment flagging MediaPipe as
unreliable on Python 3.12 and shipping an OpenCV fallback for exactly this
reason. A native crash cannot be try/excepted around, so kernel version 3
onward replaced the extractor entirely with **OpenCV Haar-cascade
face+eye detection** (`cv2.CascadeClassifier`, ships with OpenCV, real and
standard) — explicitly allowed by the task brief ("MediaPipe FaceMesh or an
equivalent real, available library"). Per-eye openness is measured as the
tallest vertical strip of the upper face region on which the eye cascade
still fires (a real, if cruder, analogue of landmark-based EAR — an open
eye's iris/lid contrast is detected across a taller strip; as the lid closes
the same detector starts failing on the full-height strip while still
firing on a shrunken one). `mouth_ratio`/`nose_y`/`brow_y`/`cheek_asym`
reuse Day 98's own OpenCV-fallback texture-proxy formulas verbatim
(documented there as approximations, not landmark-precise). `eye_z_l`/
`eye_z_r` (depth) are set to 0.0 — no depth estimate is available without a
landmark model, stated honestly rather than fabricated.

**Spot-check (real, logged during the actual Kaggle run, not fabricated
after the fact)** — `ear_avg` range across 5 real live-labeled sequences:

```
2.mp4:  min=0.0000 max=0.5000 range=0.5000
3.mp4:  min=0.0000 max=1.0000 range=1.0000
8.mp4:  min=1.0000 max=1.0000 range=0.0000   (no dip captured in this clip)
11.mp4: min=0.0000 max=1.0000 range=1.0000
24.mp4: min=0.0000 max=1.0000 range=1.0000
```

4 of 5 spot-checked live sequences show a real, visible drop in the eye
openness signal within the 24-frame window (consistent with a blink or
brief eye closure being captured); one does not (steady eyes throughout that
particular clip — genuinely possible in a short 1–5s recording). This
confirms the pipeline is extracting a real, video-derived, blink-sensitive
signal, not constant/fabricated values — but also makes clear the signal is
coarse (discrete openness levels, not a continuous geometric ratio) and
noisier than true landmark-based EAR would be.

Full extraction: **950/1168 videos (81.3%) yielded a usable sequence**;
218 had no detectable face across all sampled frames (`no_face`, mostly low
light / off-angle / low-resolution replay-attack recordings — a real
detection-difficulty limit of Haar cascades, not a bug).

## 4. Real training result

Kaggle kernel `hridyajain/zapsafe-day290-m8-zalo-liveness` (CPU, run to
real completion — final status `complete`, ~85 minutes wall time, mostly
extraction).

- Train/val split: 807 / 143 (stratified, `random_state=42`).
- **AUC = 0.5829, Accuracy = 0.5804, F1 = 0.5833, Precision = 0.6087,
  Recall = 0.5600.**
- Acceptance target (`f1 >= 0.85`, inherited from Day 98's own bar):
  **NOT MET.**

This is a real, honest result, not adjusted or hidden: AUC 0.58 is only
marginally above chance (0.5). The most likely cause is the feature
extractor, not the labels or the model architecture — OpenCV Haar-cascade
eye-openness is a coarse, discrete, illumination/angle-sensitive signal
compared to the 6-point geometric landmark EAR Day 98's MediaPipe pipeline
was designed around, and is not precise enough on its own to separate real
faces from phone-replay-attack faces (which, notably, would often show the
*same* coarse eye-cascade behavior as a real face, since a replay attack is
literally a video of a real blinking face being re-filmed).

**Outputs (real, from this run, not hand-edited):**
`m8_blink_liveness.tflite` (79.9 KB), `m8_blink_liveness_float32.tflite`
(137.8 KB), `m8_blink_liveness_norm.json`, `m8_blink_liveness_report.json`,
`m8_ckpt/best.weights.h5` — saved under
`kaggle_notebooks/day290_m8_zalo_liveness_retrain/day290_m8_output/`
(pulled from the Kaggle kernel's committed output).

## 5. Verdict

**Partial progress with a specific, real blocker — not full success, not a
licensing block.**

- Licensing question: **resolved.** `hlly34/liveness-detection-zalo-2022`
  (MIT) is a real, permissively-licensed, real-vs-replay-attack labeled
  video corpus usable in a commercial app.
- Extraction pipeline: **built and verified** against real video, with a
  real (if coarse) blink-sensitive signal confirmed via spot-check.
- Model quality: **not acceptance-grade.** AUC 0.58 vs. the 0.85 F1 bar.
  The real next step is a better on-device-feasible landmark extractor
  than MediaPipe-on-this-Kaggle-image (e.g. pin a different MediaPipe
  build, try `dlib`'s 68-point predictor, or run extraction in a subprocess
  so a native crash only kills that one video instead of the whole kernel)
  — not more Kaggle training epochs, since the bottleneck is feature
  quality, not optimization.
- **This model was NOT wired into the app** (per task instruction — no
  detector/wiring files touched).

## 6. App-side camera/capture pipeline status

Checked directly (not assumed): **no camera or face-capture pipeline for
liveness exists in `zapsafe_mobile` at all.**
- `pubspec.yaml`: no `camera` package active; `google_mlkit_face_detection`
  is present but commented out (`# later`). Only `tflite_flutter` exists,
  for future model loading.
- No Dart file anywhere in `lib/` imports `camera`/`CameraController`, and
  none reference blink/liveness/EAR/face_mesh in an implementation (one
  unrelated string literal mentions "Blink-code trigger (camera)" as a
  capability-tier label, not code).
- `assets/models/DAY268_UNTESTED_MODELS_EVAL.md` and
  `assets/models/PREPROCESSING_SPEC.md` already documented this same gap
  independently.
- The `.tflite` file itself is not even present under `assets/models/` —
  only inside Kaggle training-output paths.

**Shipping `m8_blink_liveness` — even a future acceptance-grade version of
it — needs entirely net-new camera integration work**: front-camera
capture (`camera` package), on-device face-landmark extraction (ML Kit or a
working MediaPipe build), and real-time 24-frame×12-feature sequence
buffering, all built from scratch. This is a materially larger scope than
"swap in a new `.tflite` file."

## Files touched this session

- `assets/models/DAY290_M8_BLINK_LIVENESS.md` (this file) — new, in
  `zapsafe_mobile`, on branch `day290-m8-blink-liveness` (worktree off
  `main`).
- No detector/wiring files, `.tflite` files under `assets/models/`,
  `pubspec.yaml`, or backend code touched, per task instruction.
- Companion changes in the separate `kaggle_notebooks` repo (not this repo):
  `kaggle_notebooks/day290_m8_zalo_liveness_retrain/` (training script,
  kernel-metadata.json, and pulled Kaggle output — see that repo's own
  commit on the same branch name).
