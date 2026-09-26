# Day 361D — scream's full NC cost, measured. Still not paid.

Two items were open after Day 361B:

1. FSD50K's ~15% CC BY-NC per-clip slice sits inside the scream feature
   cache, which stores a source tag but no filenames.
2. Scream needs ~360 permissive non-vocal negatives to replace what ESC-50
   was contributing.

Both are now closed, together, with a number.

## The idea: replace the diversity, don't just delete the corpus

Day 361B found that dropping ESC-50 — 360 negatives, 2.4% of rows, zero
positives — cost **0.0195**. The reading was that ESC-50 supplies negative
*diversity* nothing else does: FSD50K negatives are Freesound uploads,
ASVP-ESD and VocalAffectBench are both vocal.

That suggests replacing it rather than absorbing the loss.

### Why not DEMAND

DEMAND was the obvious candidate: 16 environments — kitchen, car, metro,
traffic, office, park — far better matched to a phone's deployment domain
than ESC-50's curated clips. Its licence was read **from the source PDF**
rather than assumed, after the EmotionTalk mistake:

> "the audio recordings and the MATLAB scripts are licensed under the
> Creative Commons Attribution-ShareAlike 3.0 Unported License"

No NC clause, so commercially usable. But ShareAlike requires that a work
which "builds upon" it be distributed under the same licence, and whether a
trained model is a derivative of its training audio is genuinely unsettled.
For a commercial app that swaps an NC problem for a copyleft one.
**Rejected — not a clean win, and not a call to make without a lawyer.**

### What was used instead

scream v5 drew 4,257 negatives from FSD50K dev. FSD50K dev holds ~35,000
permissive clips (CC0 14,959 + CC BY 20,017), so **~33,000 permissive clips
were never touched**. The replacement did not need downloading — it needed
*selecting*, and selecting for label spread, since spread is the property
ESC-50 was providing.

```
eligible CC0/CC-BY, not already used, not scream-adjacent   11,511 clips
sampled round-robin across labels                            2,500 clips
labels spanned                                                  181
```

Scream-adjacent classes (Screaming, Shout, Yell, Battle_cry,
Children_shouting, Crying, Speech, Singing …) were excluded from the
negative pool. A mislabelled positive hiding in the negatives is worse than
no extra data.

**Arm C** = drop ESC-50, drop the whole v5 FSD50K block (it cannot be
filtered in place — no filenames), re-extract from the CC0/CC-BY lists
(218 pos / 2,300 neg), add the 2,500 fresh negatives. Result: 14,709 rows
against arm A's 14,749 — very nearly a like-for-like swap, with **both NC
exposures gone**.

## It worked at the A/B recipe, and that turned out not to mean much

```
arm A   shipped composition, ESC-50 + unfiltered FSD50K    0.7823
arm B   ESC-50 dropped, nothing replacing it               0.7628
arm C   fully NC-free + 2,500 fresh CC0/CC-BY negatives    0.7900   (+0.0077)
```

Every arm C seed beat arm A's mean. Replacing the diversity clearly works
where deleting it did not.

**But that recipe is 12 epochs at batch 64, and the shipped model is trained
at 30 epochs, batch 32.** The two architectures are identical layer for
layer, so the real recipe could simply be applied to arm C's data.

## At the real recipe it loses

```
shipped scream_classifier_v5 (NC)     0.8284
arm C, 30 epochs / batch 32   mean    0.8192   min 0.8171   max 0.8220
                              delta  -0.0091   worst seed  -0.0113
```

Ship rule, fixed before running — *worst seed ≥ shipped, on the same
fixture* — **FAILS**. All three seeds land below.

**The A/B's verdict did not survive the real recipe.** The short schedule
under-trains, which compresses the difference between data compositions; at
30 epochs the shipped composition pulls ahead. Arm C's +0.0077 was an
artifact of the proxy.

This is the pre-registered ship rule doing its job. On the A/B alone the
obvious move was to ship arm C — it was NC-free *and* better. It is neither.

## A number on record is not comparable, and should stop being quoted

`scream_classifier_v5` is recorded at **0.9057**. On this fixture it reads
**0.8284**. The 0.9057 came from a different script's own eval load. That is
why the incumbent was re-measured here through its real `.tflite` path on
the identical rows rather than compared against the number on file — the
precise mistake Day 352 made and had to withdraw.

Neither figure describes real-world behaviour: scream fires on ~6% of real
AudioSet screams.

## Decision

**`scream_classifier_v5` unchanged, stays NC.** Going fully NC-free is now a
priced trade rather than an open question:

| approach | cost vs incumbent |
|---|---|
| drop ESC-50 only | −0.0195 |
| drop ESC-50 **and** the FSD50K NC slice, diversity replaced | **−0.0113 worst seed** |

Replacing the diversity recovered roughly 40% of the gap. Not enough to
spend on the weakest detector in the project.

**NC models: 2**, unchanged — `m5_vocal_stress_v3`, `scream_classifier_v5`.

## Both open items are now closed

* **FSD50K's per-clip NC slice** — no longer an unmeasured exposure. Arm C
  removes it by re-extracting from licence-filtered lists rather than
  filtering the filename-less cache, and the combined cost is the −0.0113
  above. The method is in `scream_ncfree_v2.py` and reusable.
* **~360 permissive negatives** — found, and 2,500 of them, CC0/CC-BY,
  spanning 181 labels, from data already on disk. They are *not* worthless:
  they turned −0.0195 into −0.0113. They are just not sufficient alone.

What would close the remaining gap is more permissive **positives** — arm C
has 2,904 against v5's 3,127, having lost 223 NC-licensed screams it cannot
replace from FSD50K's permissive pool, which holds only 218 scream clips in
total.

Reproduce: `work/permissive/{scream_ncfree_v2,scream_ncfree_v3}.py`,
reports in the matching `.json`. Arm C's features are cached at
`armC_features.npz` so the recipe can be re-run without re-extracting.
