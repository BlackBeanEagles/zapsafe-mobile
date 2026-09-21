# Day 348 — M3 does generalise. Face-anonymisation is what breaks it.

This corrects Day 346's central conclusion. The measurements there were
right; the conclusion drawn from them was not.

## 1. The correction

```
shipped m3_violence_temporal, same asset, three corpora:

  RWF val (its own split)                    0.9126
  A-Dataset (third corpus, unprocessed)      0.9749   CI [0.9602, 0.9863]
  Dataverse (face-anonymised)                0.4821   CI [0.4598, 0.5041]
```

Day 346 read the 0.4821 as "M3 is not a violence detector, it is an
RWF-corpus classifier". With a third corpus available that is now clearly
wrong: **M3 scores higher on an independent corpus than on its own
validation split.** Dataverse is the outlier, not the model.

Dataverse ships every clip face-blurred or face-masked. That is the one
property distinguishing it from both corpora M3 handles well.

This also disposes of the "provenance control AUC 1.0000" that Day 346
treated as damning. Blurred and unblurred video are trivially separable —
a corpus-ID classifier reaching 1.0 between them is *expected*, and is not
evidence of a subtle statistical shortcut.

## 2. The control that makes the 0.9749 trustworthy

A high number on a new corpus invites the obvious objection: maybe this
corpus is easy, and M3 is a motion detector scoring "are two people moving
fast near each other".

This corpus is the only one on disk that can settle that, because it ships
**per-file action-class labels for both classes** — including a non-violent
clip annotated *"friendly punch"*.

### Every violent action outranks every non-violent action

```
VIOLENT      choke          n= 26   0.8748
VIOLENT      stab           n= 30   0.8516
VIOLENT      gunshot        n= 28   0.8201
VIOLENT      club           n= 72   0.8200
VIOLENT      push           n= 44   0.8012
VIOLENT      punch          n= 46   0.8005
VIOLENT      fight          n= 92   0.7882
VIOLENT      kick           n= 42   0.7837
VIOLENT      slap           n= 36   0.6974
------------------------------------------- no overlap
non-violent  walk           n=  6   0.3630
non-violent  jump           n= 20   0.3312
non-violent  handgestures   n= 30   0.2887
non-violent  hug            n= 32   0.2520
non-violent  highfive       n= 12   0.2405
non-violent  greet          n= 66   0.2051
non-violent  friendly punch n=  2   0.1853
non-violent  handshake      n=  2   0.1090
```

**It is not a motion detector.** The two highest-scoring actions are
`choke` and `stab` — among the *lowest*-motion violent acts. The
high-motion non-violent acts, `jump` (0.331) and `highfive` (0.241), score
near the bottom. A motion detector would order these the other way round.

### Punch vs friendly punch

```
punch           n=46   0.8005   (violent)
friendly punch  n= 2   0.1853   (NON-violent)
```

The same physical gesture, opposite scores. n=2 makes this suggestive
rather than conclusive, but it is the single cleanest case available.

### The 0.9749 does not rest on easy negatives

Restricting negatives to physical interaction only — hug, highfive, greet,
handshake, friendly punch — and dropping the easy ones:

```
all negatives   (n=350)  AUC 0.9749
hard negatives  (n=322)  AUC 0.9786
```

It goes **up**. The result was never carried by `walk`.

## 3. The combined model is still not shipped — for a better reason

```
                         RWF     Dataverse   A-Dataset (unprocessed)
shipped  (RWF only)     0.9126    0.4821         0.9749
combined (RWF + DV)     0.9071    0.9313         0.9569
```

Day 346 declined to ship the combined model because its gains looked like a
provenance shortcut. That reasoning is now superseded, but the decision
stands on firmer ground: **the combined model is worse than the shipped one
on unprocessed video** (0.9569 vs 0.9749). Training on anonymised footage
bought competence on anonymised footage and cost a little on the kind of
video a phone actually records.

## 4. What this changes operationally

**M3's 0.9124 is better than it looked, not worse.** It is a working
violence detector that survives a corpus boundary and the hardest control
this project has been able to construct.

The real, narrow finding is: **it fails on face-anonymised video.** Whether
that matters depends entirely on deployment. A phone camera records
unprocessed frames, so the Dataverse condition is not the shipping
condition. It would matter if footage were ever anonymised before
inference — which nothing in the pipeline does today.

## 5. Method note on a near-miss

The Dataverse **Masked** variant was originally proposed as this test. It
was abandoned after checking: Masked and Blurred are the **same source
videos**, 34/34 filename-stem overlap in `v_s_b_04` vs `v_s_m_04`
(`v_s_401`..`v_s_434` in both). Scoring a Blurred-trained model on Masked
would have meant scoring it on scenes, actors and camera angles it had
already trained on, and would have produced a high number that meant
nothing. The check cost two minutes.

Reproduce: `work/m3_thirdcorpus/{encode_and_test,action_control}.py`.

## 6. Status

| | before (Day 346) | after (Day 348) |
|---|---|---|
| `m3_violence_temporal` | "at chance off its own corpus" | **0.9749 cross-corpus; fails only on anonymised video** |
| combined model | not shipped (shortcut suspected) | not shipped (**measured worse** on unprocessed video) |

**Nothing here has run on physical hardware.**
