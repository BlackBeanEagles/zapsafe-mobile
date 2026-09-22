# Day 349 — the glass/gunshot retrain is rejected, and why that matters

Both retrains were run to completion and **neither ships**. The corpus that
looked like free improvement is a trap, and the only reason that was caught
is that the ship rule was fixed before training started.

## 1. Result

```
glass    incumbent  this-corpus eval 0.6266   FSD50K 0.7819
         v2         this-corpus eval 0.9205   FSD50K 0.7015
                    FSD50K delta -0.0805  CI [-0.1385, -0.0241]  P(better) 0.004

gunshot  incumbent  this-corpus eval 0.6612   FSD50K 0.8071
         v2         this-corpus eval 0.8922   FSD50K 0.4503
                    FSD50K delta -0.3568  CI [-0.4572, -0.2559]  P(better) 0.000
```

Both new models look **dramatically better** on the corpus they trained on —
+0.29 and +0.23 — and are **significantly worse** on independent data. The
gunshot retrain is at chance on FSD50K while reporting 0.8922 on its own
eval.

`retrained glass from 0.63 to 0.92` is a defensible sentence from the
numbers in front of you. It would also have shipped a worse detector.

## 2. The rule that caught it, written down before training

Training on a corpus makes that corpus's eval split domain-matched, so a
good number there proves little. So the decision was pre-committed to
**FSD50K**, which neither the incumbents nor the new models train on, with
a bootstrap CI on the *difference* required to exclude zero.

That is the same standard that rejected scream v4 (+0.0156, CI [-0.0287,
+0.0617]) and confirmed scream v5 (+0.0609, CI [+0.0394, +0.0816]). The
script also prints its own diagnosis when the pattern appears:

```
NOTE: v2 wins on this corpus's own eval and NOT on FSD50K
      -> it learned the corpus, not the event
```

## 3. What is wrong with the corpus

`final_data_wav_split.zip` — 5,639 clips over 12 classes with ready-made
train/val/eval splits and genuinely hard negatives (`dishes_pot_pan` for
glass, `slam`/`drill`/`doorbell` for gunshot). On paper it is exactly right.

The tell is that the **incumbents also do badly on it** (0.6266, 0.6612)
while doing well on FSD50K. That is the signature of a confound in the data
rather than a weakness in the models: a detector that generalises scores
mediocre-to-poor on confounded data, while one fitted to the confound excels
there and collapses everywhere else.

The most likely mechanism is per-class recording provenance. Freesound class
folders typically draw from a handful of uploaders, so microphone, room,
sample rate history and loudness processing correlate almost perfectly with
the class label. A model can learn "which uploader" and get the class for
free.

This was not proven here, and is stated as the likely cause rather than a
finding. What *is* established is that the corpus cannot be trained on for
these two detectors.

## 4. One correction

These were listed as two separate finds — `final_data_wav_split.zip` and
`processed_freesound_wav.zip`. They are the **same 5,639 clips**: the second
merges train+val into "dev" and has a byte-identical eval split (62 glass,
179 gunshot). Only one corpus was ever there.

## 5. Status: unchanged, deliberately

| | |
|---|---|
| `m_glass_breaking_v3` | stays — FSD50K **0.7819** |
| `mg_gunshot_retrain` | stays — FSD50K **0.8071** |
| `final_data_wav_split` | **not usable for training** these detectors |

Both incumbents keep their shipped thresholds (glass 0.22, gunshot 0.70).
Nothing changed in the app.

Reproduce: `work/event_audio_v2/train_event.py`.

## 6. The wider pattern this belongs to

Day 349 measured four things and three of them moved a recorded number the
wrong way:

```
glass v2      in-corpus 0.9205  ->  independent 0.7015
gunshot v2    in-corpus 0.8922  ->  independent 0.4503
m4 stress     in-corpus 0.8321  ->  independent 0.4813   (CHANCE)
```

Every single one looked good on the data nearest to it. **In-corpus
evaluation has now failed as a predictor of independent performance in
every case this project has tested.** The habit worth keeping is not "run
more retrains" — it is "hold out a corpus nobody in the training chose, and
decide on that number before you see it."

**Nothing here has run on physical hardware.**
