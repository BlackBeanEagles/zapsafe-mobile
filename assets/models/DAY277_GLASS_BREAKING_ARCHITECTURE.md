# Day 277 -- `m_glass_breaking`: architecture experiment (real result: no improvement)

Follow-up to `DAY263_GLASS_BREAKING_MORE_DATA.md`, whose real conclusion was
that readily available real positive data for `m_glass_breaking` is
exhausted (ESC-50 40, FSD50K 974, AudioSet 106, NIGENS 9 = 1,129 raw
positives, every locally available dataset re-checked and confirmed dead)
and that the next lever, if any, would be "an architecture change." This
session made that architecture change, retrained on Kaggle, and measured
the real result. **Verdict, stated plainly: it did not help. AUC and
recall both went down relative to the day262 baseline.** This is reported
honestly, not stretched into a false positive result -- per this task's
explicit instruction not to repeat the earlier fake "recall 1.0" mistake.

## 1. Baseline (unchanged, from `DAY263_GLASS_BREAKING_MORE_DATA.md`)

```json
{
  "auc": 0.7485,
  "recall_glass_break": 0.535,
  "f1_glass_break": 0.6257,
  "raw_pos": 1129,
  "raw_neg": 4011
}
```

## 2. What was changed

Fork of `day262_m_glass_breaking_retrain.py` ->
`kaggle_notebooks/day277_m_glass_breaking_arch_push/day277_m_glass_breaking_arch.py`.
Exactly two changes, chosen to keep this an interpretable single/double-variable
experiment rather than a shotgun of every possible tweak. Data loaders (ESC-50,
FSD50K, AudioSet, UrbanSound8K, NIGENS), preprocessing (sr=16000, 2.0s,
96 mels, hop=512, n_fft=2048, fmax=8000, 96x96x3), MobileNetV2-frozen-backbone
model shape (GAP -> Dropout 0.3 -> Dense 64 relu -> Dense 1 sigmoid), and
train/val/test split are all UNCHANGED from day262.

### Change 1 -- real-audio augmentation replacing exact-duplicate oversampling

Reading `day262`'s own `balance_pos_neg()` showed the "oversampling" that
takes `raw_pos=1129` up to `final_pos=4000` was implemented as
`pos.append(random.choice(base))` -- i.e. ~2,871 of the 4,000 positive
training windows were **bit-identical duplicates** of a real clip's
precomputed melspec, not new information. That is a real, plausible
overfitting risk on a small positive set.

Fix: added `augment_real_positive()`, which takes a real raw waveform
already loaded during data collection and produces a genuinely new view of
it via:
- pitch shift, +-2 semitones (`librosa.effects.pitch_shift`)
- time stretch, 0.85x-1.15x (`librosa.effects.time_stretch`)
- real background-noise mixing: a real negative-class waveform, drawn from
  a 400-clip bank sampled from the SAME negatives already loaded for
  training (`NEG_WAV_BANK`), mixed in at a random SNR (3-15 dB)

then re-cropped and re-converted to a melspec via the existing, unchanged
`audio_to_melspec()`. Raw waveforms for all 1,129 real positives were
captured during loading (`POS_WAV_STORE`, index-aligned with the `pos`
list) specifically to make this possible. **No audio was synthesized from
scratch** -- every input to the augmentation is a real recorded clip
already part of this project's real datasets; this is real-data-preserving
augmentation, not fabrication.

### Change 2 -- focal loss replacing plain binary cross-entropy

`build_model()`'s loss changed from `binary_crossentropy` to
`tf.keras.losses.BinaryFocalCrossentropy(gamma=2.0, apply_class_balancing=False)`.
Rationale: the doc chain's own diagnosis is that this model's hard negatives
(FSD50K `Chink_and_clink`, `Crushing`, `Wood`; NIGENS glass-but-not-breaking
clips) are deliberately close to the decision boundary, and recall 0.535
means real positives are being missed, not that the model fails on easy
cases. Focal loss down-weights already-confident/easy examples and
concentrates gradient on hard/ambiguous ones. `apply_class_balancing=False`
because classes are already balanced 1:1 by `balance_pos_neg()`.

### Considered, not done this session

- **Reducing model capacity**: the trainable head (Dropout + Dense 64) is
  already small; the frozen MobileNetV2 backbone dominates real model
  capacity and isn't touched by a head-capacity change. Judged less likely
  to move the needle than the two changes above -- deferred, not tried.
- **Ensemble/two-stage approach**: adds a second training run and real
  complexity without isolating one testable variable in a single session.
  Deferred, not done.

## 3. Real retrain + monitoring

