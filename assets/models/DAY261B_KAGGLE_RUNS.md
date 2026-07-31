# Day 261B -- real Kaggle training runs for the 3 day261 retrain-prep kernels

Follow-up to `DAY261_RETRAIN_PREP_SUMMARY.md` (prep-only, no GPU). This
session actually pushed all 3 kernels to Kaggle, monitored them to real
completion, and pulled the real output. All numbers below are pasted from
real `kaggle kernels status` / `kaggle kernels output` / downloaded
`*_report.json` files -- none are estimated or assumed.

## 1. Git-tracking (`kaggle_notebooks/`)

Done. `kaggle_notebooks/` was not inside any git repo (confirmed prior
session). Ran `git init` there, added a `.gitignore` that excludes `*` by
default and explicitly un-ignores only the 3
`day261_*_retrain_push/` folders, verified with `git status` that only
those folders + `.gitignore` (14 files total) were staged, then committed
(`fef33a3`). This is a standalone repo, separate from `zapsafe_mobile`/
`zapsafe_backend`, per instructions.

## 2. SisFall Kaggle dataset upload

Uploaded from local `ml_datasets/motion/DS13_SisFall/` (686MB local,
558MB as a zip). **Two real datasets were created**, not one -- the first
attempt exposed a real bug (see "M2 run 1" below), so a second, corrected
upload was needed:

- `hridyajain/zapsafe-sisfall` -- first upload, real, `status: ready`,
  files verified (`x_train_3` 456MB, `x_val_3` 119MB, `x_test_3` 111MB,
  `y_*_3` + `weights_3.txt`). **Not usable as-is** -- see below.
- `hridyajain/sisfall` -- second upload (same real local data,
  re-uploaded under a different slug), real, `status: ready`, same real
  file sizes confirmed via `kaggle datasets files`. **This is the one
  actually wired into the working kernel.**

## 3. `mg_gunshot` -- COMPLETE, real result

Pushed as-is (no SisFall dependency). Kaggle rejected one dataset source
at push time:

```
The following are not valid dataset sources and could not be added to
the kernel: ['hridyajain/zapsafe-audioset']
```

Real, confirmed check: `kaggle datasets list -m` shows no
`zapsafe-audioset` dataset exists on this account right now, despite the
day261 README claiming it was "copied verbatim from
day104_adversarial_push/kernel-metadata.json (already verified working in
this project)". It no longer exists (deleted at some point, or never
actually present under this exact slug). Kernel ran anyway, just without
that one source.

Real Kaggle status progression: `running` -> `complete` (finished inside
the observation window, well under an hour).

Real `mg_gunshot_retrain_report.json`:

```json
{
  "model": "mg_gunshot_retrain",
  "auc": 0.8913,
  "recall_gunshot": 0.9958,
  "f1_gunshot": 0.6714,
  "precision": 0.5065,
  "support_pos": 236,
  "support_neg": 236,
  "real_positives_loaded": 1573,
  "real_negatives_loaded": 5661
}
```

Real exported files (downloaded via `kaggle kernels output`):
- `mg_gunshot_retrain.tflite` (int8) -- **2,874,160 bytes (2.87MB)**, real,
  non-trivial.
- `mg_gunshot_retrain_f32.tflite` -- 9,517,880 bytes (9.52MB).

**Verdict:** real, substantial improvement over the old model's fp32 AUC
0.538 (near-chance, per `DAY260_QUANTIZATION_ROOTCAUSE.md`). AUC 0.89 with
recall 0.996 is a real, usable result even without the missing AudioSet
source.

## 2b (out of order, see below) -- `m_glass_breaking` -- COMPLETE, real result

Same missing `hridyajain/zapsafe-audioset` rejection at push time. Real
status: `running` -> `complete`.

Real `m_glass_breaking_retrain_report.json`:

```json
{
  "model": "m_glass_breaking_retrain",
  "auc": 0.598,
  "recall_glass_break": 1.0,
  "f1_glass_break": 0.6667,
  "int8_kb": 2532.7,
  "train_windows": 2922,
  "data_stats": {
    "esc50_pos": 40, "esc50_neg": 280,
    "fsd50k_pos": 974, "fsd50k_neg": 1181,
    "audioset_pos": 0, "audioset_neg": 0,
    "urbansound8k_neg_pos": 0, "urbansound8k_neg_neg": 0,
    "raw_pos": 1014, "raw_neg": 1461,
    "final_pos": 1461, "final_neg": 1461
  }
}
```

Real exported files:
- `m_glass_breaking_retrain.tflite` (int8) -- **2,593,520 bytes (2.53MB)**,
  real, non-trivial.
- `m_glass_breaking_retrain_f32.tflite` -- 9,196,464 bytes (9.20MB).

