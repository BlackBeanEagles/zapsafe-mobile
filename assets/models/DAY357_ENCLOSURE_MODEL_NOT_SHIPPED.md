# Day 357 — the k_confinement replacement passed its bar and is still not shipped

A working replacement for the BROKEN `k_confinement` asset was built,
cleared its pre-registered bar, and is **not being shipped**. The bar was
wrong, and this records why so the same bar is not used again.

## 1. What was built

ExtraSensory (UCSD, free, no signature) supplies what the original lacked:
raw phone IMU **already in m/s²** — magnitude mean 9.751, i.e. gravity —
matching what `sensors_plus` delivers. The original `k_confinement` was
trained on UCI-HAR in *g* and fed m/s², 8× out of distribution.

Since `ELEVATOR` has only 71 examples with the light channel present, the
model was trained and honestly named for what the data supports: **phone
concealed in a pocket or bag**, not "user trapped in a confined space".
The slot rename was agreed before any training.

```
dataset   17,054 windows   IMU [128,6] + light [32,1]   8,054 positive
          16 participants (only Android phones expose the light sensor)
```

## 2. It cleared the bar

```
held-out participants   AUC 0.7530   CI [0.7314, 0.7738]   n = 2,139
light-only control            0.5351   (near chance)
IMU contribution             +0.2179
exported 37.2 KB
```

The pre-registered bar was **AUC ≥ 0.75 with CI lower bound > 0.50**, and
this clears both. The control that was supposed to sink it — is a single
lux value enough? — came back at chance, so the motion signal was real.

On those numbers it would have shipped.

## 3. Why it must not

Sixteen participants is few, and they are badly skewed (three people are 59%
of the rows), so a 25% holdout is **four people**. That prompted a
leave-one-participant-out run, and LOPO says something the single split
cannot:

```
folds evaluable   5 of 16     (11 skipped: only ONE class present)
AUC   median 0.5776   mean 0.7010   min 0.5415   max 0.9160
3 of 5 participants below 0.70
```

Median **0.578** on a genuinely new person. Two people get 0.90+, three get
~0.54. Then the measurement that explains all of it:

```
participants that are 100% one class          11 of 16
AUC of PARTICIPANT IDENTITY alone              0.8804
```

**Knowing who the person is scores 0.88.** Eleven of sixteen participants
never vary — when their light sensor was reading, the phone was *always* in
a pocket or bag. So the label is very nearly a function of the participant
id, and a model can score well by recognising the person rather than the
situation.

The single-split 0.753 is **below** what identity alone achieves. That is
the tell: the model was largely learning who, not what.

## 4. The bar was the mistake, not the model

"AUC ≥ 0.75 on a held-out split" cannot detect a participant-label
confound. It was pre-registered, it was cleared honestly, and it was still
the wrong test. Two checks belong in it for any per-user sensor model:

* **leave-one-participant-out**, reported as a distribution — median, min
  and spread — not one number;
* **identity-alone AUC** as a control. If knowing the person predicts the
  label nearly as well as the model does, the dataset cannot answer the
  question being asked of it.

Both are cheap. Neither was run before today, and the first one only
happened because 16 participants looked too few to trust.

## 5. Status

| | |
|---|---|
| `k_confinement` | **still BROKEN, still disabled, slot still empty** |
| enclosure model | trained, cleared its bar, **not shipped** |
| asset | left in `work/`, never copied into `assets/` |
| blocker, restated | not "no lux data" — ExtraSensory has lux. It is that no corpus labels concealment *within* a participant often enough to separate the situation from the person. |

Nothing in the app changed. A second model that looks like it works is worse
than the gap it would fill.

Reproduce: `work/extrasensory/{build_enclosure,train_enclosure,
lopo_enclosure}.py`.
