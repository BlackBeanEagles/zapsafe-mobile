# Day 362 — "ExtraSensory is too thin" was wrong. The model still fails, for a better reason.

Day 360 refused the phone-concealment model (the honest replacement for
`k_confinement`) and explained it this way:

> The design worked — identity leakage fell by two thirds and the IMU is
> clearly doing the work. It still fails … **the approach is sound and the
> dataset is too thin.** That says exactly what new data would need to look
> like: more participants who genuinely vary.

That was based on **5 participants**. It was the wrong diagnosis, and the
recommendation that followed from it was wrong too.

## Why there were only 5

`build_enclosure.py` needs per-window **raw** accelerometer and gyro files
from `ExtraSensory.raw_measurements.*.zip`. Raw coverage is what capped the
build at 16 participants, of whom 5 had both classes.

The **per-UUID feature archive covers all 60 users** and was sitting on the
same disk the whole time. It carries precomputed statistics over the same
sensors. "Too thin" was a statement about the raw measurement archives, not
about ExtraSensory.

Using only what a phone can actually compute from `sensors_plus` —
`raw_acc` (26), `proc_gyro` (26), `lf_measurements` (light) — and excluding
watch, location, audio and magnetometer features as undeployable:

```
                        Day 360        Day 362
participants               16             60
with BOTH classes           5             19
rows                   ~11,462         72,252
positives               2,462          15,508
```

## The model is better than Day 360 thought

```
LOPO over 19 participants
  median  0.8442      (5-participant build: 0.7741)
  mean    0.8117
  min     0.4282
  max     0.9910
```

**Median 0.844.** For most people this works well — 16 of 19 folds clear
0.65, nine of them clear 0.85. Day 360 under-sold it.

## And it fails anyway, on the pre-registered rule

```
SHIP: median >= 0.75, worst fold >= 0.65, identity-alone <= 0.60
  median     0.8442   PASS
  worst      0.4282   FAIL
  identity   0.6857   FAIL   (was 0.6087 on 5 participants)
```

Identity got *worse*, not better: 19 participants have base rates from 5% to
74%, so knowing who the person is carries more label information than it did
across the 5.

## The failing folds are real, not small-n noise

This is the part that changes the recommendation. A 0.428 fold on 65
positives could easily be an unstable estimate. A per-fold bootstrap says
it is not:

```
4E98F91F   AUC 0.4282  [0.362, 0.498]   pos=   65
86A4F379   AUC 0.6189  [0.584, 0.655]   pos=  368
B9724848   AUC 0.5970  [0.568, 0.626]   pos= 1585
```

**Every interval excludes 0.5.** These are not unmeasured participants —
the model is measurably wrong for them. `B9724848` has 1,585 positives, so
there is no shortage of data for that person. And for `4E98F91F` the model
is **anti-predictive**: the interval sits entirely *below* chance, meaning
it would be better to flip its output than to use it.

## What this changes

Day 360 said: *more participants who genuinely vary.* **That would not fix
it.** Going from 5 to 19 participants moved the median up and left the
failure exactly where it was, and the failure is now shown to be systematic
per-person rather than a sampling artifact. More ExtraSensory data buys a
better median and the same 3-in-19 hole.

For a safety feature, "measurably wrong for 16% of users, inverted for
one of them" is disqualifying regardless of how good the median is. A user
does not experience the median.

| | Day 360 | Day 362 |
|---|---|---|
| participants | 5 | **19** |
| LOPO median | 0.7741 | **0.8442** |
| worst fold | 0.5723 | 0.4282, **CI excludes chance** |
| identity-alone | 0.6087 | 0.6857 |
| diagnosis | dataset too thin | **per-person heterogeneity; more data won't fix it** |
| what would help | more participants | **per-user calibration** |

## The path that is left, and it is not a data path

The model works for most people and is wrong for specific individuals in a
stable way. That is the signature of something that needs **per-user
adaptation** rather than a bigger corpus: a short on-device calibration, or
a personalised threshold, or refusing to run for users whose held-out
behaviour does not match.

That is a product decision with real cost — it means the feature cannot
simply be switched on for everyone — and it is not attempted here.

**`k_confinement` stays disabled** (`kDualInputModelsDisabled`), the gate
stays red, and the red is still the intended steady state. What changed is
that the reason is now correct.

Reproduce: `work/extrasensory/{enclosure_all60,fold_confidence}.py`,
reports in the matching `.json`. The feature matrix is cached at
`enclosure_all60.npz` so the LOPO can be re-run without re-reading 225 MB.

### One note on method

The first version of `enclosure_all60.py` required every feature column to
be non-NaN and kept **zero** of ~300,000 rows. ExtraSensory features are
sparsely populated — a sensor that was off for a minute leaves its whole
block blank. NaNs are now preserved (HistGradientBoosting routes them
natively) and the linear control imputes with the *training* fold's median
so nothing leaks from the held-out participant.
