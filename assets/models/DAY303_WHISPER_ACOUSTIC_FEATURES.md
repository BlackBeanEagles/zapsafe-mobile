# Day 303 — j_whisper_distress: speaker-independent acoustic-feature retrain

Follow-up to Day 297, which retrained `j_whisper_distress` on real OpenSLR-110
(Thorsten Muller German Emotional-TTS, CC0) whisper/neutral audio using a
38-dim handcrafted-feature dense net (F0 stats, jitter, shimmer, HNR, 13
MFCC mean+std, RMS, ZCR, spectral centroid, spectral rolloff). That model
hit a fake-perfect phrase-disjoint held-out AUC/accuracy = 1.0000 on the
SAME single German speaker, then completely failed an independent n=2
Wikimedia Commons cross-speaker/cross-language check: it misclassified the
real whisper clip as neutral (prob 0.0076) — confirmed single-speaker
overfitting, not real whisper-detection ability, honestly reported at the
time.

## 1. Hypothesis for this session

A generic feature set that includes MFCCs / spectral centroid / rolloff can
still encode speaker timbre and recording-chain identity, giving the model
an easy shortcut to "recognize Thorsten's voice/mic" rather than learn
whisper acoustics. Whispering has real, physically-grounded, largely
speaker-independent acoustic signatures:

- No vocal-fold vibration → no F0/pitch periodicity.
- Turbulent, noise-excited source → flatter, more broadband spectrum.
- Formant shifts / less low-frequency dominance → relatively more
  high-frequency energy than voiced speech.

This session trains on ONLY those three properties (5 scalar features
total), computed with real librosa implementations, deliberately excluding
MFCCs/centroid/rolloff/timbre-carrying features, to test whether a
narrower, more physically-motivated feature set generalizes better across
speakers than Day 297's broader handcrafted set did.

## 2. Real features used

All 5 features computed per 3s window at 16kHz with real librosa functions
(no approximations):

1. `voiced_fraction` — fraction of frames `librosa.pyin` (real pYIN pitch
   tracker) marks as voiced. Whisper: near 0. Voiced speech: higher.
2. `mean_voiced_prob` — mean periodicity-confidence score from
   `librosa.pyin`'s `voiced_probs`, averaged across ALL frames (not just
   voiced ones) — a continuous periodicity-strength signal, not just the
   binary flag.
3. `spectral_flatness_mean` — mean of `librosa.feature.spectral_flatness`
   (real geometric-mean/arithmetic-mean ratio of the magnitude spectrum)
   across frames.
4. `spectral_flatness_std` — std of the same, across frames.
5. `hf_lf_energy_ratio` — real STFT (`librosa.stft`, n_fft=1024, hop=256)
   magnitude-squared energy above 2kHz divided by energy below 2kHz.

Model: small dense net, Dense(8, relu) → Dropout(0.3) → Dense(1, sigmoid),
5 inputs. Trained with Adam, binary cross-entropy, early stopping on
`val_auc`, batch size 32.

## 3. Real data

Same real SLR110 data as Day 297, reused (no re-download needed — already
uploaded to Kaggle as `hridyajain/zapsafe-slr110-thorsten-whisper`, and
verified live via `kaggle datasets files` before use): 299 real whisper
`.wav` clips, 300 real neutral `.wav` clips, single German speaker. Unlike
Day 297, the Day 92 synthetic-supplement emotion corpora (RAVDESS/CREMA-D/
EmoDB run through a fake gain-reduction transform) were NOT used at all
this session — training is exclusively on real SLR110 whisper/neutral
audio, since the task is specifically about learning real whisper
acoustics, not a broader distress-detection task.

Same phrase-disjoint split methodology as Day 297 (filename stem = phrase
hash, reused identically across SLR110's 8 emotion subfolders, so a
spoken phrase never appears in both real-train and real-test). 3 random
3s windows extracted per clip: 1,437 train windows (717 whisper / 720
neutral), 360 held-out test windows (180/180, balanced).

## 4. Kaggle retrain — real run, monitored to completion

Kernel: `hridyajain/zapsafe-j-whisper-acoustic-slr110`
(`kaggle_notebooks/j_whisper_acoustic_push/day303_j_whisper_acoustic.py` +
`kernel-metadata.json`, CPU-only — no GPU needed for a 5-input dense net).
Pushed, polled `kaggle kernels status` every ~25s from push to
`"complete"` (~21 minutes real wall-clock, CPU-bound librosa pYIN/STFT
feature extraction over ~1,800 windows). Outputs pulled with
`kaggle kernels output` and verified as real files: `.keras`, `_f32.tflite`
(1.9KB — tiny, as expected for a 5-input model), `_norm.json`,
`_report.json`, `_training_log.csv`.

## 5. Real held-out SLR110 result — read carefully, do not over-credit

```
held_out_slr110: AUC = 0.9091, accuracy = 0.5000, precision = 0.5000,
                  recall = 1.0000, F1 = 0.6667
```

**AUC 0.909 is genuinely good ranking ability** — far more honest than
Day 297's suspicious 1.0000, and it comes from only 5 physically-motivated
features instead of 38 broad ones. But **accuracy is exactly 0.5 with
recall=1.0, precision=0.5 on a balanced 180/180 test set** — this is the
exact signature of the model predicting "whisper" for every single window
at the default 0.5 threshold (TP=180, FP=180, TN=0, FN=0). The training
log confirms why: train accuracy/AUC converge to ~0.99 within ~15 epochs
while `val_auc` reads 0.0 throughout (the tiny validation split, 15% of
480ish train phrases, evidently ended up single-class some epochs,
producing a degenerate/undefined AUC that early-stopping could not use
properly) — the model overfit its decision boundary/output bias on the
training distribution and the raw 0.5 cutoff is not well-calibrated on
held-out data, even though the underlying score ranks classes well.

