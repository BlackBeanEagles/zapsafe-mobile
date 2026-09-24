# Day 355 — m4's label construct is fine. My Day 354 hypothesis was wrong.

Day 354 found that CMU-MOSEI's `sad` points the opposite way to MELD's
pooled "stressed" direction (r = −0.669, CI [−0.794, −0.512]) while its
`anger` is merely unrelated (+0.061, CI spanning zero). From that I
concluded m4's positive class was **internally contradictory**, and told
the user:

> *"Don't buy data yet. Decide the label question first — buying a corpus
> before fixing the construct spends money on the wrong problem."*

That advice was wrong and should be discarded.

## The test

Every cached MELD fixture stores only the pooled `y`; the emotion string was
thrown away at featurisation time, which is why Day 354 could only
hypothesise. MELD train (8,106) and test+dev (3,047) were rebuilt in m4's
512/256 space **keeping the emotion**, and three definitions were trained
identically — same seed, architecture, split rule, and negatives
(neutral + happy):

```
                        own test set             n      pos
anger+sad    0.6623  [0.6411, 0.6849]          3047     797
anger-only   0.6989  [0.6713, 0.7243]          2732     482
sad-only     0.6586  [0.6260, 0.6894]          2565     315
```

**Those three numbers are not comparable to each other**, and the comparison
that matters was pre-registered before the run: score the pooled model and
the anger-only model on the *identical* anger-vs-calm rows.

```
anger+sad    anger detection   0.7001
anger-only   anger detection   0.6989

PAIRED (anger-only − anger+sad)  −0.0013   95% CI [−0.0184, +0.0157]
```

## Two findings, both against the hypothesis

**1. Pooling costs nothing.** On identical rows the two models are
indistinguishable. Pooling `sad` into the positive class does not degrade
anger detection at all.

**2. `sad` is learnable.** 0.6586 with a CI floor of 0.626 — comfortably
above chance, and in fact within noise of the pooled model's own score. It
is not noise diluting anger.

The trap this run was built to avoid is exactly the one that would have
confirmed the hypothesis: anger-only reads 0.6989 against the pooled
model's 0.6623 on their own test sets, which *looks* like a 0.037 win. It
is not. Anger-vs-calm is simply an easier task than
(anger-or-sad)-vs-calm — fewer, more separable positives. Reading those two
headline numbers against each other is apples-to-oranges, and it is what I
would have done without the pre-registered paired comparison.

## What this means

The Day 354 cross-corpus opposition was **real but does not generalise into
a within-corpus cost**. Two corpora can disagree about which direction of a
feature means "stressed" while, inside one corpus, pooling those same two
emotions is free. Cross-corpus direction disagreement is evidence about
*transfer*, not about whether a label definition is coherent.

So m4's 0.648 is back to being a data/feature problem. The label question is
closed, and the corpus acquisition that Day 354 advised deferring is the
right next move after all.

## Status

| | |
|---|---|
| m4 label construct | **not the problem** — pooling is free, `sad` is learnable |
| Day 354's advice | **withdrawn** |
| m4's ceiling | data/features, as originally thought |
| shipped assets | unchanged — nothing was retrained on this |

Reproduce: `work/m4_label_test/{featurise_meld_emotions,ab_label}.py`.

Caveat worth keeping: this is one corpus. It shows pooling is free *in
MELD*. A corpus whose sadness dominates its anger could still behave
differently, which is precisely what MOSEI showed cross-corpus.
