# Day 349 — all three prosodic models are at chance on natural speech

`m4_vocal_stress_en_38` and `m5_vocal_stress_v2` were the last shipped
detectors never tested across a corpus boundary. Both now have been, and
both fail the same way `h_aggressive_speech` did on Day 347.

## 1. Three models, three corpora, one number

```
                          in-corpus (held-out speakers)   natural speech
h_aggressive_speech_v1        0.8442  (RAVDESS)            0.4780  MELD
m4_vocal_stress_en_38         0.8321  (ESD English)        0.4813  MELD
m5_vocal_stress_v2            0.7988  (ESD Mandarin)       0.4865  EmotionTalk
```

```
m4  CI [0.4572, 0.5043]   separation -0.0126   NO EFFECT SIZE   n=3047
m5  CI [0.4674, 0.5041]   separation -0.0253   NO EFFECT SIZE   n=4000
```

Neither is collapsed (span 1.0000 for both) and neither is label-flipped
(1−AUC 0.5187 and 0.5135, not ~0.95). Both emit confident, full-range
scores that carry no information about the label.

**All three land within 0.009 of each other, at chance.** That is no longer
three separate findings; it is one property of the approach.

## 2. Held-out speaker is not held-out corpus

This is the part worth internalising, because these models did the harder
validation and it still did not help.

m5's own report records the gap it *did* catch: **0.9984 on seen speakers
vs 0.7988 on held-out speakers.** That is a real and well-run control —
three of ten speakers held out entirely, no leakage. m4's 0.8321 is the
same protocol.

And it predicted nothing. Both models sit at 0.48 the moment the recording
situation changes. Speaker identity was never the confound; **corpus** was.

## 3. What the models were actually trained on

ESD: ten speakers per language reading a fixed script in a studio, with
emotion produced on cue. Labels here are `stressed = angry/sad`,
`calm = neutral/happy`.

MELD is *Friends* dialogue — laugh tracks, music beds, overlapping
speakers, wildly varying mic distance. EmotionTalk is Mandarin
conversation with five annotators per clip; the majority label was used and
the 2,897 clips without a majority were **dropped rather than forced**,
since assigning a label to genuinely ambiguous audio would make the corpus
look harder than it is and understate the model.

Language was matched deliberately — English model against MELD, Mandarin
model against EmotionTalk. Day 343 already measured EN→Mandarin prosodic
transfer at 0.4537, so crossing languages would have tested a different and
already-answered question.

## 4. The feature trap that had to be avoided

m4's input is `[1,38]` and so is h_aggressive's, but they are **not the
same 38 features**:

```
                  pitch source        frame / hop
h_aggressive      librosa.pyin        2048 / 512
m4                yin_lite (plain YIN)  512 / 256
```

Feeding m4 the librosa variant reports it DEAD at a constant 1.0 — a domain
mismatch dressed as a dead model, and the reason `fixture_for` in the gate
routes these by filename rather than shape. The extractor used here is
copied verbatim from `work/m5_zh_38/featurise_zh.py::work()`. m5 takes the
same vector restricted to `AVAIL = range(7,33) + [36,37]`, the 28 features
Dart can compute.

## 5. Blast radius: nothing live

`vocalStressPipelineProvider` is defined in `live_detection_providers.dart`
and has **no consumers anywhere in `lib/`**. The DCS engine does not read
vocal stress either. Riverpod will not instantiate a provider nothing
watches, so neither model affects any user-visible behaviour today.

That is the same position `h_aggressive` was in, and it is why this lands
usefully rather than as a regression: the finding arrives before anyone
wires it, not after.

## 6. The fix is known, measured, and the data is on disk

Day 348 already demonstrated it for h_aggressive:

```
h_aggressive v1   acted 0.8442   natural 0.4780
h_aggressive v2b  acted 0.8096   natural 0.6661
```

Adding natural speech to training moved it from chance to 0.67, at a cost
of 0.035 on the acted number. The ceiling for these features on natural
speech is 0.6832, so v2b captured 97.5% of what is available.

Both remaining models have their corpus ready:

* **m4** → MELD train split, untouched (only test+dev were read here).
* **m5** → EmotionTalk, 16,353 majority-labelled Mandarin clips, of which
  only 4,000 were used for this evaluation.

Expect ~0.65–0.68, not 0.83. The in-corpus numbers were never real.

## 7. Status

| | before | after |
|---|---|---|
| `m4_vocal_stress_en_38` | 0.8321, untested cross-corpus | **0.4813 — chance on natural speech** |
| `m5_vocal_stress_v2` | 0.7988, untested cross-corpus | **0.4865 — chance on natural speech** |

Neither asset was changed and neither pipeline was touched. What changed is
what the recorded numbers mean.

Reproduce: `work/m4_m5_crosscorpus/evaluate.py`.

**Nothing here has run on physical hardware.**