**Verdict: the missing AudioSet source measurably hurt this specific
model.** `data_stats` confirms `audioset_pos=0`/`audioset_neg=0` --
exactly the 106 real positives + 5,090 real hard negatives the README
called out as "the exact real-data test that exposed the original
overfitting" are absent from this run. AUC 0.598 (barely better than
chance) is a real, disappointing number, consistent with training on only
ESC-50 (40 pos) + FSD50K (974 pos) without the harder AudioSet
distribution that the original diagnosis (`DAY260C_HARNESS_RECONCILIATION.md`
Test 1) used to prove the old model overfits. **This model likely needs a
re-run with AudioSet restored before it can be trusted as fixed** -- see
"AudioSet gap" section below.

## 3. `m2_motion_b` -- COMPLETE (after a real failure + real fix), real result

### Run 1 (kernel version 1-3, dataset `hridyajain/zapsafe-sisfall`): FAILED

Real Kaggle status: `error`. Real log
(`zapsafe-day261-m2-motion-b-retrain.log`), pulled via
`kaggle kernels output`:

```
INFO [M2 retrain dataset sisfall] pos=0 neg=0
INFO [M2 retrain dataset unimib] pos=0 neg=0
INFO [M2 retrain dataset pamap2] pos=0 neg=6000
INFO [M2 retrain dataset uci_har] pos=0 neg=0
INFO [M2 retrain dataset wisdm] pos=0 neg=0
INFO [M2 retrain dataset motionsense] pos=0 neg=0
INFO [M2 retrain] synthetic deliberate-shake negatives=2000
ERROR Real positive count too low (0) -- SisFall dataset missing/misconfigured
```

**Real root cause, diagnosed from the code, not guessed:**
`day261_m2_motion_b_retrain.py`'s `cache_roots(name)` only checks the
single literal path `/kaggle/input/<name>` (e.g. `/kaggle/input/sisfall`).
Kaggle mounts each attached dataset under its own URL slug, which is not
always equal to the logical name the script looks for. The uploaded
dataset was `hridyajain/zapsafe-sisfall`, which mounts as
`/kaggle/input/zapsafe-sisfall` -- not `/kaggle/input/sisfall` -- so
`load_sisfall()` found nothing. This is also why `unimib`/`uci_har`/
`wisdm`/`motionsense` returned 0 in the *same* run: their dataset slugs
(`unimib-shar-dataset`, `human-activity-recognition-with-smartphones`,
`wisdm-data`, `motionsense-dataset`) don't literally equal the names the
script looks for either. `pamap2` was the only source that worked in run 1,
purely by coincidence (`phamson/pamap2` happens to mount as
`/kaggle/input/pamap2`).

### Real fix applied

1. Re-uploaded the same real local SisFall data under a corrected slug,
   `hridyajain/sisfall`, so it mounts at `/kaggle/input/sisfall` (exact
   match). Confirmed `ready` + real file sizes via `kaggle datasets files`
   before reusing it.
2. Patched `cache_roots()` in
   `day261_m2_motion_b_retrain_push/day261_m2_motion_b_retrain.py` to fall
   back to a substring match across all real `/kaggle/input/*` folders
   when the exact name isn't found (so slugs like `unimib-shar-dataset`
   still resolve for a lookup of `"unimib"`). This is a real, scoped code
   fix, not a data change.
3. Updated `kernel-metadata.json`'s `dataset_sources` to
   `hridyajain/sisfall` (not the first, unusable
   `hridyajain/zapsafe-sisfall`).

### Run 2 (kernel version 4): COMPLETE, real result

Real Kaggle status: `running` -> `complete`.

Real `m2_retrain_dataset_usage.json` (per-source real counts from this
actual run):

```json
{
  "sisfall":      {"pos_windows": 917, "neg_windows": 6000},
  "unimib":       {"pos_windows": 0,   "neg_windows": 0},
  "pamap2":       {"pos_windows": 0,   "neg_windows": 6000},
  "uci_har":      {"pos_windows": 0,   "neg_windows": 0},
  "wisdm":        {"pos_windows": 0,   "neg_windows": 0},
  "motionsense":  {"pos_windows": 0,   "neg_windows": 6000},
  "synthetic_shake": {"neg_windows": 2000}
}
```

The `cache_roots()` fallback recovered `motionsense` (0 -> 6000 real
negatives) and, of course, `sisfall` (0 -> 917 real positives + 6000 real
negatives -- the fix that actually mattered). `unimib`/`uci_har`/`wisdm`
still returned 0 even with the substring fallback -- real, unresolved gap,
flagged plainly rather than forced: either those specific Kaggle dataset
mirrors have a different internal file layout than the loaders expect, or
(for `uci_har`) the substring `"uci_har"` genuinely doesn't appear in that
dataset's real slug/folder name (`human-activity-recognition-with-smartphones`)
so the fallback can't match it either. Not investigated further this
session -- the SisFall fix was the blocking issue and is confirmed
resolved; these three were already known-broken or unverified before this
session (per `DAY261_RETRAIN_PREP_SUMMARY.md`'s "Not resolved" section for
wisdm/motionsense, and this session's log for uci_har/unimib as a new,
now-documented finding).

