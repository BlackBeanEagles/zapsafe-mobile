# Day 338 — every vocal-stress number in this project came from one split

Training the Mandarin 38-feature variant produced **AUC 0.4286 with a
negative separation**. Chasing that produced a finding much larger than the
model it started with.

## 1. The Mandarin-38 result was not the bug

0.4286 below chance, consistent across three seeds, looks like a broken
pipeline. The control says otherwise: the **28 features contain no `yin_lite`
output at all**, so running them on the same data isolates data from
features.

| feature set | this run (yin_lite pitch) | Day 332 (librosa pitch) |
|---|---|---|
| 28 — no pitch of any kind | **0.5115** | 0.5221 |
| 33 — + shimmer/hnr/rms | 0.4336 | 0.5585 |
| 33p — + pitch | 0.5349 | 0.5448 |
| 38 — everything | 0.4799 | 0.5895 |

The 28-feature control reproduces (0.5115 against 0.5221), so **the data and
labels are sound**. But every configuration sits between 0.43 and 0.53, and
the *same* feature set moves 0.5585 → 0.4336 between runs. That is noise
around no signal, not a feature effect. Reporting this as "yin_lite hurts
Mandarin" would have been wrong.

## 2. The real finding: single-split numbers

If Mandarin scores ~0.52 here but m5 shipped at **0.7988**, the difference is
the split. So m5's exact shipped configuration was run across six different
held-out speaker triples on the same data:

```
m5 (Mandarin, 28 features) — the SHIPPED config
  0001/0006/0007   0.7886   <- the split 0.7988 was reported on
  0001/0002/0003   0.7683
  0008/0009/0010   0.6020
  0003/0004/0008   0.5992
  0002/0006/0009   0.5243
  0005/0007/0010   0.5060
  mean 0.6314   sd 0.1100
```

**0.7988 is the best of six, not a typical one.** On `0005/0007/0010` the
same model is at chance. Expected performance on an unseen Mandarin speaker
is **~0.63 ± 0.11**, and that is the number that should have been shipped.

Since the English model was reported by the identical method from a single
split, it owed the same check:

```
m4 (English, 38 features) — the SHIPPED config
  0011/0016/0017   0.8959   <- the split 0.8321 was reported on
  0015/0017/0020   0.8658
  0012/0016/0019   0.8344
  0018/0019/0020   0.7977
  0013/0014/0018   0.7041
  0011/0012/0013   0.6958
  mean 0.7990   sd 0.0761

m4's data through the OLD 28-feature path, for comparison
  mean 0.5925   sd 0.0994   min 0.4852   max 0.7987
```

**m4 holds up.** Its reported split was also its best, but the worst of six
is **0.6958** — it never approaches chance, unlike m5. Expected performance
on an unseen English speaker is **~0.80 ± 0.08**.

And the 38-feature work is better supported than it was: **+0.207 averaged
over six splits** (0.7990 against 0.5925), where Day 336 claimed +0.137 from
a single one. The Day 332b/333 Dart work — `extendedFeatures` and `YinPitch`
— is worth more than the number that justified it.

Note the 28-feature path's apparent 0.7987 on `0011/0016/0017` against a mean
of 0.5925: that split flatters *whatever* is run on it. It is the same split
both m4 and the earlier English numbers were reported from.

## 3. What this does and does not say about the gate

My first reaction was that the gate fixture was at fault, because
`real_prosodic_28` hardcodes `HELD_OUT = {'0001','0006','0007'}` — the lucky
triple. **That is wrong, and worth stating so the fixture does not get
"fixed" into something incorrect.**

Those three speakers are exactly the ones m5 was trained *without*. Any other
speaker is training data, and scoring a model on its own training data is the
leak this project has documented repeatedly. The gate is measuring the right
thing.

The problem is upstream: **the model was selected and reported on one split.**
The gate faithfully reports that model's held-out number; what nobody
attached to it was the ±0.11 speaker-sampling variance around it. So
`m5 AUC=0.850` in the gate is not wrong — it is unrepresentative, and it
agrees with the training report because both describe the same draw.

The durable fix is at training time: report cross-validated mean and spread,
not one held-out triple. Applied here retrospectively rather than by
retraining, because the shipped assets are what they are and the honest move
is to record what they actually do.

## 4. Consequences

**Mandarin-38 is not shipped.** There is no evidence it helps — Mandarin
shows no reliable signal with any feature set on any split tried. The tonal
explanation offered on Day 331 (F0 committed to lexical tone) remains
plausible but is not established, and should not be repeated as though it
were.

**The locale wiring stands, with corrected numbers.** `zh` → m5 and
everything else → m4 is still the right routing: m5 at ~0.63 is weak but
above chance, and no better Mandarin model exists. What changes is what is
claimed for it.

| model | shipped/reported | honest expectation on a new speaker |
|---|---|---|
| `m4_vocal_stress_en_38` | 0.8321 | **~0.80 ± 0.08** |
| `m5_vocal_stress_v2` | 0.7988 (gate 0.850) | **~0.63 ± 0.11** |

**Every other single-split number in this project inherits the same
caveat**, so `motion_fall_v2` was checked the same way.

## 5. Day 340 — motion_fall_v2 is NOT split luck

Same method, six different held-out subject sets of 7 from 30:

```
  seed 42  [6, 8, 17, 23, 25, 26, 30]   0.9986   <- the split it shipped from
  seed  2  [8, 13, 16, 17, 19, 25, 27]  0.9978
  seed  4  [1, 2, 8, 9, 12, 26, 29]     0.9976
  seed  5  [3, 8, 10, 12, 20, 24, 25]   0.9980
  seed  3  [4, 13, 18, 21, 24, 27, 28]  0.9764
  seed  1  [2, 4, 8, 16, 17, 22, 29]    0.9724
  mean 0.9901   sd 0.0112   min 0.9724
```

The worst of six is **0.9724**, and the spread is **ten times tighter** than
m5's (sd 0.0112 against 0.1100). The shipped split was the best, as it was
for every model checked — but here that distinction is worth 0.008, not 0.16.

So the flagship detector's number survives the scrutiny that broke m5's. The
difference is not luck in the checking; it is that `motion_fall_v2` has a
0.941 class separation against m5's 0.201. **A large separation is what makes
a number robust to which subjects you hold out** — that is the property worth
looking for, and the gate already prints it on every line.

Reproduce with `tools/day340_motion_split_check.py`.

What remains unchecked: `scream_classifier_v3`, `mg_gunshot_retrain`,
`h_aggressive_speech_v1` and `m3_violence_temporal`. M3's separation is 0.506
and scream's 0.373, so both sit closer to motion than to m5 on the property
that matters.
