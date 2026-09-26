# Day 362C — a few dozen real-world clips beat hundreds of in-corpus ones

For several days the standing recommendation has been "get MIVIA" — 6,000
real glass/gunshot/scream events at realistic SNRs, behind a request form
only the user can submit. That recommendation rested on an **assumption**:
that a modest amount of in-domain data would close a gap that a large amount
of out-of-domain data cannot.

It had never been tested. Before asking someone to go and get data, it is
worth checking that the data would help.

## The design

5-fold cross-validation over AudioSet **clips** (never windows — a clip's
windows must not straddle the split):

```
BASE   train on FSD50K dev only              test on the held-out fold
MIX    train on FSD50K dev + 4/5 of AudioSet test on the held-out fold
```

Out-of-fold predictions are collected across all five folds, so both arms
are finally scored on **every** AudioSet clip — the full 59 / 77 positives,
not a fifth of them — on identical rows, so the bootstrap is paired.

**Weak labels handled explicitly.** A 10 s AudioSet clip labelled "Gunshot"
contains the gunshot in perhaps one 3 s window. Feeding every window of a
positive clip as positive would train on mostly-negative audio labelled
positive. For each positive clip, the single window the BASE model scores
highest is taken as the positive instance — using the clip's known label to
locate the event inside a clip already known to contain one. BASE never sees
AudioSet, so no held-out label leaks. Negative clips contribute all their
windows, which are all genuinely negative.

## The result

```
glass     BASE 0.6693  ->  MIX 0.7229   delta +0.0535  [+0.015, +0.095]  P(MIX<=BASE) 0.003
gunshot   BASE 0.6696  ->  MIX 0.7751   delta +0.1051  [+0.049, +0.166]  P(MIX<=BASE) 0.000
```

Both significant. Gunshot gains **+0.105**.

## The part that actually makes the case

Look at how little data produced that:

| | FSD50K positives in training | real-world positives added | gain |
|---|---|---|---|
| glass | **872** | ~47 | +0.054 |
| gunshot | **320** | ~62 | +0.105 |

**62 real-world gunshot clips outperformed 320 in-corpus ones by 0.105.**
Per clip, target-domain data is worth roughly an order of magnitude more
here than more of the same corpus. That is the whole argument for acquiring
real data rather than scraping another Freesound-style set, and it is now
measured rather than asserted.

It also re-frames Day 361's finding. Glass's retrain gain being
FSD50K-specific was read as "the model overfits its corpus". That is true,
but the actionable half is the converse: **the corpus is the limit, and a
very small amount of the right data moves it.**

## What this does NOT establish

MIX is trained on AudioSet and tested on AudioSet — different clips, but the
same corpus. So part of the gain is learning AudioSet's own recording
characteristics, not universal generalisation. A clean test would train on
AudioSet and evaluate on a **third** corpus, and no third corpus is
available here.

So the honest claim is narrower than "real data generalises":

> A small amount of data **from the target domain** is worth much more than
> a large amount from a different corpus.

For a phone app that is the relevant claim, because the target domain *is*
"real events recorded in real environments" — which is what MIVIA is (six
SNR levels over environmental noise) and what FSD50K's clean isolated
Freesound uploads are not. But it should not be quoted as proof that any
new corpus would help.

Extrapolation caution: 47 → 6,000 positives will not scale linearly. The
evidence is about the *slope at very small n*, and it is steep.

## Status of the recommendation

**MIVIA goes from "probably worth it" to "measured as worth it", with the
caveat above.** It targets exactly the three shipped audio detectors, at
realistic SNRs, and the two that could be tested here both improve
substantially from a few dozen in-domain clips.

Same reasoning gives a second, cheaper option that needs no one's
permission: **any modest set of real-world recordings of these three events
would help**, and it does not need to be large. A few hundred per class,
recorded or collected in realistic conditions, is in the range that produced
these gains.

## What was NOT done

No model was retrained for shipping and no asset was exported. This is a
measurement of what data is worth, deliberately separated from any ship
decision — MIX cannot ship, because it is trained on the same corpus it is
evaluated on, and shipping it would reproduce exactly the in-domain
memorisation Day 361 exposed.

Reproduce: `work/audioset_xcorpus/multicorpus_value.py`, report in
`multicorpus_value.json`.
