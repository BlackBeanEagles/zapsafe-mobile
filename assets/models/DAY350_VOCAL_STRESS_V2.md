# Day 350 — m4 and m5 retrained on natural speech; both ship

Day 349 measured both shipped vocal-stress models at chance the moment the
recording situation changed. Both are now retrained and shipped, and the
Mandarin one produced a finding that invalidates a design decision made on
Day 325.

## 1. Result

```
        v1 (ESD only)                v2 (ESD + natural speech)
m4      acted 0.8321                 acted 0.7738
        natural 0.4813  CHANCE       natural 0.6235   CI [0.6006, 0.6577]
m5      acted 0.7988                 acted 0.7873
        natural 0.4865  CHANCE       natural 0.7810   CI [0.7646, 0.7973]
```

Both clear the bars set before training: **natural >= 0.60 with a bootstrap
CI excluding 0.50, and acted >= 0.70.** The second bar is what rejected the
first m5 attempt (see §3) — a model that reaches natural speech by giving
away acted speech has moved the failure, not fixed it.

m4's natural figure is on the **identical 3,047 MELD test+dev rows** v1
scored 0.4813 on. m5's is on speaker-disjoint held-out EmotionTalk.

Training data: m4 = ESD English 3,400 + MELD train 8,106. m5 = ESD Mandarin
3,400 + EmotionTalk 14,000.

## 2. The 28-feature decision was wrong, and only off-ESD evidence shows it

`m5_vocal_stress_v2` shipped with **28** of its 38 features. The recorded
reasoning had two parts, and both have since failed:

**"Dart cannot compute the other 10."** True in Day 325. `yin_pitch.dart`
(plain YIN, no HMM) and `VocalStressFeatures.compose38()` were written later
for the English variant, and `kFullFeatureDim` is 38. Nothing had to be
added — the capability was already there and the rationale was simply stale.

**"The 10 carry nothing"** — measured as all-38 0.7986 vs these-28 0.7988,
the 10 alone 0.5620. That measurement was correct *and* misleading, because
it was taken entirely **within ESD**. Retraining Mandarin on ESD +
EmotionTalk both ways:

```
28 features   acted 0.6294   natural 0.7716   <- fails the 0.70 acted floor
38 features   acted 0.7873   natural 0.7810   <- holds both
```

The 28-feature model **cannot do acted and natural speech at once.** The
38-feature one can.

Why: pitch, shimmer and HNR barely vary across ten actors reading one script
in a booth, so inside ESD they look like noise. They carry real information
precisely when the recording situation changes — which is the case the model
exists for. **A feature-ablation run on a single corpus can only measure
what that corpus varies.**

## 3. Two errors caught during the run, both by controls

**The first m5 attempt failed the acted floor and was not shipped.** With no
corpus weighting, natural speech was 82% of the training rows (11,157
EmotionTalk vs 2,380 ESD) and acted collapsed 0.7988 -> 0.5989. A pooled
`class_weight` cannot see that, because the imbalance is between *corpora*,
not classes. Fixed with sample weights giving each corpus equal total
weight, class-balanced within each: acted recovered to 0.6294, then to
0.7873 once the full 38 features were used.

**The EmotionTalk split was leaking and the number was inflated.**
Featurisation stored the conversation-group prefix (`G00001`) as the
grouping key and the first run held out whole groups. But the json carries a
real `speaker_id`, and **10 of 15 speakers recur across groups** — holding
out `G00003` while training on `G00001` leaves speaker 02 on both sides.
Natural AUC fell 0.7969 -> 0.7804 once split by real speaker.

The leak was caught by noticing m5's natural Mandarin number was *higher*
than m4's natural English one, which had no reason to be true.

Recovering the speakers needed no re-featurisation: `collect_etalk()` walks
the tar in order, nothing was dropped (14,000 collected, 14,000 featurised),
so replaying the key sequence from the json alone aligns 1:1 with the cached
rows. The alignment was **asserted** — the replayed label sequence had to
equal the cached `y` exactly or the script refused to write.

## 4. What to trust and what not to

* **m5's natural number rests on 4 held-out speakers of 15.** That is a
  narrower estimate than m4's, which holds out 256 of 1,023 MELD dialogues.
  EmotionTalk is 15 speakers in 13 conversations; a speaker-disjoint split
  is the strongest available, not a strong one.
* **Run-to-run variance is about ±0.02** on these small heads. The figures
  above belong to the exported artifacts; a rerun will not reproduce them to
  four decimals.
* The gate's numbers are **in-corpus ESD** (m4 0.752, m5 0.766) and are a
  regression check, not the cross-corpus result.

## 5. Gate routing had to change, and getting it wrong is silent

Three shipped models now share `[1,38]` with **two different feature
definitions**:

```
yin_lite (plain YIN, frame 512 / hop 256)    m4_vocal_stress_v2_38
                                             m5_vocal_stress_v2_38
librosa.pyin (frame 2048 / hop 512)          h_aggressive_speech_v1
```

Feeding a yin_lite model the librosa fixture reports it **DEAD at a constant
1.0** — a domain mismatch dressed as a dead model. `fixture_for` routes by
filename and the list must be kept current.

A second fixture was added for the same reason: the first Day 350 gate run
scored the **Mandarin** model against ESD **English** and reported 0.709.
Day 343 measured EN->Mandarin prosodic transfer at 0.4537, so that number
measures language transfer, not the model. `real_prosodic_38_yin_zh()` now
serves m5 from ESD Mandarin held-out speakers.

## 6. Shipped

| | |
|---|---|
| `m4_vocal_stress_v2_38.tflite` | 28.8 KB, + `_norm.json` (**mandatory**) |
| `m5_vocal_stress_v2_38.tflite` | 28.9 KB, + `_norm.json` (**mandatory**) |
| removed | `m4_vocal_stress_en_38.*`, `m5_vocal_stress_v2.*` — unreferenced |

Thresholds unchanged (m5 0.20, m4 0.50). 850 tests pass; analyze unchanged
at 57.

Still not a live path: `vocalStressPipelineProvider` has no consumers in
`lib/` and the DCS engine does not read vocal stress.

Reproduce: `work/m4_m5_v2/{featurise_natural,recover_speakers,train_v2}.py`.

**Nothing here has run on physical hardware.**
