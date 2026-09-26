# Day 359B — gunshot goes permissive too, and my prediction was wrong

After glass, I wrote that gunshot and scream would be "a close A/B rather
than a landslide" because they read 0.807 and 0.828 against glass's 0.684.
Gunshot was another landslide, and the reason I was wrong is worth recording.

## 1. Why the prediction was wrong

I compared against **the gate's numbers**, which are measured on a
subsample: `n=311` for gunshot, `n=392` for glass. On the full FSD50K eval
fixture (2,226 clips) the shipped model reads **0.7294**, not 0.807.

Taking a subsampled figure as the baseline for a decision was the error.
The gate subsamples for speed, which is fine for a health check and wrong
for an A/B.

## 2. Gunshot result

Trained on CC0/CC-BY FSD50K dev only (320 positives), scored on the gate's
FSD50K eval fixture — disjoint split, identical rows, both models through
their real inference path:

```
shipped mg_gunshot_retrain (NC)   0.7294
permissive v2                     0.8463 mean  (0.8384 / 0.8515 / 0.8489)
```

**+0.117**, worst seed +0.109. And the asset goes from **4,677 KB to
59.7 KB** — a 78x reduction that removes the largest model in the bundle.

## 3. The operating point matters more than the AUC here

At the **actual shipped threshold of 0.70**:

```
              recall   precision   fires
v1 (NC)       0.896    0.078       69.4%
v2            0.612    0.421        8.8%
```

v1 fired on **69% of all audio** at 7.8% precision — 92% of its alerts were
false. A signal that is on two-thirds of the time carries almost no
information into DCS fusion; it is closer to a stuck switch than a detector.

v2 gives 5.4x the precision at an eighth of the firing rate.

**This is a real behaviour change and not just a swap.** Recall drops from
0.896 to 0.612. If catching every gunshot matters more than alert fatigue,
t=0.13 reproduces v1's recall (0.903) at slightly better precision (0.091) —
but that restores the constant-firing behaviour, which is what made v1
useless. The threshold constant stays at 0.70 and the full curve is in
`gunshot_calibration.json` so the choice can be revisited deliberately.

Gate: **AUC 0.810**, and `sep` rises from **0.1487 to 0.3856** — that
separation is exactly what the always-firing model lacked.

## 4. Licence

`mg_gunshot_v2` trains on **CC0 + CC BY FSD50K only**. UrbanSound8K
(CC BY-NC 3.0) and AudioSet (YouTube-sourced audio) are gone.

The NC list is now **three models**, down from five this morning:
`h_aggressive_v5`, `m5_vocal_stress_v3`, `scream_classifier_v5`.

CC BY requires **attribution** — the app owes FSD50K contributors a credit
somewhere a user can reach. That obligation now covers two shipped models.

## 5. A sed that went too far, caught before commit

Renaming `mg_gunshot_retrain` -> `mg_gunshot_v2` across the tree hit things
it should not have:

* `tools/model_exports/mg_gunshot_retrain_dynrange.tflite` — a **binary**,
  which sed corrupts silently;
* `tools/__pycache__/*.pyc` — likewise;
* doc comments recording **history**: "Day 262 added gunshot
  (mg_gunshot_retrain)", "`day261_mg_gunshot_retrain.py`", and
  "`mg_gunshot_retrain` emitted a constant 0.3633 for every input".

That last category is the dangerous one: renaming those would attribute v1's
broken int8 behaviour to v2, which never had it. All were reverted; only
live asset references were kept.

## 6. Scream is the one that should be close

`scream_classifier_v5` reads 0.828 and trains on five corpora
(VocalAffectBench MIT, FSD50K, AudioSet, ASVP-ESD, ESC-50). The permissive
FSD50K subset has **218 Screaming positives** — an order of magnitude less
data than the shipped model saw.

Its preprocessing is also different in every respect from glass and gunshot:
22.05 kHz (not 16), 128x131 single-channel, pad/truncate to 131 frames, no
`np.resize`. Using the mel-image path there would give a confident wrong
number rather than an error.

That A/B is running. Losing it is the expected outcome and would be reported
as a licence-for-accuracy trade on the flagship detector, not shipped.

## 7. Status

| | |
|---|---|
| `mg_gunshot_v2` | 59.7 KB (was 4,677 KB), gate AUC 0.810, sep 0.3856 |
| `m_glass_breaking_v4` | 59.6 KB (was 207.2 KB), gate AUC 0.815 |
| NC models | **3**, down from 5 |
| threshold | gunshot unchanged at 0.70; behaviour change documented |
| attribution owed | FSD50K contributors, for two shipped models |

881 tests pass; analyze unchanged at 57.

Reproduce: `work/permissive/{build_train_gunshot,cal_gunshot,
build_train_scream}.py`.
