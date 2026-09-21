# Day 346 — `m3_violence_temporal` is at chance on an independent corpus

> ## ⚠️ SUPERSEDED BY DAY 348 — THE HEADLINE BELOW IS WRONG
>
> Day 348 scored the same shipped model on a **third** violence corpus
> (A-Dataset-for-Automatic-Violence-Detection, 230 violent / 120
> non-violent) and got **AUC 0.9749**, 95% CI [0.9602, 0.9863] — *better*
> than its own RWF val split.
>
> So M3 does **not** fail to generalise. It generalises well to ordinary
> video and collapses specifically on **face-anonymised** video, which is
> what the Dataverse corpus is. The measurements in this file are all
> reproducible and correct; the **conclusion drawn from them was not**,
> because it assumed Dataverse was a representative second corpus when it is
> the outlier.
>
> The "provenance control AUC 1.0000" below is likewise explained rather
> than damning: blurred and unblurred video are trivially distinguishable,
> so a corpus-ID classifier reaching 1.0 is expected and is not evidence of
> a subtle shortcut.
>
> The filename is kept so existing links still resolve.
> See `DAY348_M3_GENERALISES_ANONYMISATION_BREAKS_IT.md`.

Day 344 listed M3 as "0.9176; more training data now identified" and the
plan was to combine that data and retrain. The combining was done. The
result is not an improvement, it is a **correction to what 0.9124 means**.

## 1. The headline

```
shipped model -> RWF val (the split it was measured on)   AUC 0.9126
shipped model -> Dataverse, 2,700 unseen clips            AUC 0.4821
                 bootstrap 95% CI                         [0.4598, 0.5041]
                 verdict                                   CHANCE
```

The 0.9126 matters as much as the 0.4821. The **same scoring code, in the
same run**, reproduced the recorded 0.9124 on RWF val. So the measurement
path is validated and the fault is not in how this was measured.

### It is not a label flip, and it is not a collapse

Both were checked rather than assumed, because a below-chance number is
exactly the shape a bug makes.

```
polarity check   1 - AUC = 0.5179     (an inverted label set would give ~0.95)
output span      0.9951               (a collapsed model gives < 0.05)
score std        0.26
```

```
dataverse violence      mean 0.2650   std 0.2638
dataverse non-violence  mean 0.2798   std 0.2745
```

The model emits confident, well-spread, *identical* score distributions for
both classes. At its shipped threshold of **0.2246** both classes sit on the
line, so it would fire on roughly half of everything.

This is the project's recurring failure mode in its purest form: **right
shape, plausible values, wrong answer, nothing thrown.**

### Not uniform across scenes

```
street violence     n=434   AUC 0.3590      <- actively anti-correlated
classroom violence  n=616   AUC 0.5328
other violence      n=140   AUC 0.6407
```

## 2. The failure is symmetric, and that is the diagnosis

```
                        -> RWF val     -> Dataverse test
RWF-only retrain          0.9144         0.3397
Dataverse-only            0.4636         0.9268
combined                  0.9071         0.9313
```

Each single-corpus model scores ~0.93 on its own data and **below chance**
on the other. This is not one bad model. Neither corpus teaches "violence" —
each teaches what violence looks like *in that source*, and the two sets of
cues point in opposite directions.

## 3. Combining looks like it works. The control says otherwise.

The combined model is good on both (0.9071 RWF / 0.9313 Dataverse), which
read alone would be a clean win. So the provenance control was run: a model
trained on the same features to predict only **which corpus** a clip came
from.

```
corpus-ID AUC   1.0000   (tail split)   /   0.9998   (whole-rar split)
```

The two corpora are **perfectly separable** from these features. A combined
model can therefore identify the source first and apply a source-specific
rule — so "good on both" is two memorised rules, not one general detector,
and there is no reason to expect it to survive a third corpus. A real phone
is a third corpus.

**The combined model is therefore NOT recommended for shipping as an
improvement.** Combining raised the numbers without touching what makes
them meaningless.

### The structural cause

In both corpora, class and source are perfectly confounded **by
construction**: every violent clip lives in a violence folder, every
non-violent clip in a non-violence folder, filmed and processed separately.
Neither dataset can distinguish "violence" from "which folder this came
from". Holding out whole rars does not fix it (0.9470) because source still
tracks class.

## 4. Method notes

**Only the `Blurred` variant was used.** The Dataverse corpus ships every
video twice, Blurred (faces blurred) and Masked (faces patched out). Mixing
them teaches a model to answer "which processing pipeline made this file".
Both classes exist in both variants, so a consistent choice was possible and
no class is defined by its variant:

```
Blurred violence      v_s_b_01..04, v_o_b_01, v_c_b_01..03   1,190 clips
Blurred non-violence  nv_b_01..07                            1,510 clips
```

**Encoding is byte-identical to `train_m3_temporal.py`** — 16 evenly spaced
frames, 224x224 RGB, MobileNetV3Small ImageNet avg-pool. Any drift would
have made the comparison meaningless. Each rar was pulled from its zip,
unpacked, encoded and deleted one at a time (C: had ~10 GB free), caching
per rar so the run resumed after an interruption.

**Two splits were computed, not one.** A *tail* split (last 20% of each rar,
keeping every scene category on both sides) and a *whole-rar* split
(strictly no session overlap). They are reported together; where they
disagree the rar split is the one to believe.

Reproduce: `work/m3_combined/{encode_dataverse,train_m3_combined,
verify_transfer}.py`.

## 5. Status change

| before | after |
|---|---|
| `m3_violence_temporal` 0.9124, more data identified | **at chance (0.4821) on an independent corpus; 0.9124 describes RWF, not violence** |

This is the second headline number this week not to survive a second
dataset — scream v3 went 0.839 -> 0.7675 on Day 345 — and the fourth model
in this project to look fine and be wrong.

## 6. What would actually settle it

The **Masked** variant is deliberately still unused: same content, different
processing. If the combined model holds up there, the shortcut explanation
is wrong. If it collapses, it is confirmed. That is the cheapest decisive
test and it has not been run.

**Nothing here has run on physical hardware.** Every number is held-out
datasets.