```
$ kaggle kernels push -p day277_m_glass_breaking_arch_push
Kernel version 1 successfully pushed.
$ kaggle kernels status hridyajain/zapsafe-day277-m-glass-breaking-arch
... running (polled every ~30s, real transient DNS failures against
    www.kaggle.com mid-poll, same as prior sessions -- connectivity
    recovered, not a scripting bug) ...
hridyajain/zapsafe-day277-m-glass-breaking-arch has status "complete"
```
Real wall-clock: pushed ~12:00, complete ~12:15 (about 15 minutes), monitored
synchronously start to finish.

## 4. Real result

Pasted verbatim from real `m_glass_breaking_arch_report.json`:

```json
{
  "model": "m_glass_breaking_arch",
  "auc": 0.7077,
  "recall_glass_break": 0.4975,
  "f1_glass_break": 0.5819,
  "int8_kb": 2532.0,
  "train_windows": 8000,
  "data_stats": {
    "esc50_pos": 40, "esc50_neg": 280,
    "fsd50k_pos": 974, "fsd50k_neg": 1181,
    "audioset_pos": 106, "audioset_neg": 2500,
    "nigens_pos": 9, "nigens_neg": 50,
    "pos_wav_store_size": 1129,
    "neg_wav_bank_size": 400,
    "raw_pos": 1129, "raw_neg": 4011,
    "pos_oversampled_to": 4000,
    "pos_oversample_augmented": 2871,
    "pos_oversample_duplicated": 0,
    "final_pos": 4000, "final_neg": 4000
  }
}
```

`pos_oversample_augmented=2871, pos_oversample_duplicated=0` confirms the
augmentation path ran for every oversampled window as intended (no silent
fallback to duplication), and `pos_wav_store_size=1129` confirms raw
waveforms were captured for all real positives -- the mechanism worked
correctly. The *result* of using it did not.

## 5. Comparison to baseline -- stated plainly

| metric | day262 baseline | day277 (architecture change) | delta |
|---|---|---|---|
| AUC | 0.7485 | 0.7077 | **-0.0408** |
| recall_glass_break | 0.535 | 0.4975 | **-0.0375** |
| f1_glass_break | 0.6257 | 0.5819 | **-0.0438** |
| raw_pos | 1129 | 1129 | 0 (unchanged, as designed) |

**Verdict: real, honest negative result.** Both changes -- real-audio
augmentation for oversampling and focal loss -- moved every headline metric
in the wrong direction versus the day262 baseline. This is not a "did not
help, no change" result; it is measurably worse. Two plausible
(non-exclusive) explanations, neither confirmed further this session:
- Focal loss's extra hard-example weighting, combined with a positive set
  whose oversampled variety is now itself harder (pitch/time-shifted,
  noise-mixed) rather than exact duplicates, may have pushed the small
  effective real-positive signal toward being outweighed by the hard
  negatives during training, rather than sharpening the boundary as
  intended.
- The augmentation ranges (+-2 semitones, 0.85x-1.15x stretch, 3-15dB real
  noise mix) were chosen by judgment, not tuned; they may be too aggressive
  for a genuinely small (1,129 clip) real positive set, moving augmented
  windows further from the real acoustic distribution of glass breaking
  than intended.

Given this task's explicit instruction to report plainly rather than repeat
the earlier fake "recall 1.0" mistake: **this architecture experiment did
not fix `m_glass_breaking`.** The day262 model (AUC 0.7485, recall 0.535)
remains the best real result to date and is NOT superseded by this run.

## 6. Not done this session (scope boundary, per task instructions)

- No `.tflite` files were copied into `zapsafe_mobile/assets/models/`, and
  no detector/wiring/pubspec/backend files were touched.
- `kaggle_notebooks` changes were committed locally only; neither repo was
  pushed to any remote.
- This branch (`day277-glass-breaking-arch`) was cut fresh off `main`
  (commit `58a84c7`), not off the already-merged `day258-ml-wiring`
  branch, and was created via a separate git worktree so as not to disturb
  unrelated in-progress uncommitted work on `day274-light-sensor`
  (another session's `mg_gunshot`/light-sensor work, untouched by this one).
- Whoever picks up `m_glass_breaking` next should treat AUC 0.7485 /
  recall 0.535 (day262) as the current best real number, know this
  session's architecture experiment (real-audio-augmentation oversampling +
  focal loss) made it measurably worse (AUC 0.7077 / recall 0.4975), and
  should not re-try this exact combination without changing the
  augmentation aggressiveness or reconsidering focal loss's gamma. Real
  further options, per the exhausted-data conclusion in
  `DAY263_GLASS_BREAKING_MORE_DATA.md`: a YouTube-download pipeline for the
  125 uncached real AudioSet glass rows (new infrastructure, out of scope
  here), or a different, more conservative architecture change (e.g. only
  the augmentation change without focal loss, or only focal loss without
  augmentation, to isolate which of the two hurt more) -- not attempted
  this session to keep this a single documented experiment rather than an
  unbounded search.
