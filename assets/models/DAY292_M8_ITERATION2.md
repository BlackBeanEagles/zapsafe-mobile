# Day 292 — m8_blink_liveness iteration 2: fixing the real MediaPipe problem

Follow-up to `DAY290_M8_BLINK_LIVENESS.md`, which built a real extraction +
training pipeline over the MIT-licensed `hlly34/liveness-detection-zalo-2022`
video corpus (1168 labeled real-vs-replay-attack `.mp4` videos) but fell back
to a coarse OpenCV Haar-cascade eye-openness proxy after MediaPipe FaceMesh
appeared to die silently on Kaggle's CPU image across two pushes. Real
result there: **AUC 0.5829** — diagnosed as an extractor-quality problem
(Haar cascade too coarse to separate real blinks from replay-attack video of
a real face blinking).

This session (Day 292) attacks that specific diagnosed weakness: get a real
landmark-based extractor working, not another workaround.

## 1. Real diagnosis first (before writing any pipeline code)

A small diagnostic kernel
(`kaggle_notebooks/day292_mediapipe_diag/diag.py`, kernel
`hridyajain/zapsafe-day292-mediapipe-diag`) was pushed to Kaggle **3 separate
times**, each testing a real hypothesis about why MediaPipe failed on Day
290, and each capturing the actual subprocess stdout/stderr/returncode
(deliberately running MediaPipe in a child subprocess from the diagnostic
script so a genuine native crash can't kill the whole kernel and hide the
evidence, per Day 290's own suggested next step):

**Run 1** — plain `pip install mediapipe` (what Day 290 effectively did):
```
MEDIAPIPE_VERSION 1.0.0
AttributeError: module 'mediapipe' has no attribute 'solutions'
```
Real finding: today's `pip install mediapipe` resolves to **mediapipe
1.0.0**, which removed the legacy `mediapipe.solutions.face_mesh` API Day
98/290's code was written against. This was **never a native crash** — it's
a clean, catchable Python `AttributeError`. Day 290's script just never
wrapped the `FaceMesh(...)` construction itself in a try/except (only
per-frame `.process()` calls), and Kaggle's kernel-log buffering made the
real traceback look like a silent death.

**Run 2** — try pinning older mediapipe versions to get the legacy API back
(`0.10.14`, `0.10.21`) plus the new Tasks API on `1.0.0`:
```
mediapipe==0.10.14 -> ImportError: cannot import name 'runtime_version'
                       from 'google.protobuf'
mediapipe==0.10.21 -> same ImportError
mediapipe==1.0.0 Tasks API (FaceLandmarker) -> CHILD_EXCEPTION (protobuf,
                       same root cause)
```
Real finding #2: `mediapipe/__init__.py` unconditionally imports
`mediapipe.tasks.python`, which pulls in TensorFlow's docs tooling, which
needs `google.protobuf.runtime_version` — a symbol that only exists in
protobuf ≥ 4.25. Kaggle's preinstalled TensorFlow stack keeps an older
protobuf around. Explicitly pinning `protobuf==3.20.3` alongside mediapipe
hits a hard `ResolutionImpossible` (pip won't even install it) — so the
legacy-API route is dead on this image regardless of mediapipe version.

**Run 3** — install mediapipe, then **force-reinstall a newer protobuf on
top** (`pip install --force-reinstall --no-deps "protobuf>=5,<7"`), overriding
the stale protobuf mediapipe's own resolver leaves in place:
```
mediapipe==0.10.21 + protobuf>=4.25,<5 forced -> still ImportError (0.10.21's
     tasks-import chain needs a protobuf newer than what got force-installed
     here; not pursued further once run below succeeded)
mediapipe==1.0.0 (Tasks API, FaceLandmarker) + protobuf>=5,<7 forced ->
     MEDIAPIPE_VERSION 1.0.0
     DETECT_OK True
     CHILD_SUCCESS
```
**Real fix confirmed**: `pip install mediapipe==1.0.0` followed by
`pip install --force-reinstall --no-deps "protobuf>=5,<7"`, then use the
modern **Tasks API** (`mediapipe.tasks.python.vision.FaceLandmarker`)
instead of the removed legacy `solutions.face_mesh` API. A real
`FaceLandmarker.detect()` call succeeded in-process, no crash, no exception.

**Conclusion: Day 290's diagnosis was wrong.** MediaPipe was never
incompatible with this Kaggle CPU image — it was a fixable
dependency/API-version mismatch (mediapipe 1.0.0 dropping the legacy API +
a stale protobuf pip's resolver leaves behind), not a native runtime
failure.

## 2. Real extractor rewrite

`kaggle_notebooks/day292_m8_zalo_liveness_mediapipe/day292_m8_zalo_liveness.py`
is Day 290's script with **only the extractor swapped** — same dataset, same
labels, same `[24, 12]` input contract, same BiLSTM(48) architecture, same
train/val split (`random_state=42`), same acceptance bar — so any AUC delta
is attributable to extractor quality alone, per the task brief.

`frame_to_features()` now uses genuine MediaPipe `FaceLandmarker` output
(478-point face mesh) to compute:
- **Real 6-point EAR** per eye (`ear_left`, `ear_right`), using the same
  canonical MediaPipe eye-contour landmark indices MediaPipe's own EAR
  examples use (`(362, 385, 387, 263, 373, 380)` left, `(33, 160, 158, 133,
  153, 144)` right) — a continuous geometric ratio, not a Haar-cascade
  detection-success proxy.
- **Real z-depth** (`eye_z_l`, `eye_z_r`) directly from the landmark model's
  own depth output — Day 290's Haar pipeline had to hardcode these to `0.0`
  since no depth estimate is available without a landmark model. This is the
  concrete "richer signal" a real landmark extractor provides over Haar
  cascades.
- `mouth_ratio` from real mouth-corner/lip landmark distances (not a texture
  std-dev proxy), `nose_y`/`brow_y`/`cheek_asym`/`face_w_ratio` from real
  landmark y/x positions.

A pre-flight smoke test (`ZAPSAFE_M8_MAX_VIDEOS=20`, kernel
`hridyajain/zapsafe-day292-m8-smoke`) was run **before** committing to the
full 1168-video extraction, to catch bugs cheaply: it caught one real bug
(a local `import mediapipe as mp` inside `frame_to_features` running before
`_get_landmarker()`'s pip-install step, raising `ModuleNotFoundError` on the
very first call) and confirmed **20/20 videos extracted successfully** with
no crash once fixed.

## 3. Real spot-check — signal quality, before training

Comparing the same kind of spot-check Day 290 logged, live-labeled sequences
from the **real Day 292 Kaggle run**:

```
2.mp4:  ear_avg min=0.0726 max=0.1954 range=0.1228
3.mp4:  ear_avg min=0.0454 max=0.2097 range=0.1643
7.mp4:  ear_avg min=0.1509 max=0.1859 range=0.0350
8.mp4:  ear_avg min=0.1758 max=0.2115 range=0.0356
11.mp4: ear_avg min=0.1327 max=0.1687 range=0.0360
```

versus Day 290's Haar-cascade values on (mostly) the same live sequences:
```
2.mp4:  min=0.0000 max=0.5000 range=0.5000
3.mp4:  min=0.0000 max=1.0000 range=1.0000
8.mp4:  min=1.0000 max=1.0000 range=0.0000
11.mp4: min=0.0000 max=1.0000 range=1.0000
```

This is a real, qualitative confirmation of the hypothesis the task brief
was built on: Day 290's values are discrete (`{0.0, 0.35, 0.65, 1.0}` from
the 3-strip openness heuristic, clustering at the extremes) with erratic
full-range 0-to-1 jumps within a single short clip — consistent with a
coarse, unstable proxy, not a smooth physiological signal. Day 292's values
are **continuous, small-range (0.04–0.21), and vary smoothly** — the actual
shape a real geometric eye-aspect-ratio should have across a short video
with normal blink dynamics.

**Extraction yield also improved**: **1160/1168 usable (99.3%)**, vs Day
290's 950/1168 (81.3%). A real landmark model is more robust to the exact
conditions (low light, off-angle, low-res replay recordings) where the
Haar-cascade face/eye detectors were failing most often.

## 4. Real training result

Kaggle kernel `hridyajain/zapsafe-day292-m8-mediapipe-retrain` (CPU, run to
real completion, `status: complete`, ~31 minutes wall time — notably
*faster* than Day 290's ~85 minutes, since MediaPipe's single-pass
FaceLandmarker call replaced Day 290's multi-strip Haar-cascade retry loop
per frame).

- Train/val split: 986 / 174 (stratified, `random_state=42`, on the larger
  1160-usable-video pool).
- **AUC = 0.7186, Accuracy = 0.6552, F1 = 0.6552, Precision = 0.6706,
  Recall = 0.6404.**
- Acceptance target (`f1 >= 0.85`, inherited from Day 98/290's own bar):
  **still NOT MET.**

**Comparison to Day 290's real baseline:**

| metric | Day 290 (Haar cascade) | Day 292 (MediaPipe FaceLandmarker) | delta |
|---|---|---|---|
| AUC | 0.5829 | 0.7186 | **+0.1357** |
| F1 | 0.5833 | 0.6552 | **+0.0719** |
| Accuracy | 0.5804 | 0.6552 | **+0.0748** |
| Extraction yield | 950/1168 (81.3%) | 1160/1168 (99.3%) | **+18.0 pts** |
| Wall time | ~85 min | ~31 min | faster |

This is **real, substantial progress**, not a wash and not full success. AUC
moved from "barely above chance" (0.58) to "meaningfully better than chance,
real discriminative signal" (0.72) — confirming the Day 290 diagnosis was
correct in substance (the Haar-cascade extractor was the bottleneck) even
though its explanation for *why* MediaPipe wasn't available was wrong. The
0.85 F1 acceptance bar (inherited from Day 98, itself trained on synthetic
data and never validated against real replay-attack video) is still not
met — closing that final gap likely needs either more training data
diversity, temporal augmentation, or a materially different architecture,
not another extractor swap; the extractor-quality lever identified in Day
290 has now been mostly pulled.

## 5. Verdict

**Real, measured iteration-2 improvement over Day 290's documented weakness.**

- The Day 290 diagnosis ("MediaPipe crashes natively, use Haar cascade") is
  corrected: MediaPipe was fixable (mediapipe 1.0.0 + forced protobuf
  upgrade + the modern Tasks API), and using it delivers exactly the kind
  of improvement the diagnosis predicted (AUC 0.583 → 0.719).
- Model quality: still **not acceptance-grade** (F1 0.655 vs 0.85 target).
  Real, honest number — not adjusted or rounded up.
- **This model was NOT wired into the app.** No detector/wiring,
  `.tflite`/pubspec/backend files touched, per task instruction. Day 290's
  own finding — `zapsafe_mobile` has **no camera/face-capture pipeline at
  all** (`camera` package not active, no Dart file references
  blink/liveness/EAR/face_mesh in implementation) — was not re-verified in
  this session (out of scope per instruction) but nothing in this session
  changes that finding; it still applies.

## Files touched this session

- `assets/models/DAY292_M8_ITERATION2.md` (this file) — new, in
  `zapsafe_mobile`, on branch `day292-m8-iteration2` (worktree off `main`).
- No detector/wiring files, `.tflite` files under `assets/models/`,
  `pubspec.yaml`, or backend code touched.
- Companion changes in the separate `kaggle_notebooks` repo (not this repo),
  same branch name `day292-m8-iteration2`:
  - `kaggle_notebooks/day292_mediapipe_diag/` — diagnostic script + metadata
    (real root-cause investigation, 3 real Kaggle kernel runs).
  - `kaggle_notebooks/day292_m8_zalo_liveness_mediapipe/` — retrain script,
    kernel-metadata.json, and pulled real Kaggle output (training log,
    report, norm JSON, `.tflite`/`.h5` files per repo convention — the
    `.tflite`/`.h5` binaries themselves stay gitignored, matching every
    prior day's convention in that repo).
