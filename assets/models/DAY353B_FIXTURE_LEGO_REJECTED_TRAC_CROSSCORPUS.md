# Day 353B — the last unblocked item, one corpus rejected, and TRAC survives

Four open items were worked. One shipped, one was rejected by its own
replication test, one produced the week's first successful cross-corpus
result, and one turned out to be blocked by data after all.

## 1. `h_aggressive_v4_38` is no longer UNVERIFIED

It was the only model with no real-data fixture. It did not need new data:
`work/h_aggressive_v4/feat_meld_eval.npz` already held MELD test+dev
featurised by `featurise_yin2048.py` — the same extractor that trained v4,
on a split it never trains on. Exported as
`eval_h_aggressive_natural.npz` and routed by filename, since this is now
the **third** distinct `[1,38]` feature definition in the gate.

```
h_aggressive_v4_38.tflite   WEAK   n=2911  AUC=0.641  sep=0.0841
```

0.641 against the 0.6415 recorded on Day 352 — reproduced end-to-end
through the actual shipped `.tflite` and its norm, not just the training
script. **It is now honestly WEAK rather than unverified**, which is a
worse-looking gate and a better-informed one. It was always 0.641.

## 2. LEGOv2 — found, measured, and rejected

m4 and h_aggressive are both weak for the same reason: their only natural
English is MELD. Day 353 established that adding *acted* English is unsafe,
so the search was for spontaneous English.

