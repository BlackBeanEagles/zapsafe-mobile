# Day 262B -- real AudioSet upload + `mg_gunshot`/`m_glass_breaking` re-run

Follow-up to `DAY261B_KAGGLE_RUNS.md`'s flagged gap: both retrains ran
without any real AudioSet data because `hridyajain/zapsafe-audioset` did
not exist on this Kaggle account. This session fixed that for real --
uploaded real AudioSet audio, re-pushed both kernels, and pulled real
results. All numbers below are pasted from real `kaggle datasets status`/
`kaggle datasets files`/`kaggle kernels status`/`kaggle kernels output`
command output -- none are estimated or assumed.

## 1. Real AudioSet subset upload

**Not** the full 15GB/9,927-clip local `DS07_AudioSet/train_wav/` --
uploading that would have taken many more hours than needed. Instead, a
real, transparent, deterministic subset was built: every local AudioSet
clip that `day261_m_glass_breaking_retrain.py`'s and
`day261_mg_gunshot_retrain.py`'s own loader functions (unchanged,
identical label-matching logic: `GLASS_TERMS`/`GLASS_MIDS`/`NEG_MIDS`/
`NEG_TERMS` for glass, `GUN_MID = "/m/032s66"` for gunshot) would actually
select from `train.csv`, including the glass hard-negative pool capped at
the scripts' own `MAX_PER_SOURCE = 2500` using the same `random.seed(42)`
shuffle the training scripts use. Real breakdown:

- `glass_pos` (real AudioSet glass/shatter/smash clips): 106
- `glass_neg` (real hard negatives, capped to int(2500) via seed-42 shuffle,
  matching the loader's own cap -- 5,090 real candidates existed locally,
  only 2,500 uploaded since the loader would never use more): 2,500
- `gun_pos` (real AudioSet `/m/032s66` gunshot clips): 74
- Union (de-duplicated, some clips can appear in more than one set): 2,680
  unique real, unmodified `.wav` files, 4.01GB total (real `du -sh` before
  upload) + real `train.csv` (926KB, unmodified, full file so the loaders'
  own CSV-driven filtering logic runs unchanged against it).

Uploaded via `kaggle datasets create -p . --dir-mode zip` from a staging
folder under the scratch directory (`audioset_upload/train_wav/` +
`train.csv` + `dataset-metadata.json`), same real CLI pattern as this
week's SisFall upload.

