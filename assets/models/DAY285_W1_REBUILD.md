# Day 285 — w1 fusion (M1 scream + M2 motion) real rebuild attempt

Follow-up to `DAY280_W1_FUSION.md` (found `w1`'s reported 0.9568 AUC was a
circular-labeling artifact: `y = AND(s1>0.45, s2>0.5)` on the same `s1,s2`
fed to the model) and `DAY282_W2_W5_FUSION_INVESTIGATION.md` (found w2-w5
have the same bug, worse — they never call real upstream models at all).
Day 280 concluded retraining w1 "would not fix this" without a genuinely
independent label source, and that no such source existed locally or in
Drive. This session built one and retrained for real, rather than
re-asserting the Day 280 conclusion.

## The fix, in two parts

**Bug 1 (fake fusion) — replaced heuristics with real inference.**
`build_w1_dataset()` computed `s1`/`s2` with hand-written signal heuristics
(RMS, mel energy, zero-crossing for audio; std/jerk of accel magnitude for
IMU) and never touched a `.tflite` file. The rebuild loads the real shipped
`models/components/m1_scream_v2.tflite` (input `[1,128,131,1]` float32 mel,
verified via `interpreter.get_input_details()`) and
`models/components/m2_motion_v2.tflite` (input `[1,100,6]` float32 raw IMU,
z-normalized with the real `norm_mean`/`norm_std` from
`m2_motion_v2_report.json`) with `tf.lite.Interpreter`, and runs real
inference on real audio clips and real IMU windows to produce `s1`/`s2`.
One approximation is noted honestly below (mel-spectrogram duration/frame
count for M1 was reconstructed, not read from M1's own training script,
since the shipped `.tflite`'s exact preprocessing config wasn't recoverable
from the repo in the time available).