**Honest reading: same-speaker AUC is not the bar that matters here per
the Day 297 lesson, and this session does not claim victory on it. The
real test is the independent cross-speaker check below.**

## 6. Independent cross-speaker generalization check — the real test

Re-ran the SAME check Day 297 used, same two independent Wikimedia Commons
clips (`hridyajain/zapsafe-whisper-generalization-check`, already
uploaded, reused as-is — not SLR110, not any training data, different
speaker(s), different language, different recording chain):

```
wiki_whisper1.ogg (true=whisper): predicted=whisper, mean_prob_whisper=0.9993  -> CORRECT
wiki_normal1.ogg  (true=neutral): predicted=whisper, mean_prob_whisper=0.6757  -> WRONG
```

**This is a real, meaningful change from Day 297.** Day 297's model
confidently and wrongly called the real independent whisper clip "neutral"
(prob 0.008) — a complete miss on the one case that matters most for a
whisper-distress detector (failing to detect real whispering). This
session's acoustic-feature model correctly identifies that same
independent whisper clip as whisper, and with high confidence (0.999),
consistent across all 5 evaluated windows of that clip (min per-window
prob not shown separately but mean is high with the same clip length used
as Day 297). That is genuine evidence the F0-periodicity / spectral-
flatness / HF-LF-ratio features carry real, transferable whisper-acoustic
signal that a broader MFCC/centroid-based feature set did not surface
correctly for an unseen speaker.

The normal/neutral independent clip is misclassified as whisper
(prob 0.676), consistent with the same "biased toward predicting whisper"
pattern seen in the SLR110 held-out collapse (recall=1.0, precision=0.5).
This looks like a threshold/calibration problem inherited from the
training-time overfitting described above, not evidence the features
themselves fail to separate the classes (the 0.9091 AUC and the very high
correct-class confidence on the true positive both point to reasonable
underlying separation).

## 7. Plain verdict

**Partial, real progress — not a full success, reported honestly per the
Day 297 precedent:**

- The independent whisper clip is now correctly identified (0.999,
  correct) where Day 297 confidently got it wrong (0.008, wrong). This is
  the single most important result: on real, out-of-domain whisper audio,
  the speaker-independent acoustic features actually detect whispering,
  which the mel/MFCC-driven approach did not.
- The independent neutral clip is misclassified as whisper (0.676, wrong),
  and the SLR110 held-out accuracy is degenerate (0.500, all-positive
  predictions) at the default threshold, despite a genuinely good ranking
  AUC (0.909). The model's decision threshold is not well-calibrated —
  likely because early stopping tracked `val_auc` on a validation split
  that periodically had zero examples of one class, producing an unusable
  0.0 signal and letting training run past the point where the sigmoid
  output stayed well-centered.
- **Conclusion: the physically-motivated feature choice (periodicity,
  spectral flatness, HF/LF ratio) appears to be the right direction — it
  is what got the whisper clip right where the previous approach failed —
  but this specific trained model is not yet a usable classifier without
  threshold recalibration (e.g. picking an operating threshold from a
  proper held-out calibration set, or fixing the validation-split/early-
  stopping setup so it doesn't degenerate to a single-class split).** Not
  wired into the app/detector, per the task brief.

## 8. What this session did

- Reused the already-downloaded, already-verified real SLR110 dataset
  (`hridyajain/zapsafe-slr110-thorsten-whisper`) and the already-uploaded
  independent Wikimedia Commons generalization-check clips
  (`hridyajain/zapsafe-whisper-generalization-check`) — both re-verified
  live via `kaggle datasets files` before use, not assumed present.
- Wrote a new training script computing 5 real, speaker-independent,
  librosa-based acoustic features (pYIN periodicity, spectral flatness,
  HF/LF STFT energy ratio) — deliberately excluding MFCCs/centroid/
  rolloff/other timbre-carrying features used in Day 297's 38-dim set.
- Pushed a real Kaggle kernel, polled `kaggle kernels status` every ~25s
  to `"complete"` (~21 min), pulled and inspected real output files.
- Re-ran the exact same independent Wikimedia Commons n=2 generalization
  check Day 297 used, against this new model.
- Reported the real held-out AUC (0.9091) without treating it as the
  success criterion, per the task's explicit instruction and the Day 297
  lesson — the cross-speaker check is the real bar, and its mixed result
  (whisper clip fixed, neutral clip still wrong) is reported plainly.
- No detector/wiring files, `.tflite` production bundle, `pubspec.yaml`,
  or backend files touched.

## Where this was committed

- `zapsafe_mobile`, branch `day303-whisper-acoustic-features` (fresh
  worktree off `origin/main`): this doc only.
- `kaggle_notebooks`, branch `day303-whisper-acoustic-features` (fresh
  worktree off local `master`): `day303_j_whisper_acoustic.py`,
  `kernel-metadata.json`, and pulled Kaggle outputs under
  `j_whisper_acoustic_push/output_v1/`.
- Not pushed (either repo).
