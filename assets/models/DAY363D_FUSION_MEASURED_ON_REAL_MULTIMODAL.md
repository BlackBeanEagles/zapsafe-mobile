# Day 363D — M9 finally has real multimodal data. Fusion doesn't help, and something worse turned up.

The 800-video XD-Violence test split downloaded and 400 videos ran through
the **real shipped detectors** — audio through `scream_classifier_v5`,
frames through `mobilenetv3small_encoder` → `m3_violence_temporal_v1`.
400 of 400 processed, zero drops.

This is the first co-occurring multi-modal incident data M9 has ever had.

## 1. Fusion does not beat its best single input

```
scream alone                 0.6408
scene alone                  0.7247
shipped linear 0.5/0.2       0.6951      <- WORSE than scene alone
calibrated LLR sum           0.7247
learned 2-input (5-fold OOF) 0.7224

gain vs best single  -0.0022  [-0.0298, +0.0235]   P(fusion <= best) 0.577
```

A learned fusion, given both inputs and cross-validated, **does not beat
just using the scene detector**. Combining buys nothing here.

**The shipped weights actively make things worse**: 0.6951 against scene
alone at 0.7247. Mixing the weaker detector in at more than twice the weight
of the stronger one degrades the better signal. That is Day 363B's inversion
finding, now confirmed on real co-occurring data rather than inferred from
separate per-detector measurements.

## 2. The important finding: scream is saturated on ordinary media audio

```
scream_classifier_v5 on 200 NON-violent movie/web clips
  > 0.50 :  89.0%        percentiles: p10 0.493
  > 0.70 :  74.0%                     p50 0.898
  > 0.90 :  48.5%                     p90 0.987
```

**Median 0.898 on non-violent audio.** It is not discriminating; it is
nearly always on. On the fused score for non-violent content, **93.8% comes
from scream**.

This is domain-specific, not universal — on AudioSet the same model spans
p5 0.002 to p95 0.973 and reads AUC 0.860. Movie and TV audio specifically
drives it to the ceiling, which is consistent with a detector trained on
clean isolated Freesound clips meeting dense, loud, dramatic mixed audio.

"TV playing nearby" is not an exotic condition.

## 3. What that does to the alert path

`dcs_inference_engine.dart` states the design intent plainly:

> With motion contributing, the reachable maximum becomes `0.5 + 0.3 = 0.80`,
> so the 0.75 alert threshold now requires **two independent modalities to
> agree**, which is what a fusion is for.

With scream sitting at ~0.9 whenever media audio is present, that agreement
is free:

```
scream at the NON-violent median (0.898) + fall firing  ->  0.749   (threshold 0.75)
scream at p55 of non-violent audio     (0.916) + fall   ->  0.758   ALERT
scream at p70 of non-violent audio     (0.950) + fall   ->  0.775   ALERT

share of ordinary non-violent clips where a fall ALONE would trigger: 48.5%
```

The median case lands at **0.749** — one thousandth under the threshold. The
system is sitting exactly on the knife edge, and in roughly half of ordinary
media-audio conditions **a single fall detection escalates on its own**.

Whether that is bad depends on your view of falls — `motion_fall_v2` is the
strongest detector in the project at AUC 0.999, and escalating on a genuine
fall is defensible. What is *not* defensible is that the documented
two-modality protection **does not exist** under a common condition, and
nobody chose that. It happens because one of the two modalities is stuck on.

## 4. What this does not say

**XD-Violence "violent" is not this app's "SOS-worthy."** It is fights,
shootings, riots, abuse, car accidents and explosions in movies and web
video. A violent film scene often has no scream; a person in real danger is
often silent. These AUCs measure transfer to a *related construct in a
different domain*.

Day 360B flagged that risk before any of this was downloaded, and Day 305
trained M3 on XD-Violence and scored 0.4950 against its own 0.5944 baseline.
A weak result here was the expected outcome and is not, by itself, evidence
the detectors are broken.

The saturation finding in §2 is different, and stronger. It does not depend
on the violence labels being the right construct — it is measured on the
**negative** class, and says the scream detector cannot tell ordinary movie
audio from anything else.

**Motion was absent throughout.** XD-Violence has no IMU, so only two of the
three fusion inputs exist. No constant was substituted for motion: a
constant third input trains a model to ignore that input while still
appearing to use it at runtime.

## 5. Decision

**Nothing changed.** Not the weights, not the threshold, not the detector.

Three things are now known that were not:

1. Fusion, as built, does not beat its best single input on real multimodal
   data — so M9's value proposition is unproven, not merely unbuilt.
2. The shipped weights measurably degrade the better signal.
3. The two-modality safety property is defeated ~half the time by scream
   saturation, and a fall alone can escalate.

(3) is the one that matters most and is the narrowest to fix. The candidates
are all product decisions: raise the threshold, calibrate scream so its
output is not pinned near 1.0 on ambient audio, or gate scream's fusion
contribution on it being *distinguishably* above its own ambient baseline.

I am not picking one unilaterally — each changes when the app raises an SOS.

Reproduce: `work/fusion/{xd_extract,xd_fusion_eval}.py`, rows in
`xd_fusion_rows.json`, report in `xd_fusion_eval.json`. 400 videos,
200/200 balanced, zero drops.
