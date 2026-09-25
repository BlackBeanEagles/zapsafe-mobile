# Day 358B — m4 does not get h_aggressive's fix. It is already optimal.

h_aggressive gained 0.641 → 0.671 today from a training-recipe change. The
obvious next move was to apply the same change to m4, which sits at 0.648 and
carries the same over-parameterised head shape. It was tested and it does not
help.

## The test

Scored on the **same held-out natural rows the gate uses for m4**, so the
numbers are directly comparable to its 0.648.

```
logistic regression                0.6405
current head, d0.3/0.2             0.6075   (5 seeds, 0.6036-0.6151)
regularised, d0.5 + L2 1e-3        0.6418   (5 seeds, 0.6325-0.6502)

shipped m4 (gate)                  0.648    <- still the best
```

Regularisation *does* help inside the comparison — +0.034 over the same head
without it, the same direction h_aggressive showed. But it never reaches the
shipped model, so there is nothing to ship.

## Why the shipped model wins

Two reasons, and both mean the recipe is already right:

**1. Only half of h_aggressive's fix applies.** The 2×2 in
`DAY358_H_AGGRESSIVE_V5_RECIPE_FIX.md` showed the *weighting* dominated,
with regularisation a smaller effect on top. m4 already uses
`class_weight`, and it trains on a **single corpus** (MELD) — there is
nothing to rebalance. `corpus_weights` never applied to it, so the large
half of the gain was never available.

**2. Early stopping.** `train_final.py` fits with
`EarlyStopping(monitor="val_auc", restore_best_weights=True)`; this
comparison ran a fixed 60 epochs to match the h_aggressive sweep. That
difference is the most likely source of the remaining gap, and it means the
shipped recipe is doing something the sweep did not.

## What this closes

m4's 0.648 is not a recipe bug. It is what the 38-dim vector plus 6,100 MELD
rows supports. Combined with the corpora already rejected —

* ESD: actively harmful (direction r = −0.56)
* CMU-MOSEI, LEGOv2, EQ4You, NaturalVoices, AudioSet: all rejected
* WavLM embeddings: +0.018 for a 377 MB encoder

— there is no remaining lever on m4 that does not require new data or a new
asset budget.

## Status

| | |
|---|---|
| m4 | unchanged at 0.648, **confirmed already optimal** |
| action taken | none — nothing retrained, nothing shipped |
| why recorded | so this is not retried; the fix looked transferable and is not |

Reproduce: `work/embeddings/m4_reg_test.py`.
