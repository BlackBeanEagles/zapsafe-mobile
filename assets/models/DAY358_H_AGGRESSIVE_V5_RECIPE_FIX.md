# Day 358 — h_aggressive 0.641 → 0.671, and it was the weighting all along

Six corpora and ~41 GB were spent trying to lift this model with more data.
The gain came from a one-line change to the training recipe, on the same
data and the same features.

## 1. How it was found: by trying the expensive idea first

Day 356 concluded the 38-dim prosodic vector was the ceiling and proposed
learned speech embeddings. That was tested cheaply, on MELD alone:

```
WavLM-base-plus, layer 12, mean+std pooled    0.7054  CI [0.6835, 0.7275]
38-dim, 128/64 MLP, same protocol             0.6671
38-dim, plain logistic regression             0.6865
shuffled-label control                        0.4888
```

Every WavLM layer beat 38-dim, linear probes nearly matched the MLP, and the
shuffled control sat at chance — so the representation gain is real. But
against a *properly tuned* 38-dim head the margin is **+0.018**, for a
377 MB encoder against a 4.7 MB largest-asset budget. Rejected on cost.

The useful part was accidental: **a linear model beat the shipped network by
0.045 on its own features.** That is the signature of an over-parameterised
head, not of weak features.

## 2. Two hypotheses, both tested, one wrong

**"Drop the acted corpora."** Four of the five are acted, and Day 353 showed
ESD was actively harmful. Refuted:

```
                    MELD eval     EQ4You    NaturalVoices
MELD train only     0.6869        0.5038    0.5088
five corpora        0.6709        0.4972    0.5622
```

MELD-only wins in-domain and **collapses to chance** on NaturalVoices, where
the five-corpus recipe reaches 0.5622. The acted data buys generalisation.
Keeping it.

Worth recording separately: both recipes sit at ~0.50 on corpora they do not
train on. The 38-dim space does not transfer *whatever* it is trained on,
which is the cleanest statement yet of why six corpora failed.

**"It is the regularisation."** Also wrong, and this one nearly shipped as a
finding. A 2×2 isolated it:

```
                          corpus_weights   class_weight
v4 head (d0.3/0.2)        0.6513           0.6649
regularised (d0.5, L2)    0.6339           0.6736
```

The **weighting** dominates. `corpus_weights` scales every corpus to equal
influence, pushing SAVEE's 360 rows and RAVDESS's 1,056 to the same total
weight as MELD's 7,961 — and three of the four upweighted corpora are acted
studio recordings while the deployment domain is conversational.

There is also an interaction: regularisation **hurts** under
`corpus_weights` and helps under `class_weight`. A first v5 attempt that
changed only the head came out at 0.6410 — identical to v4, no gain at all.

## 3. What shipped

```
v5 = same 5 corpora, same 38-dim features, class_weight + d0.5 + L2 1e-3

seeds   0.6702  0.6708  0.6707  0.6735  0.6761
mean 0.6723   min 0.6702   max 0.6761
gate, through the shipped .tflite:  0.671   (v4: 0.641)
```

The **median** seed was exported, not the best — picking the best seed is
choosing a number rather than a model. 11.9 KB, unchanged from v4.

## 4. The threshold had to move, and that nearly went wrong

The gate reported it immediately:

```
v4  rec@0.5 = 0.664        v5  rec@0.5 = 0.057
```

L2 and dropout 0.5 compress the sigmoid toward zero, so the same numeric
threshold sits far out in the tail. **Shipping v5 behind the old 0.45 would
have produced a better-scoring model that almost never fires** — a silent
regression that AUC alone cannot show.

Both models were scored through their real `.tflite` files (v4 restored from
git) at matched recall:

```
recall   v4 prec (thr)    v5 prec (thr)    v5-v4
0.80     0.266 (0.420)    0.280 (0.230)    +0.015
0.70     0.296 (0.482)    0.316 (0.276)    +0.020
0.60     0.318 (0.526)    0.323 (0.304)    +0.004
0.50     0.334 (0.561)    0.368 (0.355)    +0.035
0.40     0.364 (0.610)    0.421 (0.417)    +0.057
```

v5 is better at **6 of 6** recall levels. The shipped threshold is **0.23**,
which reproduces v4's operating point exactly — recall 0.758, precision
0.280 — so the upgrade is behaviour-neutral where it fires, while the better
ranking benefits any fusion consuming the raw score. Raising it to 0.30 or
0.355 trades recall for precision deliberately; that is a product decision
and is documented at the constant rather than buried here.

## 4b. The gate's `rec@0.5` no longer means anything for this model

The gate still prints `rec@0.5 = 0.057` for v5, because it reports recall at
a hardcoded 0.5 for every model. The shipped threshold is 0.23, where recall
is **0.758**. So that column understates v5 by a factor of thirteen.

This is a pre-existing gate limitation rather than something v5 introduced —
no shipped model uses 0.5 (`m5` is 0.20, `m_glass_breaking` 0.22,
`trac_aggression` 0.60) — but v5 is the first case where it is actively
misleading, because the compressed sigmoid puts 0.5 far into the tail.
Reading that number as "the detector fires on 5.7% of aggressive speech"
would be wrong. Fixing it properly means teaching the gate each model's
shipped threshold, which is a change to the gate and not to this model.

## 5. Status

| | |
|---|---|
| asset | `h_aggressive_v5_38.tflite`, 11.9 KB (v4 deleted) |
| gate | **0.671**, still WEAK against the 0.70 bar, still red |
| threshold | 0.23, behaviour-matched to v4's operating point |
| data | unchanged — no new corpus, no new features |
| cross-corpus | unchanged at ~0.50; this does not fix transfer |

Still below the gate's 0.70 bar, so it stays red and stays a fusion
contributor rather than an alert trigger. The honest summary is that a
recipe bug was costing 0.03 for an unknown number of days, and six corpora
were acquired before it was found.

Reproduce: `work/embeddings/{extract_wavlm_meld,compare_representations,
arch_sweep_38dim,meld_only_vs_multicorpus,isolate_weighting,
train_h_aggressive_v5,compare_v4_v5_curves}.py`.
