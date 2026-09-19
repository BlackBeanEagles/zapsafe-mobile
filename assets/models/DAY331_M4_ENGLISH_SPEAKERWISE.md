# Day 331 — M4 English, re-run speaker-wise: 0.8985, and the pyin decision was Mandarin-only

Two results. The first replaces a retracted number. The second reverses a
design decision that was made on Mandarin and quietly applied to English.

## 1. The honest M4 English number is 0.8985

An earlier English run reported **AUC 0.9807** from a *random* split over 10
speakers, so the same voices appeared on both sides. That was retracted. The
replacement holds out 3 of 10 speakers entirely (`0011`, `0016`, `0017`,
deterministic under `SEED=42`), on the identical pipeline the Mandarin twin
uses so the two are directly comparable.

```
val AUC (seen speakers)        0.9720
HELD-OUT SPEAKER AUC           0.8985   <- the real number
```

**I expected this to land at 0.79–0.82 and said I would distrust anything
above 0.85. It came in at 0.8985, and it survives every check I ran:**

| check | result |
|---|---|
| speaker overlap between train and test | **none** — train `0012-0015, 0018-0020`, test `0011, 0016, 0017` |
| test-set class balance | 510 / 510 |
| rows byte-identical across the split | **0 / 1020** |
| AUC recomputed independently from the shipped `.tflite` | **0.8985**, exact match |
| output span / class separation | 1.0000 / **+0.7900** (vs the Day 330 collapse floors of 0.05) |
| per-held-out-speaker AUC | 0011 **0.9399**, 0016 **0.9528**, 0017 **0.9404** |

The last row matters: no single easy speaker is carrying the pooled number.
It also shows something worth knowing — every individual speaker scores
*higher* (~0.94) than the pooled 0.8985. The model ranks well **within** a
speaker but its score distribution shifts **between** speakers, so pooling
costs ~0.04. Since the app thresholds globally rather than per-caller,
**0.8985 is the number to ship against, not 0.94.**

English simply leaks far less than Mandarin: a seen-to-held-out gap of
**0.073** (0.9720 → 0.8985) against Mandarin's **0.187** (0.9984 → 0.8119).
The retraction of 0.9807 was still correct — that number was leaked — but the
honest replacement is much stronger than projected.

`en_to_zh_transfer_auc = 0.4537` reproduces the existing finding that
prosodic stress does not transfer English → Mandarin.

## 2. The 38-vs-28 feature decision does not hold in English

M4's 0.8985 uses the **38-feature** vector. The app can only compute **28** of
those — the other 10 come from `librosa.pyin`, an RMS series and
autocorrelation, none of which exist in the Dart pipeline.

Day 325 measured what those 10 were worth, decided 0.057 AUC did not justify
a pyin implementation in Dart, and shipped the 28-feature model. That
measurement was made **on Mandarin**. Re-running it on English, same
pipeline, same cached features:

| language | 38 features | 28 features | cost of dropping pyin/RMS/autocorr |
|---|---|---|---|
| Mandarin (M5, shipped) | 0.8119 | 0.7988 | **0.013** |
| English (M4) | **0.8985** | **0.7176** | **0.181** |

**The same 10 features are worth roughly fourteen times more in English.**
In Mandarin they are noise; in English they are the difference between a
strong detector and a marginal one that barely clears the 0.70 ship floor.

A plausible reason, offered as a hypothesis rather than a result: Mandarin is
tonal, so F0 is largely committed to carrying lexical tone and is a poor
channel for emotional prosody. In English F0 is free to carry it. If that is
right the effect is structural, not an artifact of this dataset — but it has
not been tested, and it should not be treated as established.

What is established is narrower and sufficient: **the pyin decision was
correct for Mandarin and is wrong for English, and it was generalized without
being re-measured.**

## What this means

Nothing is shipped by this commit. The decision it surfaces is a product one:

* **Ship the 28-feature English model at 0.7176.** No Dart work. It clears
  the 0.70 floor by 0.018, which is thin — at the 0.5 threshold it gives
  recall 0.537 at precision 0.670.
* **Implement `pyin` in Dart and ship the 38-feature model at 0.8985.** Day
  325 called this "a large, high-risk job" and declined it on 0.057 of
  Mandarin gain. The English number is 0.181, which is a different question
  and probably worth the work.

The shipped `m5_vocal_stress_v2` (Mandarin, 28-feature) is unaffected and
still measures AUC 0.850 on the gate's own held-out-speaker fixture.

Artifacts: `work/m4_english/` (38-feature, `m4_vocal_stress_en_float16.tflite`
+ norm + report) and `work/m4_english_28/` (28-feature). Neither is copied
into `assets/models/` — that waits on the decision above.
