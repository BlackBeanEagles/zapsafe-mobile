# Day 289 — M3 danger-classifier real retrain on UCF-Crime

**Scope note (read this first):** this retrain targets **day84's
`m3_lighting_augmented` checkpoint** — the SAFE/NEUTRAL/RISKY 3-class,
`224x224x3` danger classifier trained via
`kaggle_notebooks/day84_m3_lighting_augmented.py` — **not**
`m3_scene_adversarial` (day103, `160x160x3`, binary camera-blocked
detector, `kaggle_notebooks/day103_adversarial_push/day103_m3_adversarial.py`).
Those are two different real checkpoints under the same `m3` name (confirmed
in `DAY268_UNTESTED_MODELS_EVAL.md`). Day103's model already trains fine on
its own synthetic-corruption pipeline and was not touched this session.

## Why UCF-Crime

Day84's danger classifier maps generic Places365 scene categories (office,
alley, parking_garage...) onto an invented SAFE/NEUTRAL/RISKY label via a
hand-written `DANGER_MAP` — a proxy with no ground truth ("is an alley
actually risky" is an assumption, not an annotation). `odins0n/ucf-crime-dataset`
(real Kaggle mirror of the academic UCF-Crime corpus, 11GB, verified via
`kaggle datasets files`) provides a native `NormalVideos` vs. 13-real-anomaly-
category split from real CCTV footage — both classes from the same camera
domain, a materially better-grounded label than the Places365 proxy.

## Real label mapping decided this session

Read directly off the actual folder names present in the dataset (verified
via a diagnostic Kaggle kernel, see "Real bugs found" below — the on-disk
class name is `NormalVideos`, not `Normal` as the Day288 doc assumed):

| UCF-Crime class | mapped to | reasoning |
|---|---|---|
| `NormalVideos` | SAFE (0) | native non-incident footage |
| `Abuse`, `Assault`, `Fighting`, `Robbery`, `Shooting` | RISKY (2) | direct interpersonal violence or armed threat to a bystander — the core "personal safety" scenario this model exists for |
| `Burglary`, `Arson`, `Explosion`, `Vandalism` | RISKY (2) | acute physical danger in the scene itself (fire, blast, forced intrusion) even without a visible confrontation |
| `Arrest` | NEUTRAL (1) | law enforcement is already present and controlling the scene — arguably safer, not riskier, than an unmonitored scene; not a "flee this scene" signal |
| `RoadAccidents` | NEUTRAL (1) | vehicle-domain hazard, already covered by the separate `i_vehicle_crash` model (`DAY271_VEHICLE_CRASH_WIRING.md`); including it here would duplicate/conflate two different downstream signals |
| `Shoplifting`, `Stealing` | NEUTRAL (1) | nonviolent property crime with no bystander threat — present in frame but not a "get away from this place" scene signal |

9 of 13 anomaly categories mapped to RISKY, 4 to NEUTRAL. This mirrors
day84's original rule of thumb ("RISKY = hard to call for help / immediate
danger, NEUTRAL = public but variable, SAFE = monitored/populated") applied
to real incident categories instead of an invented scene-type guess.

## Real dataset construction

- Source: `odins0n/ucf-crime-dataset`, real mount path
  `/kaggle/input/datasets/odins0n/ucf-crime-dataset/{Train,Test}/<class>/`
  (NOT `/kaggle/input/ucf-crime-dataset/...` — see bugs below), containing
  real extracted PNG frames per source video, e.g.
  `Test/Abuse/Abuse028_x264_0.png`.
- **Video-level split**, not frame-level: frames were grouped by source
  video ID (the filename prefix before the trailing frame index) and the
  70/15/15 train/val/test split was applied to *video IDs*, not individual
  frames. This matters because adjacent frames from the same video are
  near-duplicates — a frame-level split would let near-identical frames
  leak across train and test and inflate the reported accuracy. Confirmed
  in code (`day289_m3_ucf_crime.py`, `build_video_index` / per-class video
  shuffle-then-split).
- Sampled up to 40 frames/video and capped at 3,000 frames/class per split
  (9,000 train / 8,016 val / 8,123 test frames total) — full-resolution use
  of all ~1M `NormalVideos` frames alone was unnecessary and would have
  made a single Kaggle T4/P100 session impractical; this sample is balanced
  3-way by class weighting to match.
- Real class-video counts found on disk: `NormalVideos` 950 videos/
  1,012,720 frames; `RoadAccidents` 150/26,149; `Robbery` 150/42,328;
  `Stealing` 100/46,786; `Burglary` 100/47,161; all other classes 50 videos
  each (13k-33k frames).

## Real bugs found and fixed this session (documented so the next session doesn't repeat them)

1. **Wrong dataset mount path.** Assumed `/kaggle/input/ucf-crime-dataset/`;
   the real Kaggle-attached path (confirmed via a small diagnostic kernel,
   `hridyajain/zapsafe-day289-diag`, that walked `/kaggle/input`) is
   `/kaggle/input/datasets/odins0n/ucf-crime-dataset/`. First real training
   run found 0 classes and exited immediately.
2. **Wrong "Normal" class name.** The dataset's real folder is
   `NormalVideos`, not `Normal` as assumed from the DAY288 doc's
   description. First fixed run silently trained on only the NEUTRAL/RISKY
   classes (0 SAFE samples) without erroring — caught by inspecting the
   real per-class frame counts in the log, not by the run failing.
3. **Mid-`fit()` recompile crash.** The original plan (mirroring day84's
   script) was to unfreeze base layers inside a Keras callback partway
   through one `model.fit()` call. This raised a real
   `TypeError: 'NoneType' object is not callable` on the next epoch —
   recompiling a model inside a callback during an active `fit()`
   invalidates the compiled `train_function`. Fixed by splitting into two
   sequential `fit()` calls.
4. **Fine-tuning destabilized the model — a real, measured regression.**
   With the mid-fit bug fixed, the actual two-phase run (frozen base, then
   unfreeze 50 MobileNetV3Small layers at lr=1e-5) showed frozen-base
   val_accuracy peaking at 0.5061, then the fine-tune phase's loss exploding
   from ~0.70 to as high as 18.9 and val_accuracy collapsing to 0.25-0.37 —
   the model degenerated into predicting almost one class (confusion matrix
   that run: `[[2943,57,0],[2043,80,0],[2965,35,0]]`, RISKY recall 0). This
   is catastrophic forgetting, not a fluke — verified via the full per-epoch
   log. **Fine-tuning was disabled** for the final run; only the frozen-base
   head (GlobalAveragePooling + dense layers on top of frozen
   ImageNet-pretrained MobileNetV3Small) was trained.
5. **`model.save()` extension error.** Keras 3's `model.save()` requires a
   `.keras`/`.h5` file extension; the SavedModel-directory export needed
   for the TFLite converter requires `model.export(dir)` instead. Fixed
   after a real traceback confirmed the exact error.

## Real result (final run, Kaggle kernel `zapsafe-day289-m3-ucf-crime-retrain`, version 4, T4/P100 GPU, ~4.3 min train)

Held-out **test split accuracy: 0.5018** (3-class; chance = 0.333).

| class | F1 |
|---|---|
| SAFE | 0.5289 |
| NEUTRAL | 0.4378 |
| RISKY | 0.5166 (recall 0.5253) |

Confusion matrix (rows=true, cols=pred, order SAFE/NEUTRAL/RISKY):

```
[[1622,  533,  845],
 [ 565,  878,  680],
 [ 947,  477, 1576]]
```

Training curve (`day289_training_log.csv`): train accuracy climbed steadily
to 0.76 while val_accuracy plateaued around 0.50-0.52 from epoch 8 onward
and val_loss slowly rose — the model overfits past that point, which is why
early stopping (patience 5, monitor val_accuracy, restore best weights)
correctly stopped at epoch 13 and restored the epoch-8 weights. Final held-
out test accuracy (0.5018) is consistent with that restored validation
accuracy (0.5186) — no sign of train/test leakage inflating the number,
which is exactly what the video-level split was meant to guarantee.

## Independent sanity check

The confusion matrix is **not collapsed to one class** — all three classes
get meaningful true-positive mass and the model's errors are spread
plausibly (SAFE is most often confused with RISKY, not with NEUTRAL, which
is a reasonable failure mode given the coarse label boundary). This is a
real, meaningful signal by itself: run 3's broken fine-tuning phase produced
exactly the degenerate single-class collapse this run does NOT show, so we
know the model is discriminating on real features, not defaulting to a
constant answer.

The "is this model just learning grainy-CCTV-quality as a shortcut" concern
does not apply within this dataset the way it would for a Places365-vs-CCTV
comparison, because **all three classes (SAFE/NEUTRAL/RISKY) are drawn from
the same UCF-Crime CCTV camera domain** — there is no grain/quality
confound between classes to exploit. What this result does *not* establish
is generalization to non-CCTV, everyday phone-camera scenes (which is
ultimately what the shipped model needs to handle) — I did not have a real,
accessible set of non-surveillance photos in this environment to test
against this session, so that generalization gap is a real, documented
open question for whoever picks this up next, not something I'm claiming to
have verified.

## Verdict

**0.50 accuracy / 0.53 RISKY recall on a 3-class task (chance 0.33) is a
real, modest, non-fabricated signal above chance** — better than nothing,
clearly not production-grade. This is a real candidate to replace/supplement
day84's invented-label training data, but it needs at least one more real
iteration (larger sample, possibly a slightly larger backbone, and testing
generalization to non-CCTV imagery) before it's a genuine improvement over
the existing shipped `scene_analyzer_v1.tflite`, which itself has not been
evaluated against any real labeled set per `DAY268_UNTESTED_MODELS_EVAL.md`.

**Not wired into the app.** Per `DAY268_UNTESTED_MODELS_EVAL.md`, the
currently-shipped `m3` (`scene_analyzer_v1.tflite`) already has real
detector/fusion plumbing in place (referenced by the `w3`/`w_*` fusion
heads) but its own real-data accuracy has never been verified — wiring in
this session's new checkpoint would require (a) exporting it to match the
shipped model's real uint8 `[1,224,224,3]` -> `[1,1]` I/O contract (this
retrain currently outputs float32 `[1,3]` softmax, a different contract)
and (b) a real before/after comparison against the shipped model on the
same eval set. Both are separate follow-up work, explicitly out of scope
here per this session's instructions. No detector/wiring files, `.tflite`
assets, `pubspec`, or backend code were touched.

## Files produced this session

- `kaggle_notebooks/day289_m3_ucf_crime_push/day289_m3_ucf_crime.py` — real training script
- `kaggle_notebooks/day289_m3_ucf_crime_push/kernel-metadata.json` — Kaggle kernel config
- `kaggle_notebooks/day289_m3_ucf_crime_push/final/m3_ucf_crime_report.json` — real metrics (accuracy, per-class F1, confusion matrix)
- `kaggle_notebooks/day289_m3_ucf_crime_push/final/day289_training_log.csv` — real per-epoch training curve
- `kaggle_notebooks/day289_m3_ucf_crime_push/final/m3_ucf_crime_retrain.tflite` — real exported model (NOT copied into `zapsafe_mobile/assets/models/` — left as a candidate artifact, not shipped)
- This file, `assets/models/DAY289_M3_UCF_CRIME_RETRAIN.md`, in `zapsafe_mobile` on branch `day289-m3-ucf-crime-retrain`
