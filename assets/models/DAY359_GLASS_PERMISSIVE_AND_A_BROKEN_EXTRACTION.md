# Day 359 — glass: licence cleared, AUC 0.684 → 0.866, and 70% of FSD50K was missing

The licence task turned up a data bug that had been silently capping every
FSD50K number in this project, and fixing it improved a shipped safety
detector by more than any model change this month.

## 1. The discovery: 69.9% of FSD50K on disk was empty

FSD50K ships as a spanned archive (`.z01`–`.z05` + `.zip`, 17.1 GB). The
extracted copy on disk was **28,618 zero-byte files out of 40,966**. Every
count taken from it — including the glass training set — had been running on
~30% of the corpus without anyone noticing, because zero-byte files still
satisfy `os.path.exists`.

Rejoining the parts produced a file Python refused:

```
BadZipFile: zipfiles that span multiple disks are not supported
```

The End-of-Central-Directory keeps its disk-number fields, so the central
directory is unusable. But **local file headers are self-describing** — each
carries its own signature, method, sizes and filename immediately before its
data — so the clips were recovered by scanning for `PK\x03\x04` and skipping
the directory entirely:

```
entries scanned 40,967 | written 3,703 of 3,703 | CRC failures 0
```

## 2. Why the glass detector was weak

Its own training report:

```
train_pos 92   train_neg 1709   eval_real_pos 13
chosen_threshold 0.8754   (selected on those 13 positives)
```

Ninety-two positive examples. With the extraction repaired, the **CC0/CC-BY
subset alone has 872** — 9.5× more, and not one NC clip in it.

## 3. What shipped

Trained on permissive FSD50K dev only; scored on the gate's FSD50K **eval**
fixture, a disjoint split, with both models run through their real inference
path on identical rows:

```
shipped m_glass_breaking_v3 (NC)   0.6838
permissive v4                      0.8633 mean   seeds 0.8682 / 0.8563 / 0.8655
```

At the **actual shipped threshold of 0.22** — not the recorded 0.8754, which
Day 346C had already rejected as chosen on 13 positives:

```
              recall   precision   fires
v3 (NC)       0.813    0.154       63.2%
v4            0.910    0.226       48.3%
```

Better recall, better precision, and it fires *less often*. Strictly
dominant, so **the threshold does not change** — 0.22 stands and the upgrade
carries no behaviour surprise.

Gate, through the shipped `.tflite`: **AUC 0.815** (was 0.782),
**rec@0.5 0.789** (was 0.570), **59.6 KB** (was 207.2 KB).

If alarm fatigue ever matters more than coverage, 0.45 gives recall 0.813 —
matching v3 exactly — at precision 0.318 and half the firing rate. That is a
product decision and the full curve is in `glass_calibration.json`.

## 4. Licence

`m_glass_breaking_v4` trains on **CC0 + CC BY FSD50K only**. UrbanSound8K
(CC BY-NC 3.0) and the Freesound-derived set are gone.

The NC list drops from five models to four:
`h_aggressive_v5`, `m5_vocal_stress_v3`, `mg_gunshot_retrain`,
`scream_classifier_v5`.

**CC BY requires attribution.** The app now owes FSD50K contributors a credit
somewhere a user can reach. That is a real product task, not a formality —
and it is far cheaper than NC, which forbids commercial use outright.

## 5. What this opens

The same permissive subset exists for the other two audio-event models:

```
gunshot   320 permissive positives (of 348)
scream    218 permissive positives (of 254)
```

Both are now extracted and non-empty. Whether they can match their shipped
models is an open A/B, not a promise — `mg_gunshot_retrain` reads 0.807 and
`scream_classifier_v5` 0.828, both much stronger starting points than glass's
0.684, so neither is likely to be the landslide this was.

`m5_vocal_stress_v3` (EmotionTalk, CC BY-NC-SA) and `h_aggressive_v5`
(TESS, RAVDESS) have **no permissive replacement** — emotional-speech corpora
are essentially all NC.

## 6. Status

| | |
|---|---|
| asset | `m_glass_breaking_v4.tflite`, 59.6 KB (v3 deleted, was 207.2 KB) |
| gate | **0.815**, ok — up from 0.782 |
| recall @0.22 | **0.910**, up from 0.813, while firing less |
| licence | **CC0 + CC BY only** — off the NC list |
| threshold | unchanged at 0.22 |

881 tests pass; analyze unchanged at 57.

Reproduce: `work/permissive/{build_permissive_sets,extract_by_headers,
build_glass_permissive,train_glass_permissive,calibrate_glass}.py`.