**LEGOv2** (CMU Let's Go) is real members of the public phoning a bus
information line, annotated by Ulm University: 3,305 neutral, 693
slightlyAngry, 137 angry, 104 veryAngry, across 291 calls. 4,243 usable
clips, nobody performing.

It looked strong on the screening test — the opposite of ESD:

```
direction agreement, LEGO vs MELD    r = +0.70  [+0.55, +0.82]   36/38 agree
```

But two warnings came with it: it is **8 kHz telephone audio**, corpus-ID
AUC was **1.0000** (trivially separable), and linear transfer LEGO→MELD sat
at chance (0.50–0.54). Features can agree on direction — a rank measure —
while an 8 kHz shift moves every decision boundary.

The paired A/B (LEGO training-side only, both arms scored on identical
untouched MELD rows) ran four configurations, and exactly one cleared its
CI:

```
h_aggressive, wide labels   +0.0410  CI [+0.0181, +0.0648]   <- the hit
h_aggressive, strict        -0.0061  CI [-0.0273, +0.0150]
m4, wide                    -0.0013  CI [-0.0138, +0.0111]
m4, strict                  -0.0019  CI [-0.0157, +0.0117]
```

One win in four tests at a 95% bar is a ~19% family-wise false-positive
rate, and the standing rule here is that a screening hit gets confirmed by
retraining. Re-run at four fresh seeds:

```
seed 7      +0.0267
seed 123    -0.0041
seed 2024   -0.0185
seed 31337  +0.0074
            mean +0.0029, positive in 2/4
```

**Not confirmed. LEGOv2 is rejected.** Stopping at the A/B would have added
a corpus, a licence line and 4,243 rows of provenance on the strength of
one lucky initialisation.

The corpus is not deleted — `work/lego_natural/` holds the features in both
spaces and the scripts — but nothing ships from it, and m4 stays at 0.648.

Worth recording for whoever tries next: LEGOv2 is CMU "individual,
education research purposes only", so it would not have improved the
licence position either.

## 3. TRAC-1 survives a cross-corpus test — the first thing this week that did

TRAC-1 had never been scored outside its own corpus, in a week where that
test broke m3_violence (0.9126 → 0.4821), scream v3 (0.839 → 0.7675) and
every vocal-stress model.

**Indo-HateSpeech** — 77,926 Instagram comments, Hindi (Devanagari and
romanised) and English, labelled HS0/HS1. Same language pair, different
platform, different annotators. 58,477 usable rows after dropping the
undocumented HSN category.

```
TRAC-1 on Indo-HateSpeech   0.7081   CI [0.7028, 0.7134]   n=58,477
length-only baseline        0.5223
in-corpus (TRAC dev)        0.8312
OOV rate vs TRAC's vocab    21.5%
```

A real drop, not a collapse, and it clears the trivial-cue baseline by
0.19 on that set's own labels.

**The caveat is structural and cannot be resolved by this test alone.**
TRAC's labels are aggression (OAG/CAG/NAG); Indo-HateSpeech's are hate
speech. Those are related but not the same construct — hate speech roughly
targets a protected attribute, while much TRAC aggression is a personal
insult that would be HS0 here. So part of the 0.12 drop is transfer failure
and part is the constructs differing, and this measurement cannot say which.

What it does establish: **0.8312 must not be quoted as general aggression
detection.** 0.71 on an independent corpus is the number that describes the
model to anyone outside the TRAC corpus.

It remains unwired, because its blocker was never the number — there is no
consented text surface in the app.

## 4. `distress_text_v1` — the cross-corpus blocker is real

Day 347 listed five blockers, four of them product decisions and one a
measurement: it had never been tested cross-corpus. That one was worth
attempting, and it cannot be done.

Every labelled text corpus on every attached drive was enumerated. **Three
exist**, all mental-health, and:

```
mental_health_feature_engineered.csv   48,928 unique texts
mental_heath_unbanlanced.csv           48,928 unique texts
overlap                                48,928 = 100.0%
```

`feature_engineered` is the training corpus with extra derived columns — not
an independent corpus, the same rows. There is nothing to test against.

One thing checked and cleared along the way: the two training sources
overlap each other by 50% (496 of 992 texts), which would inflate 0.9628 if
the split came before dedup. It does not — `load()` dedupes on normalised
text across both files *before* splitting. **No leakage.** The 0.9628 is not
inflated by exact duplicates.

So distress_text stays shelved, and the reason list is now four product
decisions plus one confirmed data blocker, rather than four plus an untested
assumption.

## 5. Licence: a correction, in the unfavourable direction

Day 353 said m5's EmotionTalk had "no card or licence file on disk" and that
dropping ESD traded a known NC term for an unstated one.

**Wrong.** EmotionTalk is **CC BY-NC-SA 4.0** — the badge is in its own
source repo (`EmotionTalk-main.zip` → `README.md`). The extracted data drop
holds only `Audio.tar` and `.cache`, so the first pass looked in the data
folder and the licence was one directory away in the code repo.

ESD was not traded for an unknown. **It was traded for another
Non-Commercial corpus.** The gate's `UNKNOWN` flag is gone and m5 now
appears where it belongs:

```
Non-Commercial training data: h_aggressive_v4_38, m5_vocal_stress_v3_38,
                              m_glass_breaking_v3, mg_gunshot_retrain,
                              scream_classifier_v5
```

Five models, not four. The NC problem is neither smaller nor murkier than
before Day 353 — it is exactly the same size, and one model that looked
merely unclear is now known to be NC.

Also corrected in the Day 353 doc: EmotionTalk is 19 **actors** in dyadic
conversation. Calling it "natural speech" was too strong; it is
*conversational* rather than read-aloud. The direction-inversion result
stands because it was measured, but the word was wrong.

## 6. Status

| item | outcome |
|---|---|
| h_aggressive fixture | **done** — WEAK 0.641, no longer UNVERIFIED |
| m4 improvement | **no path found** — LEGOv2 measured and rejected |
| TRAC-1 | **validated cross-corpus at 0.7081**; still unwired, no surface |
| distress_text | **blocked on data**, confirmed; dedup verified clean |
| licence | m5 corrected to NC; five NC models, not four |

Reproduce: `work/lego_natural/{featurise_lego,diagnose_lego,ab_lego,
confirm_seeds}.py`, `work/trac_aggression/crosscorpus_indo.py`.

**Nothing here ran on physical hardware.**
