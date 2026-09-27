# Day 364 — correcting Day 363D. The scream detector is not saturated.

Day 363D reported, as its headline finding, that `scream_classifier_v5` has
a median score of **0.898 on non-violent media audio**, concluded it was
saturated, and stated that this defeats the DCS two-modality rule so that
**"a fall alone escalates in 48.5% of ordinary media audio."**

**That is wrong.** The number was measured the wrong way, and the conclusion
drawn from it does not survive measuring it correctly.

## The error

That 0.898 is a **maximum over every 3 s window of a whole video**.
XD-Violence test videos have a median duration of 75 s, so at a 1.5 s hop
that is a max over ~50 draws; the longest video gives 226. It was compared
against AudioSet screams at 0.834, which was a **single window**.

A maximum over 50 samples is far above the median of one sample, for any
distribution. The two numbers were never comparable.

**The DCS engine scores one window at a time** — `infer()` takes a single
`AudioFeatures` frame — so the per-window distribution is the only one that
describes what the fusion sees.

## The correct measurement

9,706 individual 3 s windows across 100 non-violent XD-Violence videos:

```
PER-WINDOW (what the fusion actually sees)
  p10  0.0157     p50  0.1991     p90  0.7631
  p25  0.0518     p75  0.4999     p99  0.9758     mean 0.3009

MAX-OVER-VIDEO (what Day 363D reported)
  median 0.8799
```

Median **0.199**, not 0.898. The detector has a healthy dynamic range across
almost the whole [0,1] interval.

How much of the original number was the max operator, by resampling the same
per-window pool:

```
max over  1 random window  -> median 0.2161
max over  5                -> median 0.7119
max over 10                -> median 0.8376
max over 25                -> median 0.9289
max over 50                -> median 0.9673
```

The reported 0.898 sits right where "max over ~15 windows" lands. **It was
the maximum operator, essentially in full.**

## What that does to the safety claim

```
ambient per-window median 0.1991 -> 0.0995 of the 0.75 threshold
                       + fall (0.30) = 0.3995   -> NO ALERT
```

`DCSScoreWatcher` also requires `requiredConsecutiveWindows = 3`, which the
original analysis ignored entirely. Measuring actual runs over 7,519 windows
in 60 videos — windows overlap at a 1.5 s hop, so they are correlated and
the rate cannot be obtained by cubing a per-window probability:

```
audio alone, no motion:               0 of 7,399 triplets   0 of 60 videos
sustained fall + ambient media audio: 65 of 7,399 (0.878%)  10 of 60 (16.7%)
```

**Ambient audio alone never triggers**, in any window triplet of any video.
The two-modality property holds.

The residual is much narrower than claimed: if `motion_fall_v2` sits at ~1.0
for three consecutive windows *and* media audio is playing, about 17% of
media clips contain at least one crossing. But a **sustained** fall signal
is not noise — it is the project's strongest detector (AUC 0.999) asserting
a fall for 4.5 s. Escalating there is close to the intended behaviour.

## Status of the claims

| Day 363D said | corrected |
|---|---|
| ambient median **0.898**, detector saturated | **0.199** per window; not saturated |
| ambient scores higher than real screams | artifact of max-vs-single comparison |
| two-modality rule defeated | **holds** — audio alone never fires |
| "fall alone escalates 48.5% of the time" | **retracted.** Needs a *sustained* fall; ~17% of media clips then contain one crossing |
| 93.8% of the fused score comes from scream | artifact of the same max |

**Day 363D's other findings stand**, because they did not depend on the
windowing: the fusion does not beat its best single input (0.7224 learned
vs 0.7247 scene alone), and the shipped 0.5/0.2 weights are worse than using
scene alone (0.6951). Those are rank comparisons on identical rows.

## The recalibration this started as

The work began as "recalibrate scream so its output is not pinned near 1.0".
The isotonic calibration was fitted, failed its own pre-registered ship rule,
and is **not shipped** — correctly, because it was solving a problem that
does not exist. A detector with p10 0.016 and p90 0.763 does not need its
dynamic range restored.

The ship rule also exposed a real property worth recording: isotonic
regression is only *weakly* monotone, and its flat segments merge ranks, so
it changed AUC by up to 0.0077. A calibration that is supposed to be
ranking-preserving should be checked for that rather than assumed.

## Why this happened

The max-over-windows choice was made in `xd_extract.py` for a good reason —
it matches the shipped rolling buffer for *deciding whether a clip contains
an event*. It is wrong for *characterising an ambient baseline*, and it was
carried from one use to the other without re-checking. Day 361 made almost
this exact mistake in the opposite direction, feeding a 2.0 s model 3.0 s of
audio, and that one was caught before publishing. This one was not.

Reproduce: `work/fusion/{scream_perwindow,scream_recalibrate}.py`, reports
in the matching `.json`.
