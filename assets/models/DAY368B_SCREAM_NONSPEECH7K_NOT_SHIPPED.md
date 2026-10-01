# Day 368B — Nonspeech7k helps scream on average, misses the ship rule by 0.0008

## Data

**Nonspeech7k** (Zenodo 6967442, **CC BY 4.0**, read from the record itself;
search summaries had wrongly called it non-commercial). Human non-speech
sounds: 593 training screams plus breathing, coughs, laughs, sneezes, yawns
and crying. Clips come from Freesound, aigei.com and YouTube. Downloaded from
a byte-equivalent Kaggle mirror because Zenodo throttled to 403.

**Leakage removed before training.** FSD50K, the source of both the scream
test fixture and v5's training set, is also Freesound. Matching on Freesound
sound id:

```
training clips dropped (sound id in FSD50K eval or dev)               288
test clips dropped (sound id in FSD50K dev or Nonspeech7k train)      171
```

Labels follow v5: screaming is positive, the other classes negative, and
crying is excluded.

## Method

Shipped recipe, reproduced exactly: v5 **arm D** (13,960 rows, crying
sources excluded), with `make_model` and `spec_augment` imported from
`work/scream_v5/train_scream_v5.py`, 45 epochs max, early stopping on
val_auc. Three seeds per arm, run on a Kaggle GPU.

An earlier local attempt used the wrong composition: it kept crying as a
positive, and its control scored 0.790 against shipped 0.828. It was
discarded rather than reported. This run's control reproduces shipped, so
the comparison is valid.

## Result

```
                     FSD50K eval (fixture)     AudioSet held-out    Nonspeech7k test
shipped v5           0.8284                    0.9069               0.9817
A control  seeds     .8306 .8109 .8287          .9192 .9293 .8990     .9779 .9863 .9885
           mean      0.8234                    0.9158               0.9842
N +ns7k    seeds     .8369 .8388 .8276          .8809 .9333 .9088     .9908 .9928 .9990
           mean      0.8344                    0.9077               0.9942
```

Ship rule, fixed before running: the worst seed must be at least shipped on
FSD50K, and the mean must be at least shipped on the other two sets.

```
FSD50K worst seed   0.8276 vs 0.8284   FAIL by 0.0008
AudioSet mean       0.9077 vs 0.9069   pass
Nonspeech7k mean    0.9942 vs 0.9817   pass
```

**Not shipped.** On the fixture, the paired bootstrap for median-seed N
minus shipped gives 95% CI **[-0.008, +0.025]** with P(better) 0.83. N minus
the same-seed control gives [-0.011, +0.023] with P(better) 0.75.

## Reading it honestly

- **The direction is consistent.** N's mean beats the control on FSD50K
  (+0.011) and Nonspeech7k (+0.010). Two of three seeds beat shipped on the
  fixture.
- **The size is not established.** Both CIs include zero, and the AudioSet
  mean is flat against control (0.9077 vs 0.9158; AudioSet has only 132
  clips). Overriding a pre-registered rule after seeing a 0.0008 miss is how
  this project shipped placebo improvements before. The rule stands.
- **What would decide it:** more seeds (the seed-to-seed spread is about
  0.02, larger than the effect) or a larger real-world test set. Per
  `ml_real_world_data_value`, a few hundred real recordings are worth more
  than either.

The data is CC BY 4.0, so unlike ESC-50 it does not add to scream's
non-commercial exposure.

Reproduce: `tools/day353_ml/permissive/scream_armd_ns7k_gpu.py` (Kaggle
kernel `hridyajain/zapsafe-scream-armd-ns7k-gpu`, dataset
`hridyajain/zapsafe-scream-armd-ns7k`). Numbers are in
`tools/day353_ml/permissive/scream_ns7k_armd_result.json`.
