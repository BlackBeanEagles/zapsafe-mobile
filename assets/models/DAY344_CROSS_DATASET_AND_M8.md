# Day 344 — motion_fall_v2 does generalise, and M8 has a named failure

Two results from data found by opening archives that filename searches had
missed. One of them corrects an alarm I raised on my own bug.

## 1. motion_fall_v2 across datasets — 0.9472, and the first number was mine

Day 340 showed its 0.999 was not split luck (mean 0.9901 over six held-out
UniMiB subject sets). But every number it had ever produced came from
**UniMiB, the dataset it was trained on**. Robust across subjects is not the
same as robust across datasets, and this detector carries fusion weight 0.3
and feeds escalation that can now actually fire.

The ASSIST-IoT/SRIPAS multimodal fall dataset
(`F:\zapsafe\multimodal-fall-detection-dataset-v1.0.0.zip`) is a genuinely
independent test — different participants, different hardware, different
sampling rate, different research group, 164,820 labelled fall rows.

```
UniMiB (trained + split-verified)      AUC 0.9901   sep 0.941
ASSIST-IoT TAG (independent)           AUC 0.9472   sep 0.770
                                       t=0.5  recall 0.868  precision 0.194
                                       t=0.9  recall 0.830  precision 0.241
```

**The model holds up.** 0.99 → 0.95 across a dataset boundary is a real but
modest drop, and **no retrain is warranted**.

### The first run said 0.687, and that was a labelling bug

The initial version labelled a window positive if **any** sample in it was a
fall, sliding at 50% overlap. UniMiB crops each window **centred on the
event**. So the first run's positives included windows where the fall clipped
the very edge — cases carrying almost no signal — and recall collapsed to
0.391. Switching to centred windows, one per contiguous fall event, with
negatives kept a full window clear of any fall:

```
edge-inclusive (wrong)   AUC 0.6871   sep 0.303   recall 0.391
centred (UniMiB's rule)  AUC 0.9472   sep 0.770   recall 0.868
```

That is a 0.26 AUC swing from the evaluation convention alone. It was
reported as "motion_fall_v2 does not transfer" before being checked, which
was wrong. **The measurement was broken, not the model.**

### The watch streams are excluded, and that is also a units story

The dataset carries three sensors. Measured raw magnitudes:

```
TAG       median 1.007 g   -> gravity PRESENT
WATCH_R   median 0.128 g   -> gravity REMOVED (linear acceleration)
WATCH_L   median 0.133 g   -> gravity REMOVED
```

UniMiB — and therefore the model — is gravity-present. Running the watches
through a gravity-present conversion fed the model a quantity it has never
seen, and it emitted a **constant** (span 0.0000, recall 1.000 at every
threshold). That is an invalid comparison, not a model result, and the watch
arms are dropped for that reason.

Two conversions were needed for TAG and both have bitten this project
before: **g → m/s²** (×9.80665; skipping it is the same 9.8× error that made
`i_vehicle_crash` score 0.5000) and **125 Hz → 50 Hz** by timestamp
interpolation with a gap guard, not row decimation.

Reproduce: `work/m2_crossdataset/cross_validate_motion.py`.

## 2. M8 with attack-type diversity — a named failure, not an improvement

Zalo is not local; it only ever existed on Kaggle. Credentials were present,
so the corpus was downloaded (2.8 GB, 1,168 videos, 598 live / 570 spoof) and
1,160 extracted cleanly — matching Day 302's "1160/1168 usable" exactly, which
confirms the extractor is faithful.

**A correction to an earlier reading of the extra set.** It was described as
containing real faces (`Selfies: 24`, a "Face" folder of 23). It does not —
those counts were `.jpg` files, and the "Face" folder was
`Textile 3D Face Mask Attack Sample`, misread because of the spaces in its
name. **All 84 videos are attacks**, so this is a single-class addition:

```
Cutout 15 · Textile-3D 23 · Silicone 11 · Latex 10
Replay-mobile 10 · Wrapped-3D 10 · Replay-display 5
```

The value was never balance — it is attack diversity, since a liveness
model's real failure mode is an attack type it has never seen.

### The experiment, and why the obvious one would not answer it

Training with and without the 84 and testing on held-out **Zalo** cannot
work: Zalo contains none of these attack types, so the extra data would be
judged on attacks it was not added to cover. That arm was run anyway for
comparability and moved as predicted — 0.6908 → 0.7048, `+0.0140`, noise.

The real test is **leave-one-attack-type-out**: train a baseline on Zalo
alone (no mask attacks at all) against one on Zalo + the other five families,
then test both on the held-out family plus held-out Zalo live clips.

```
Silicone_mask          n=11   0.1761 → 0.4261   +0.2500
Replay_mobile_attacks  n=10   0.9196 → 0.9830   +0.0634
Textile_3D_mask        n=23   0.5726 → 0.6161   +0.0435
Latex_mask             n=10   0.3563 → 0.3812   +0.0250
Replay_display_attacks n= 5   0.8232 → 0.8143   -0.0089
Cutout_attacks         n=15   0.6470 → 0.6286   -0.0185
Wrapped_3D_paper_mask  n=10   0.7384 → 0.5598   -0.1786

mean +0.0251   helped 4 of 7
```

**This does not demonstrate that diversity helps.** 4/7 is a coin flip and
the spread (−0.179 to +0.250) dwarfs the mean. With 5–23 videos per family
the individual deltas are mostly noise — the same standard that showed scream
v4's +0.0156 sat inside its confidence interval.

### What it does demonstrate, which is more useful

Look at the **baselines**: a Zalo-trained model scores **0.1761 on silicone
masks** and **0.3563 on latex**. Both are far below chance — systematic
inversion. It confidently labels physical mask attacks as **live**.

Adding five other mask families lifted silicone from 0.176 to 0.426, a real
move, but still not above chance.

So M8's status changes from "blocked at 0.752" to a **named, measured failure
mode**: *Zalo-trained M8 is actively wrong on physical mask attacks, and 84
videos are not enough to fix it.* The fix is mask-attack data at scale, not a
better head.

**Not shipped.** It does not beat the incumbent on the comparable number and
the leave-one-out result does not support a claim of improvement.

## 3. Archive sweep — what filename searches had missed

Opening archives rather than matching names found ~250 GB previously
uninspected. Two corrections worth recording:

* **`train_crowd1-9.tar` (~100 GB) is not crowd-panic audio.** It is
  **Golos**, the Russian ASR corpus — it sits beside `golos_opus.tar` and
  `train_farfield.tar`, where "crowd" means *crowd-sourced* and "farfield"
  means far-field mics. Ruled out before being claimed as relevant.
* **`dataverse_files*.zip` (F:, up to 10.9 GB) is a real Violence Detection
  corpus** (violence / non-violence, some blurred variants). Directly
  relevant to M3, which currently trains on a single violence dataset.

Reproduce the inventory: `work/archive_scan.py`.

## Standing position

| model | status |
|---|---|
| `motion_fall_v2` | **0.9472 cross-dataset** — generalises, no retrain needed |
| `m3_violence_temporal` | 0.9176; more training data now identified |
| `scream_classifier_v3` | 0.839; eval set of 45 positives is the blocker |
| `m4_vocal_stress_en_38` | ~0.80 across splits |
| `m5_vocal_stress_v2` | ~0.63 across splits |
| M8 | named failure on physical masks; needs data at scale |
| M7 / k_confinement / M9 | still blocked on data that does not exist |

**Nothing has run on physical hardware.** Every number here is held-out
datasets; `flutter test` has no native TFLite interpreter.
