# Day 347 — `h_aggressive_speech` is at chance on natural speech

Day 318 measured this model carefully and concluded the asset was good and
"the gap is wiring, not the model". The first half stands. The second half
does not survive a second corpus.

```
RAVDESS (acted, studio, Day 318)    AUC 0.8442
MELD (natural TV dialogue)          AUC 0.4780    delta -0.3662
                                    95% CI [0.4516, 0.5037]  ->  CHANCE
                                    separation -0.0275       ->  NO EFFECT SIZE
```

2,911 clips — 661 aggressive (anger/fear/disgust) vs 2,250 calm
(neutral/joy). Not a label flip (`1-AUC = 0.5220`, an inversion would give
~0.95). Not a collapse (span 0.9961). It emits confident, well-spread scores
that carry no information about the label.

## The precision curve is the clearest signature

```
t=0.70  recall 0.433  precision 0.215
t=0.60  recall 0.501  precision 0.210
t=0.50  recall 0.590  precision 0.213
t=0.40  recall 0.666  precision 0.218
t=0.30  recall 0.747  precision 0.224
t=0.20  recall 0.808  precision 0.223      base rate 0.227
```

Precision equals the base rate at **every** threshold. That is the
definition of a classifier with no signal, and it is more legible than the
AUC.

## The control: it is the model, not the corpus

MELD is *Friends* dialogue — laugh tracks, music beds, overlapping speakers,
short utterances, crowd-sourced utterance-level labels. If these 38 features
simply could not separate MELD, the result would be a statement about the
corpus and nothing could be concluded.

So classifiers were trained on the **same cached 38-dim features**, 5-fold
cross-validated:

```
MELD-trained logistic regression   0.6832
MELD-trained GBDT                  0.6742
shipped h_aggressive_speech_v1     0.4780
```

The features carry real signal on MELD. **The shipped model specifically
fails to transfer**, and it does not merely underperform the ceiling — it
reaches chance while a model fitted to this corpus reaches 0.68.

This is the same discipline as Day 346's provenance control: a cross-corpus
number is worth only what its control says.

## Why this was the one worth running

`scream_classifier_v1` claimed precision 0.9424 / recall 0.9529 and its own
docstring later recorded that it "had learned acted studio emotion, not
screaming" — it had been trained and evaluated on acted RAVDESS/CREMA-D
speech. `h_aggressive_speech`'s entire evidence base was **160 RAVDESS
clips: 24 actors in a booth reading two fixed sentences**. Same corpus
family, same failure.

It now joins the pattern Day 346 established:

| model | in-corpus | cross-corpus | |
|---|---|---|---|
| `motion_fall_v2` | 0.9901 | **0.9472** | holds |
| `mg_gunshot_retrain` | 0.9225 | **0.8071** | holds |
| `scream_classifier_v5` | — | **0.8284** | holds |
| `m_glass_breaking_v3` | — | **0.7819** | holds |
| `m3_violence_temporal` | 0.9126 | **0.4821** | chance |
| **`h_aggressive_speech_v1`** | **0.8442** | **0.4780** | **chance** |

## Blast radius: zero running code

`h_aggressive_speech_v1` is **not wired**. It has no detector class, no
pipeline, no provider and no DCS fusion weight. `model_registry.dart` is its
only reference, and that entry states plainly that "Phase B (inference
wiring) is STILL NOT DONE".

So nothing regresses and nothing needs gating. **The value of this result is
that it arrives before Phase B, not after.**

The registry entry told whoever picked up Phase B that the model was good
and only the plumbing was missing. That plumbing is substantial — the native
layer emits 15 per-frame scalars, while the day90 extractor needs f0
mean/std/jitter via pyin pitch tracking, RMS-derived shimmer and HNR, and
spectral rolloff, none of which exist in Dart or the native layer today.
That is days of work, and on this evidence it would have been spent wiring
up a detector that reads natural speech at chance.

## What would make this shippable

Not wiring. A **retrain on natural speech**, with the corpus doing the work:
MELD's own train split is available and untouched by this evaluation (only
`test` and `dev` were read, deliberately, so the train split stays clean for
exactly this). A model fitted to it reaches 0.68 with these features, which
is a real ceiling to aim at and well short of the 0.84 the acted corpus
advertised.

Whether aggressive-speech detection is worth that is a product question. It
should be answered against **0.68**, not 0.84.

Reproduce: `work/h_aggressive_crosscorpus/{evaluate_meld,
control_meld_separable}.py`.

## Method note

The extractor is lifted verbatim from `real_prosodic_38()` in
`tools/verify_shipped_models.py`, which mirrors `day90_h_aggressive_speech.py`
with training-time augmentation removed — the same code path that produced
the 0.8442 being compared against. `h_aggressive_speech_v1_norm.json` is
applied; skipping it is not a small error, since Day 318 measured raw
features at 0.5214.

The asset is **int8**, and feeding it float32 raises outright rather than
mis-scoring silently — the good failure mode, and worth noting because it
means quantisation must be applied and reversed with the tensor's own
scale/zero-point (0.0506 / -26 in, 0.00390625 / -128 out).

MELD audio is already 16 kHz mono, so no resampling was introduced on top of
the domain shift. `sadness` and `surprise` are dropped rather than mapped:
day90 assigns them to neither class, and inventing a mapping would be
choosing the answer.

**Nothing here has run on physical hardware.**
