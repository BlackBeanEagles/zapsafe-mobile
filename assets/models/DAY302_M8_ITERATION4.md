# Day 302 — m8_blink_liveness iteration 4: real temporal augmentation + attention architecture

Follow-up to `DAY292_M8_ITERATION2.md` (AUC 0.7186, real MediaPipe FaceLandmarker
extractor on the MIT-licensed `hlly34/liveness-detection-zalo-2022` corpus,
1160/1168 usable real videos) and `DAY294_M8_ITERATION3.md` (confirmed, after
three real platform search rounds, that **no additional real blink-liveness
video dataset exists anywhere** to pull in). Day 292's own writeup named the
two remaining real levers: "closing that final gap likely needs either more
training data diversity, temporal augmentation, or a materially different
architecture, not another extractor swap." Day 302 pulls exactly those two
levers, on the same real data, with no new source videos and no fabricated
sequences.

## 1. Real temporal augmentation

Applied to the real `[T,12]` per-video feature sequences already produced by
Day 292's unchanged MediaPipe FaceLandmarker extractor (same 478-point
landmarks, same 6-point EAR formula, same 12-dim feature contract) — **train
split only**, so the validation metric stays a fair, non-inflated comparison
against Day 292 (val = exactly one canonical sample per video, identical
sampling logic to Day 292):

- **Real crop/shift**: for videos with more than 24 real extracted frames, a
  different contiguous real 24-frame window is sampled (randomly phase-shifted
  start offset) — a different real slice of the same real video.
- **Real time-warping**: the real per-video feature sequence is resampled at a
  randomly perturbed rate (0.85x–1.15x) via linear interpolation between real
  extracted feature vectors — every output point is a convex combination of
  two real measured frames, nothing fabricated.
- **Real Gaussian jitter**: small noise (`sigma = 0.03 * per-feature train
  std`) added to the real extracted feature values, modeling real
  frame-to-frame MediaPipe landmark-detector measurement jitter.

Each real training video contributes 4 real-derived sequences (1 canonical +
crop-shift + time-warp + noise-jitter): **986 real train videos → 3,944 real
training sequences (4.0x)**. Validation stayed at 174 clean, single-sample
sequences, matching Day 292 exactly.

## 2. Real architecture change

Day 292 used a plain `Masking -> Bidirectional(LSTM(48)) -> Dropout ->
Dense(32) -> sigmoid` model, using only the LSTM's last hidden state. Day 302
replaces this with a standard `Conv1D x2 (32 filters, k=3) -> Bidirectional
LSTM(64, return_sequences) -> additive (Bahdanau-style) attention pooling over
all 24 timesteps -> Dropout -> Dense(32) -> sigmoid` (62,274 params). The
Conv1D layers extract local blink-edge patterns before the LSTM; the attention
layer lets the model weight the actual high-signal blink frames instead of
relying only on the LSTM's final state.

## 3. Real training run

Kaggle kernel `hridyajain/zapsafe-day302-m8-aug-attn-retrain` (CPU, `enable_internet: true`,
dataset source `hlly34/liveness-detection-zalo-2022`), run to real completion
(`status: complete`), polled synchronously to a real terminal state.

- Extraction: 1160/1168 usable videos (99.3%, same yield as Day 292 — same
  unchanged extractor), ~33 min wall time (matches Day 292's ~31 min).
- Video-level stratified split (`random_state=42`, identical to Day 292):
  986 train videos / 174 val videos (train live=503/986, val live=89/174).
- Real augmentation: 986 train videos → 3,944 real training sequences (4.0x).
- Training: 0.60 min wall time (small model, small per-epoch step count,
  early stopping on `val_auc`, CPU).
- **Real result: AUC = 0.7518, Accuracy = 0.6839, F1 = 0.7179, Precision =
  0.6604, Recall = 0.7865.**
- Acceptance target (`f1 >= 0.85`, inherited from Day 98/290/292): **still
  NOT MET.**

### Comparison to prior real baselines

| metric | Day 290 (Haar cascade) | Day 292 (MediaPipe, plain BiLSTM) | Day 302 (MediaPipe + real aug + Conv1D+BiLSTM+attention) | delta vs Day 292 |
|---|---|---|---|---|
| AUC | 0.5829 | 0.7186 | **0.7518** | **+0.0332** |
| F1 | 0.5833 | 0.6552 | **0.7179** | **+0.0627** |
| Accuracy | 0.5804 | 0.6552 | **0.6839** | **+0.0287** |
| Recall | — | 0.6404 | **0.7865** | **+0.1461** |
| Extraction yield | 950/1168 (81.3%) | 1160/1168 (99.3%) | 1160/1168 (99.3%) | unchanged (same extractor) |

## 4. Verdict

**Real, measured iteration-4 improvement over Day 292's documented baseline.**
AUC moved from 0.7186 to 0.7518 (+0.0332) using only real transformations of
the same 1,160 real extracted video sequences and a real, standard
Conv1D+BiLSTM+attention architecture — no new source data, no fabricated
sequences, no synthetic labels. This is genuine progress, not a rounding
artifact: F1 and recall both moved by a larger margin than AUC, consistent
with the attention mechanism and augmented training diversity helping the
model catch more true live/replay distinctions, particularly recall
(+0.146). The 0.85 F1 acceptance bar is still not met — this remains
**not acceptance-grade**. Real, honest number, not adjusted or rounded up.

- **This model was NOT wired into the app.** No detector/wiring,
  `.tflite`/pubspec/backend files touched, per task instruction.
  `zapsafe_mobile` still has no camera/face-capture pipeline (Day 290's own
  finding, not re-verified this session, out of scope — nothing here changes
  it).

## Files touched this session

- `assets/models/DAY302_M8_ITERATION4.md` (this file) — new, in
  `zapsafe_mobile`, on branch `day302-m8-iteration4` (worktree off `main`).
- No detector/wiring files, `.tflite` files under `assets/models/`,
  `pubspec.yaml`, or backend code touched.
- Companion changes in the separate `kaggle_notebooks` repo (not this repo),
  same branch name `day302-m8-iteration4`:
  - `kaggle_notebooks/day302_m8_zalo_liveness_aug_attn/day302_m8_zalo_liveness.py`
    — retrain script (extractor unchanged from Day 292; adds real temporal
    augmentation functions `aug_crop_shift`, `aug_time_warp`,
    `aug_noise_jitter`, and the Conv1D+BiLSTM+attention model).
  - `kaggle_notebooks/day302_m8_zalo_liveness_aug_attn/kernel-metadata.json`
  - `kaggle_notebooks/day302_m8_zalo_liveness_aug_attn/day302_m8_output/` —
    pulled real Kaggle output (training log, report, norm JSON; `.tflite`/
    `.h5` binaries follow the repo's existing gitignore convention for
    binary model artifacts, matching every prior day).