**Bug 2 (circular labels) — labels now come from the source corpora, not
from `s1`/`s2`.**
Old rule: `y = 1 if s1 > 0.45 and s2 > 0.5 else 0` — a deterministic
function of the model's own two inputs.
New rule: `y = 1` iff the audio clip is drawn from a real scream/distress
ESC-50/UrbanSound-hard category (`crying_baby`, `screaming`, or
scream/cry-labeled UrbanSound-hard clips — the corpus's own class label)
**and** the IMU window is drawn from a real MobiAct/PAMAP2 fall-code
segment (`FOL/FKL/BSC/SDL/JOG/JUM` — the corpus's own activity code).
`y = 0` for three negative kinds, all still built from real independently
labelled source clips:
  - calm audio (real ESC-50 ambient categories) × ADL IMU (real
    non-fall activity codes) — the "true negative" case,
  - scream audio × ADL IMU — audio alone is positive, must not count,
  - calm audio × fall-code IMU — motion alone is positive, must not count.

The last two negative kinds exist specifically so the model can't win by
detecting either modality alone; it has to require both, same as the
combined-incident concept is supposed to mean. `s1` and `s2` never appear
anywhere in the label-generation code — only in the model's input features
(`[s1, s2, s1*s2, |s1-s2|]`, same 4-dim scheme as the original for a fair
comparison).

## Why this is a genuinely different kind of independence (and where it isn't)

The label for each pair is a function of **which corpus and which class
code the two component clips came from** — information that exists before
and independently of running M1/M2 on them. Shuffling M1/M2's weights, or
replacing them with a different pair of scream/motion classifiers, would
not change a single label. That is the property the old rule did not have
(its labels moved in lockstep with the exact `s1`/`s2` values because they
were defined as a threshold on those values). This is real, structural
independence between label source and feature source.

**Residual risk, stated plainly (this is the self-critical part the task
asked for):** the "combined incident" label is a **cross-corpus pairing**
of two clips that were never recorded together — a real ESC-50 scream clip
and a real MobiAct fall clip, arbitrarily matched by the pairing loop, not
a real synchronized recording of one person screaming while falling. So
while the label is independent of `s1`/`s2` (fixing the exact bug that was
found), it is still **not literal ground truth for "a real combined
scream+fall event happened."** It's ground truth for "a real scream
recording was paired with a real fall recording by construction" — a
weaker claim. This is the same category of concern the project has hit
repeatedly this week (proxy labels standing in for the thing you actually
want to detect), just one level further out: the label-generation
mechanism no longer touches the model's own inputs, but it is still a
constructed proxy for the true target, not an observation of it. No
dataset of real synchronized "distress scream during a real fall" clips
was found in this project's Kaggle account or Drive folder in the time
available for this session — that is still the fundamentally missing
piece, same as Day 280's conclusion, just now correctly separated from the
label-circularity bug (which *is* fixed).

## What was actually run (real, on Kaggle, monitored to completion)

- Uploaded the real shipped `m1_scream_v2.tflite`, `m2_motion_v2.tflite`,
  and `m2_motion_v2_report.json` as a new private Kaggle dataset
  (`hridyajain/zapsafe-w1-rebuild-m1-m2-models`) since they weren't
  otherwise available inside a Kaggle kernel filesystem.
- Wrote `day285_w1_rebuild.py` (real M1/M2 TFLite wrappers +
  independent-label pair builder + fusion-MLP trainer, same 16-8-1
  architecture as the original for a fair comparison) and concatenated it
  with `day106_audio_common.py`/`day106_fusion_common.py` (real ESC-50 /
  UrbanSound / MobiAct / PAMAP2 / WISDM / UCI-HAR loaders, unmodified
  except for one bugfix below) into
  `day285_w1_rebuild_kaggle_all_in_one.py`, pushed as kernel
  `hridyajain/zapsafe-day285-w1-rebuild-notebook`.
- Real bugs hit and fixed while getting this to run for real (documented
  for anyone continuing this): (1) a stray `from __future__ import
  annotations` mid-file after concatenation — syntax error, fixed by
  de-duplicating; (2) the Kaggle dataset mount path was
  `/kaggle/input/datasets/<owner>/<slug>/...`, not
  `/kaggle/input/<slug>/...` as in older kernels — fixed with a
  `rglob("m1_scream_v2.tflite")` fallback scan; (3) `day106_audio_common.py`'s
  `kaggle_input_roots()` role-keyword table had no entry for `"esc50"`, so
  `cache_roots("esc50")` matched nothing against the real dataset folder
  name (`environmental-sound-classification-50`) even though the dataset
  was attached — fixed by adding `"esc50": ["esc50",
  "environmentalsoundclassification50", "environmental-sound-classification-50"]`
  to the role table (this is a real, generically useful fix to shared code,
  not a workaround specific to this run).
- First real run (kernel v6, small caps: 24 scream clips, 24 calm clips,
  24 fall windows, 24 ADL windows) completed but the held-out grouped test
  set — split with `GroupShuffleSplit` grouped by source audio clip, so the
  same clip's pairs never span train/test — landed at exactly AUC 0.500
  (chance), and the Keras validation curve showed `val_auc: 0.0000e+00`
  every epoch. Root cause: the pair-construction loop emits samples in
  contiguous same-label blocks (all `pos_scream_fall` together, etc.), and
  neither Keras' internal `validation_split` (takes a trailing slice) nor
  the tiny group count (only 48 total audio-clip groups) coped with that —
  fixed by shuffling the training indices before `model.fit` and increasing
  caps to 70 clips/windows per class (140 audio groups) for a less
  degenerate split.
- Second real run (kernel v8, caps raised to 70/70) completed cleanly:
  15,400 real pairs (2,800 positive, 12,600 negative across the three
  negative kinds), 11,480 train / 3,920 held-out grouped test.

## Real result

```
test_auc_grouped_holdout: 0.578125
n_train: 11480, n_test: 3920
production_gate_auc: 0.88
production_pass: false
```

Full report: `day285_w1_rebuild_report/day285_w1_rebuild_report.json`
(pulled directly from the completed Kaggle kernel output, not
hand-transcribed). Training-time AUC (in-sample, not the held-out number)
also stayed in the 0.55-0.59 range across all 9 epochs before early
stopping, consistent with the held-out number rather than contradicting it
— this is not a case of a good model undermeasured by a bad split.

**AUC 0.578 is barely above chance (0.5) and far below both the fake
0.9568 the old pipeline reported and the 0.88 production gate.** With the
circularity bug removed and real M1/M2 inference in place, this specific
construction of `w1` shows no meaningful real discrimination.

## Interpretation — what a weak-not-fake number means here

This is a categorically different outcome from Day 280's finding, and it's
important not to conflate them:
- Day 280: the number (0.9568) was **meaningless** — it measured the
  network reproducing its own label rule.
- Day 285: the number (0.578) is **real but weak** — real independent
  labels, real model inference, genuine held-out evaluation, and the
  answer is "not much signal here, at this scale, with this label
  construction."

Plausible (non-exclusive) reasons for the weak result, none of which were
resolved in the time available for this session:
1. **Small clip diversity.** Only 40-70 distinct source clips per class
   (capped for Kaggle CPU runtime) — even though 15,400 pairs were
   generated, they're combinatorial products of a small clip pool, so the
   effective information content is closer to "40-70 audio clips x 70
   IMU windows" than 15,400 independent observations.
2. **Cross-corpus pairing dilutes joint signal.** Because positive pairs
   are arbitrary (clip, window) combinations rather than a real
   synchronized event, there's no actual causal/temporal relationship
   between `s1` and `s2` for a real positive — the model can only learn
   "both marginals are individually high," which the 4-feature scheme
   already exposes almost losslessly (`s1`, `s2`, `s1*s2`, `|s1-s2|`); if
   M1's and M2's real score distributions on these corpora don't separate
   cleanly on their own, no fusion head can rescue that.
3. **M1 preprocessing approximation.** The exact mel-spectrogram
   duration/hop that produces `m1_scream_v2.tflite`'s expected 131 frames
   wasn't independently re-derived from that model's own (possibly
   updated/undocumented) training script; the rebuild used a best-effort
   reconstruction (22050 Hz, 3.0 s, pad/crop to 131 frames) that may not
   exactly match what the shipped model was trained on, which would
   degrade `s1`'s quality independent of any fusion-modeling issue.

None of these were run down further given the session's time budget — they
are the natural next steps, not resolved gaps.

## Honest verdict

**Not trustworthy as a "w1 is ready" result — but also not fake.** The
label-independence bug from Day 280/282 is genuinely fixed: labels are a
function of source-corpus class codes, not of `s1`/`s2`, and this was
checked by direct inspection of the label-generation code (no threshold on
`s1`/`s2` anywhere in `build_real_pairs`). The real-inference bug is also
genuinely fixed: both `s1` and `s2` come from `tf.lite.Interpreter.invoke()`
on the real shipped `.tflite` files, verified by reading their real input
signatures first. But the resulting AUC (0.578) does not clear a useful
bar, so **this rebuilt `w1` should not be wired**, same practical
conclusion as Day 280, now for a different and more defensible reason (real
weak signal, not measurement fraud). The deeper "is cross-corpus clip
pairing an adequate proxy for a true synchronized combined-incident label"
question remains open and is the most likely next thing to revisit if this
gets picked up again — it would need either a real synchronized
scream+fall corpus (not found in this account/Drive) or a principled
argument for why cross-corpus pairing should be expected to work despite
lacking temporal/causal correlation, neither of which exists yet.

**Not wired.** No backend, detector, mobile asset, or pubspec changes made
this session, per the task's constraints.

## Files touched this session

- `kaggle_notebooks/day285_w1_rebuild_push/day285_w1_rebuild.py` — new,
  real M1/M2 TFLite wrappers, independent-label pair builder, trainer.
- `kaggle_notebooks/day285_w1_rebuild_push/day285_w1_rebuild_kaggle_all_in_one.py`
  — new, the pushed/executed Kaggle script (concatenation of the above with
  `day106_audio_common.py` + `day106_fusion_common.py`, plus the esc50
  role-keyword fix).
- `kaggle_notebooks/day285_w1_rebuild_push/day106_audio_common.py`,
  `day106_fusion_common.py` — local copies, one real generic bugfix applied
  (esc50 role-keyword mapping, see above); originals under
  `day106_fusion_crosslang_push/` in `main` are untouched by this branch.
- `kaggle_notebooks/day285_w1_rebuild_push/kernel-metadata.json` — new.
- `kaggle_notebooks/day285_w1_rebuild_push/day285_w1_rebuild_report/` —
  real report/norm JSON pulled from the completed Kaggle kernel (v8).
- `kaggle_notebooks/day285_w1_rebuild_push/DAY285_W1_REBUILD.md` — this
  file.
- New private Kaggle dataset `hridyajain/zapsafe-w1-rebuild-m1-m2-models`
  (real `m1_scream_v2.tflite` / `m2_motion_v2.tflite` / report json, needed
  so the Kaggle kernel could run real inference against the real shipped
  models).
- New private Kaggle kernel `hridyajain/zapsafe-day285-w1-rebuild-notebook`
  (8 pushed versions while debugging the concatenation/mount/esc50 issues
  above; v8 is the completed, reported run).
- Branch `day285-w1-rebuild`, worktree `kaggle_notebooks_day285`, off
  `master`. Not pushed to remote. No backend, detector/wiring files,
  `assets/models/*.tflite`, or `pubspec.yaml` touched.