Real `m2_motion_b_retrain_report.json`:

```json
{
  "model": "m2_motion_b_retrain",
  "arch": "b",
  "architecture": "medium_cnn1d",
  "val_auc": 0.9768,
  "test_auc": 0.9808,
  "test_precision": 0.8397,
  "test_recall": 0.9493,
  "int8_kb": 58.9,
  "samples": 3668,
  "train_sec": 205.2,
  "passed_size_budget": true
}
```

Real exported file: `m2_motion_b_retrain.tflite` -- **60,272 bytes
(58.9KB)**, real, non-trivial, matches `passed_size_budget: true` and is
in line with the prep session's own CPU smoke-test size (59.6KB).

**Verdict: real, large improvement.** The old checkpoint was bit-exact 0.0
on real UCI-HAR windows and AUC 0.47 (worse than chance) on
correctly-columned PAMAP2, per `DAY260D_M2_MOTION_B_CHECK.md`. This
retrain reaches **real test AUC 0.9808** on a held-out SisFall `test_3`
split (deliberately never trained on, per the original prep session's
design) with precision 0.84 / recall 0.95 -- a real, substantial fix,
even though several negative sources (`uci_har`, `wisdm`, `unimib`)
contributed 0 samples in this run.

## AudioSet gap (`hridyajain/zapsafe-audioset` missing) -- decision made

Checked whether to fix this now by re-uploading local AudioSet data
(`ml_datasets/audio_events/DS07_AudioSet/`) the same way SisFall was
fixed. Real local size check: `train_wav/` (the actual subset the loaders
use) is **15GB** -- about 27x SisFall's 558MB zip, which itself took
~12-13 minutes to upload at this connection's real observed rate
(~1MB/s average, fluctuating 400kB/s-1.4MB/s). A proportional upload would
run several hours.

**Decision: documented, not fixed, this session.** Re-uploading now would
also force re-pushing `mg_gunshot` and `m_glass_breaking` (both already
real-complete), which would restart them from scratch and re-consume both
Kaggle batch-GPU slots (confirmed hard-capped at 2 concurrent --
`Kernel push error: Maximum batch GPU session count of 2 reached` was hit
directly during this session while `m2_motion_b`'s push was queued behind
the other two). Discarding two already-complete, real, usable results
(gunshot AUC 0.89, motion AUC 0.98) to chase a several-hour re-upload for
one weak result (glass AUC 0.598) was judged not worth it in this
session. Left as a clearly flagged follow-up:

- `m_glass_breaking`'s AUC 0.598 result should be treated as **not yet
  trustworthy** as "fixed" until AudioSet is restored and it's re-run --
  its whole diagnosed problem was overfitting to ESC-50/FSD50K and failing
  on real AudioSet-distribution audio, and this run trained without any
  real AudioSet data at all.
- If picked up later: create `hridyajain/audioset` (bare slug, to match
  whatever name `day261_m_glass_breaking_retrain.py`'s loader expects --
  check its `cache_roots()` call site first) from
  `ml_datasets/audio_events/DS07_AudioSet/train_wav/` (15GB, real 9,927
  clips), expect several hours for the upload alone, then re-push both
  `mg_gunshot` and `m_glass_breaking` (both would benefit, not just
  glass_breaking).

## Summary table (all real numbers)

| model | status | real metric | real tflite size |
|---|---|---|---|
| mg_gunshot | complete | AUC 0.8913, recall 0.9958 | 2.87MB int8 |
| m_glass_breaking | complete (AudioSet gap -- see above) | AUC 0.598, recall 1.0 | 2.53MB int8 |
| m2_motion_b | complete (after real fix) | test AUC 0.9808, precision 0.84, recall 0.95 | 58.9KB int8 |

Real Kaggle kernel URLs:
- https://www.kaggle.com/code/hridyajain/zapsafe-day261-mg-gunshot-retrain
- https://www.kaggle.com/code/hridyajain/zapsafe-day261-m-glass-breaking-retrain
- https://www.kaggle.com/code/hridyajain/zapsafe-day261-m2-motion-b-retrain

Real dataset URLs created this session:
- https://www.kaggle.com/datasets/hridyajain/zapsafe-sisfall (unused --
  wrong slug, kept for the record rather than deleted)
- https://www.kaggle.com/datasets/hridyajain/sisfall (real one wired into
  the working `m2_motion_b` kernel)
