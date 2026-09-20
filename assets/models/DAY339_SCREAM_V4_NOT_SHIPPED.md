# Day 339 — scream v4 is not better than v3, and is not shipped

v4 added SpecAugment (two frequency masks, two time masks, gain jitter),
roughly doubled the same-domain hard-negative caps (Laughter/Cough/Sneeze/
Throat-Clearing/Sigh/Sniff from 900/900/700/600/600/600 to
1800/1800/1400/1200/1200/1200), and trained longer with more patience.

Its own run reported **real held-out AUC 0.8592** against v3's recorded
0.8234, which reads like a clear win. It is not one.

## 1. Different evaluation sets

v4's eval was 132 clips (33 pos / 99 neg); v3's recorded 0.8234 came from a
different draw. Comparing them is meaningless. On the **same** gate fixture
(135 clips, 45 pos / 90 neg):

```
v3  AUC = 0.8390
v4  AUC = 0.8546     delta +0.0156
```

## 2. The delta is inside the noise

Bootstrap over 2,000 resamples of that fixture:

```
mean delta  +0.0151
95% CI      [-0.0287, +0.0617]      <- includes zero
P(v4 > v3)  0.739
```

With 45 positives, a 0.016 AUC difference is not distinguishable from
resampling noise.

## 3. At matched operating points, they are the same model

The tempting number was the shipped threshold: at `t = 0.30`, v4 gives recall
**0.889** against v3's 0.689. That is a 20-point recall gain and it is
entirely **recalibration** — v4's scores sit higher, so 0.30 means something
different on each model.

Comparing them where it is meaningful — same precision, or same recall:

| constraint | v3 | v4 | delta |
|---|---|---|---|
| precision ≥ 0.80 | recall 0.467 | recall 0.444 | **−0.022** |
| precision ≥ 0.70 | recall 0.644 | recall 0.644 | 0.000 |
| precision ≥ 0.66 | recall **0.711** | recall 0.644 | **−0.067** |
| precision ≥ 0.60 | recall 0.778 | recall 0.733 | **−0.044** |
| precision ≥ 0.50 | recall 0.911 | recall 0.956 | +0.044 |
| recall ≥ 0.60 | prec 0.707 | prec 0.771 | +0.064 |
| recall ≥ 0.70 | prec **0.667** | prec 0.615 | **−0.051** |
| recall ≥ 0.80 | prec 0.562 | prec 0.585 | +0.022 |
| recall ≥ 0.89 | prec 0.500 | prec 0.551 | +0.051 |

Deltas swing from −0.067 to +0.064 with **no consistent direction**. At
v3's own shipped operating point (precision ≈ 0.66) v3 is *better*.

**Verdict: the augmentation and the extra hard negatives bought nothing
measurable.** v4 is not shipped.

## 4. What is actually actionable

The scream operating point is tunable on the **existing** model, with no
retrain. v3 on the gate fixture:

```
 thresh   recall  precision
  0.50    0.489    0.759
  0.35    0.644    0.707
  0.30    0.689    0.660   <- shipped
  0.25    0.733    0.623
  0.19    0.778    0.600
  0.15    0.800    0.554
```

If more recall is wanted — and for a scream detector carrying the largest
fusion weight (0.5) it may well be — it is a constant, not a training run.
That is a product decision about how many false alarms are acceptable, so it
is recorded here rather than made.

## 5. Notes for whoever tries v4 again

* The artifact is **misnamed**: the output file is
  `m1_scream_v3_float16.tflite` inside `work/scream_v4/`, because the v4
  script's string substitution covered `scream_classifier_v3` but not the
  `m1_scream_v3_float16` output filename. It is the v4 weights.
* Two real infrastructure improvements came out of the run and are worth
  keeping: feature caching already existed and survived a kill, and
  **checkpoint + epoch-stamped resume** was added after the first attempt
  died at epoch 14 (exit 4, no traceback) and lost 13 epochs of progress.
* That first kill happened while `flutter analyze` and the full test suite
  were running concurrently. Not proven, but the epoch times spiked 91 s →
  250 s beforehand, so heavy concurrent work is the leading suspect.
* If v4 is revisited, the thing to change is probably not augmentation. AUC
  0.84 on 45 real positives with a 95% CI roughly ±0.05 means **the
  evaluation set is too small to detect the improvements worth making**.
  More held-out real screams would buy more than more training tricks.