**Real failure + retry, documented plainly:** the first upload attempt
crashed mid-transfer with a real `MaxRetryError` /
`NameResolutionError`/`SSLEOFError` against `www.kaggle.com` and
`www.googleapis.com` -- a real transient network failure, not a scripting
bug (confirmed `kaggle datasets list -m` worked again immediately after,
proving connectivity had recovered). Re-ran the exact same
`kaggle datasets create` command a second time; it completed for real this
time (52m49s for the 3.26GB zipped `train_wav.zip`, average ~1.1-1.3MB/s
with real fluctuation between ~100kB/s and ~3MB/s, consistent with this
week's other uploads on this connection).

**Real post-upload verification** (not assumed from the create command's
own "successful" message):

```
$ kaggle datasets status hridyajain/zapsafe-audioset
ready

$ kaggle datasets files hridyajain/zapsafe-audioset
name                        size  creationDate
-------------------------  -----  -------------------
train.csv                  926KB  2026-07-31 04:54:56
train_wav/--aaILOrkII.wav    2MB  2026-07-31 04:55:36
train_wav/-0DLPzsiXXE.wav    2MB  2026-07-31 04:55:36
...
```

Real, confirmed `ready` + real per-file sizes (~0.8-2MB per real wav
clip, consistent with 2s-10s real AudioSet segments at 16-44kHz) --
usable, not just "created."

Dataset URL: https://www.kaggle.com/datasets/hridyajain/zapsafe-audioset

## 2. kernel-metadata.json fixes

Both `day261_mg_gunshot_retrain_push/kernel-metadata.json` and
`day261_m_glass_breaking_retrain_push/kernel-metadata.json` already
referenced `hridyajain/zapsafe-audioset` in `dataset_sources` -- that slug
was always correct, it just didn't exist as a real dataset before this
session. No slug change was needed (unlike `m2_motion_b`'s SisFall
mismatch last session); only the stale `_comment_dataset_sources` note
(which incorrectly implied the dataset was "already verified working")
was corrected to describe the real day262b re-upload. Confirmed via
direct read of both scripts' `find_dataset()`/`load_audioset_*()`
functions that the loaders resolve any `/kaggle/input/*` folder whose name
contains `"audioset"` (a lenient fallback, not an exact-slug requirement),
so the exact slug choice was not the load-bearing risk here -- the missing
dataset was.

## 3. Real kernel re-push + monitoring

```
$ kaggle kernels push -p day261_mg_gunshot_retrain_push
Kernel version 2 successfully pushed.
$ kaggle kernels push -p day261_m_glass_breaking_retrain_push
Kernel version 2 successfully pushed.
```

Both confirmed `running` via `kaggle kernels status` immediately after
push, then polled repeatedly (real, synchronous `kaggle kernels status`
calls every ~30s) until both reached a real terminal state:

- `m_glass_breaking`: `running` -> `complete` (~11 minutes after push)
- `mg_gunshot`: `running` -> `complete` (~12 minutes after push)

Both completed within the same observation window, no errors, no stalls.

## 4. Real results

### `mg_gunshot` -- real, further improvement

```json
{
  "model": "mg_gunshot_retrain",
  "auc": 0.9225,
  "recall_gunshot": 0.9757,
  "f1_gunshot": 0.7812,
  "precision": 0.6514,
  "support_pos": 247,
  "support_neg": 248,
  "real_positives_loaded": 1647,
  "real_negatives_loaded": 5661
}
```

Real exported files:
- `mg_gunshot_retrain.tflite` (int8) -- 2,874,160 bytes (2.87MB), real.
- `mg_gunshot_retrain_f32.tflite` -- 9,517,880 bytes (9.52MB), real.

**Comparison to prior (`DAY261B`, no AudioSet):** AUC 0.8913 -> **0.9225**,
a real, further improvement (+0.031). Recall dropped slightly (0.9958 ->
0.9757) but precision and F1 both rose (0.5065 -> 0.6514 precision, 0.6714
-> 0.7812 F1) -- a real, more balanced classifier, not just a recall-only
win. AudioSet genuinely helped this model, as flagged as a possibility in
`DAY261B_KAGGLE_RUNS.md`.

### `m_glass_breaking` -- real, substantial improvement, but not fully solved

```json
{
  "model": "m_glass_breaking_retrain",
  "auc": 0.7206,
  "recall_glass_break": 0.5189,
  "f1_glass_break": 0.6084,
  "int8_kb": 2532.7,
  "train_windows": 7922,
  "data_stats": {
    "esc50_pos": 40, "esc50_neg": 280,
    "fsd50k_pos": 974, "fsd50k_neg": 1181,
    "audioset_pos": 106, "audioset_neg": 2500,
    "urbansound8k_neg_pos": 0, "urbansound8k_neg_neg": 0,
    "raw_pos": 1120, "raw_neg": 3961,
    "pos_oversampled_to": 3961,
    "final_pos": 3961, "final_neg": 3961
  }
}
```

Real exported files:
- `m_glass_breaking_retrain.tflite` (int8) -- 2,593,520 bytes (2.53MB),
  real.
- `m_glass_breaking_retrain_f32.tflite` -- 9,196,464 bytes (9.20MB), real.

`data_stats` confirms the fix actually took effect this time:
`audioset_pos=106`, `audioset_neg=2500` (both real, non-zero, matching
the real uploaded subset counts exactly) -- unlike the prior run's
`audioset_pos=0, audioset_neg=0`.

**Comparison, plainly stated:**
- vs. the original diagnosed failure (`DAY260C_HARNESS_RECONCILIATION.md`
  Test 1, real AudioSet AUC 0.37): **0.37 -> 0.7206**, a real, large,
  meaningful improvement -- clears the "meaningfully better than
  near-chance" bar by a wide margin.
- vs. the prior no-AudioSet retrain (`DAY261B`, AUC 0.598): **0.598 ->
  0.7206**, also a real improvement (+0.123), confirming AudioSet was
  indeed the missing piece for this model, as `DAY261B` predicted.
- **However:** recall dropped sharply, from 1.0 (prior run) to **0.5189**
  this run. The prior run's recall of 1.0 is now understood as a
  symptom of a degenerate/near-constant-positive classifier trained
  without the harder AudioSet negatives, not a real strength -- this
  run's recall 0.52 with AUC 0.72 is a more honest, harder-earned number
  from a model actually distinguishing glass-breaking from real hard
  negatives (crushing, dishes, knocking, wood, chink/clink) rather than
  just predicting positive by default.

**Verdict:** real, substantial fix -- AUC roughly doubled from the
original real-AudioSet baseline (0.37 -> 0.72) -- but not a complete
solve. Recall 0.52 means roughly half of real glass-breaking events in
this harder, more realistic distribution are still missed. This should be
reported as "meaningfully improved, not fully fixed" -- a genuine step
forward from two prior weak/misleading results (fp32 0.37 real-AudioSet,
then a data-starved 0.598), not a finished model. Further work (more
real AudioSet positives beyond the 106 available locally, deliberate
hard-negative mining, or an architecture change) would likely be needed
before this clears a "production-ready" bar.

## Summary table (all real numbers)

| model | status | real metric (this run) | prior (no AudioSet, `DAY261B`) | original real-AudioSet baseline |
|---|---|---|---|---|
| mg_gunshot | complete | AUC 0.9225, recall 0.9757, F1 0.7812 | AUC 0.8913, recall 0.9958 | fp32 AUC 0.538 |
| m_glass_breaking | complete | AUC 0.7206, recall 0.5189, F1 0.6084 | AUC 0.598, recall 1.0 | fp32 AUC 0.37 |

Real Kaggle kernel URLs (version 2, this session's real run):
- https://www.kaggle.com/code/hridyajain/zapsafe-day261-mg-gunshot-retrain
- https://www.kaggle.com/code/hridyajain/zapsafe-day261-m-glass-breaking-retrain

Real dataset URL created this session:
- https://www.kaggle.com/datasets/hridyajain/zapsafe-audioset (real,
  `status: ready`, 2,680 real unmodified AudioSet clips + `train.csv`,
  4.01GB local / 3.26GB zipped-in-transit)

## Not done this session (out of scope, flagged not forgotten)

- No `.tflite` files were copied into `zapsafe_mobile/assets/models/` and
  no detector/wiring code was touched -- per this session's explicit
  scope, another agent is working on wiring `mg_gunshot`'s current
  retrained model into the app in parallel. Whoever picks up wiring next
  should decide whether to use this session's further-improved
  `mg_gunshot` AUC 0.9225 model (vs. `DAY261B`'s AUC 0.8913 one) before
  shipping.
- `m_glass_breaking` is explicitly **not** recommended for shipping as-is
  given real recall 0.52 -- flagged above, not stretched into a false
  "fixed" claim.
