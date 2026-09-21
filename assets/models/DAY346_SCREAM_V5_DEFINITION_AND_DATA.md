# Day 346 — scream v5: the defect was the label definition, not the data

Day 345 measured `scream_classifier_v3` at **0.7675** on a real eval set
(not the 0.839 on record) and found v4 significantly *worse* at 0.7522. The
plan that followed was to find more data. That plan was half wrong: the
largest single gain here came from **deleting 789 rows**.

## 1. Result

```
                          FSD50K eval   AudioSet held-out
v3 (shipped)                 0.7675        0.8222
arm A  v3 recipe             0.7673        0.8292     control
arm B  crying removed        0.8107        0.8742
arm C  + FSD50K dev          0.8050        0.9131
arm D  both                  0.8284        0.9069     <- best
```

```
arm D vs v3   FSD50K +0.0609   95% CI [+0.0394, +0.0816]   P(better) 1.000
              AudioSet +0.0848
float16 tflite 0.8284 vs keras 0.8284  -- quantisation cost nothing
```

## 2. The control is why the rest can be believed

Arm A retrains from scratch on v3's own data recipe and lands on
**0.7673 vs v3's 0.7675** — a delta of 0.0002, CI [-0.0180, +0.0181].

So the pipeline has no drift, and every difference in B/C/D is attributable
to the change being tested rather than to run-to-run variance or a
featurisation mismatch. The v3 baseline in this run also reproduced Day
345's 0.7675 exactly through an independently re-written featuriser.

A second thing falls out of arm A: **SpecAugment bought nothing.** Arm A has
augmentation that v3 never had and still lands on v3's number. It was one of
the changes v4 bundled in, and it is not what moved anything.

## 3. Change 1 — stop training on a broader target than we score

v3 and v4 both trained `Crying` (700), `Pant` (44) and `Moan` (45) as
**positives**. The eval set counts only Screaming/Shout/Yell as positive. So
roughly half of the positive mass was teaching the model to fire on
something its own scoring calls not-a-scream.

Removing those 789 rows and changing nothing else is worth **+0.0432** on
FSD50K and **+0.0520** on AudioSet. No new data, no extra training time.

That it improves on **both** eval sets is what makes it trustworthy —
AudioSet is where no arm has a domain advantage.

## 4. Change 2 — the hard negatives that were missing

FSD50K dev contributed 441 unique scream-family positives, but the more
valuable part was **Cheering (217)**, **Crowd (282)** and **Applause (400)**.

Every negative v3 and v4 had was an individual, close-mic vocalisation — a
cough, a laugh, a sneeze. Nothing taught either model the difference between
a scream and a stadium, which is the confusion that matters for a phone in a
public place.

**The domain-advantage worry did not materialise.** Arms C and D train on
FSD50K dev and are scored on FSD50K eval, so some gain could have been the
domain match. It wasn't: arm C, *with* the advantage, does **not** beat arm
B on FSD50K (0.8050 vs 0.8107). Its win is on AudioSet (0.9131), where it
has no edge at all. The new data's value is the negatives generalising, not
the corpus matching.

**The two changes stack.** Arm D beats both single-change arms on FSD50K,
so they address different failures.

## 5. Operating points — the part that decides shipping

```
                    recall   precision
v3 @ t=0.20 (ships)  0.711     0.304
v5-D @ t=0.30        0.822     0.324
v5-D @ t=0.20        0.843     0.282
```

At **t=0.30 v5-D strictly dominates** v3's shipped operating point — more
recall *and* more precision. That is a gain on both axes, not a trade.

Keeping **t=0.20** instead buys a further +0.021 recall for −0.042
precision, which for a personal-safety detector is arguably the right side
to err on. That is a product decision, not one the AUCs settle.

Precision ~0.32 is low in absolute terms, but this eval set is deliberately
adversarial: 287 positives against 1,477 negatives that are speech, chatter,
laughter and singing. It is a worst-case precision, not a field estimate.

### A stale number to fix either way

`ScreamDetectorV2`'s docstring justifies t=0.20 with "recall 0.778,
precision 0.614". Those come from the 135-clip AudioSet fixture Day 345
retired. v3's real curve at t=0.20 is **recall 0.711, precision 0.304**.
That docstring is wrong regardless of whether v5 ships.

## 6. What was tried and did not work

* **v4's doubled hard-negative caps** — measured worse (0.7522), reverted.
  v5 uses v3's caps.
* **SpecAugment alone** — no effect (arm A).
* **TUT Rare Sound Events**, proposed as scream training data, is neither:
  its classes are babycry/glassbreak/gunshot, and Day 298 established it is
  licensed Non-Commercial. Not used.

## 7. Method note — no 17.4 GB join

FSD50K dev ships as `.z01`..`.z05` + `.zip` and C: had ~6 GB free, so Day
345's concatenate-and-patch approach was unavailable. It was also
unnecessary: zip local file headers are self-describing, so each part was
scanned **in place on D:** and only the wanted clips written out. 4,796 of
4,797 recovered; one straddled a part boundary and is counted rather than
written truncated.

Reproduce: `work/scream_v5/{extract_dev,train_scream_v5}.py`.

## 8. Status

| | |
|---|---|
| model | `work/scream_v5/m1_scream_v5_float16.tflite`, 205.8 KB |
| FSD50K eval | **0.8284** (v3 0.7675) |
| AudioSet | **0.9069** (v3 0.8222) |
| quantisation | verified lossless |
| shipped | **not yet** — pending threshold decision |

**Nothing here has run on physical hardware.**
