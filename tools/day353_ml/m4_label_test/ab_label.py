"""Day 355 - is m4 better at anger alone than at anger+sad?

THE PREDICTION BEING TESTED
===========================
Day 354 found that MOSEI's `sad` points the OPPOSITE way to MELD's pooled
"stressed" direction (r = -0.669, CI [-0.794, -0.512]) while its `anger`
is merely unrelated (+0.061, CI spanning zero). If m4's positive class is
internally contradictory, a model trained on anger alone should be a
cleaner detector of anger than the pooled model is of anger+sad.

THREE DEFINITIONS, IDENTICAL IN EVERY OTHER RESPECT
===================================================
    anger+sad    what m4 ships today
    anger-only   the narrower construct
    sad-only     the other half, as a control

Same seed, architecture, split rule and negatives (neutral + happy).
Trained on MELD train, scored on MELD test+dev -- rows no arm ever trains on.

HOW TO READ IT, FIXED BEFORE RUNNING
====================================
Each definition is scored ON ITS OWN TEST SET, because they are different
tasks: anger-only is judged on anger-vs-calm rows, pooled on
(anger|sad)-vs-calm rows. Comparing them is therefore NOT apples to apples
and no single AUC ordering settles it. What IS comparable, and what this
run is really for:

  1. Does the pooled model beat the anger-only model AT DETECTING ANGER?
     Both are scored on the identical anger-vs-calm subset. If pooling
     costs anger detection, the `sad` rows are actively interfering.
  2. Is sad-only learnable at all? If sad-vs-calm is near chance, then
     half of m4's positive class carries almost no prosodic signal in this
     feature space, and pooling it in is diluting the other half.

Test 1 is the decisive one and is a fair paired comparison on shared rows,
with the bootstrap taken on the difference.

WHAT THIS DOES NOT DECIDE
=========================
Whether m4 SHOULD be anger-only. Narrowing it drops any ability to notice a
distressed, frightened or tearful user, which for a personal-safety app may
be the more important half. That is a product decision. This only measures
what the pooling costs.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = 42
NEG = {"neutral", "happy"}

DEFS = {
    "anger+sad": {"anger", "sad"},
    "anger-only": {"anger"},
    "sad-only": {"sad"},
}


def load(tag):
    d = np.load(os.path.join(HERE, "meld_%s_emo.npz" % tag),
                allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d["emo"]), np.asarray(d["spk"])


def fit(Xtr, ytr, Xva, yva):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(SEED)
    np.random.seed(SEED)
    n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
    m = tf.keras.Sequential([
        tf.keras.Input(shape=(Xtr.shape[1],)),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=150, batch_size=128,
          verbose=0,
          class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                        1: len(ytr) / (2.0 * max(n1, 1))},
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])
    return m


def ci(y, p, n=4000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    b = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        b.append(roc_auc_score(y[i], p[i]))
    return float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))


def paired_ci(y, pa, pb, n=4000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    d = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        d.append(roc_auc_score(y[i], pa[i]) - roc_auc_score(y[i], pb[i]))
    return (float(np.percentile(d, 2.5)), float(np.percentile(d, 97.5)),
            float(np.mean(d)))


def main():
    from sklearn.metrics import roc_auc_score
    Xtr, etr, _ = load("train")
    Xte, ete, _ = load("eval")
    print("train %s  eval %s" % (Xtr.shape, Xte.shape))
    import collections
    print("  train emotions:", dict(collections.Counter(etr.tolist())))
    print("  eval  emotions:", dict(collections.Counter(ete.tolist())))

    rep = {}
    models = {}
    for name, pos in DEFS.items():
        mtr = np.array([e in pos or e in NEG for e in etr])
        mte = np.array([e in pos or e in NEG for e in ete])
        ytr = np.array([1 if e in pos else 0 for e in etr[mtr]])
        yte = np.array([1 if e in pos else 0 for e in ete[mte]])
        mu, sd = Xtr[mtr].mean(0), Xtr[mtr].std(0) + 1e-8

        def Z(A, mu=mu, sd=sd):
            return ((A - mu) / sd).astype(np.float32)

        m = fit(Z(Xtr[mtr]), ytr, Z(Xte[mte]), yte)
        p = m.predict(Z(Xte[mte]), verbose=0).ravel()
        a = float(roc_auc_score(yte, p))
        lo, hi = ci(yte, p)
        print("\n  %-11s own test set: AUC %.4f  CI [%.4f, %.4f]  "
              "(n=%d, pos=%d)" % (name, a, lo, hi, int(mte.sum()),
                                  int(yte.sum())))
        rep[name] = {"auc_own_testset": round(a, 4),
                     "ci95": [round(lo, 4), round(hi, 4)],
                     "n": int(mte.sum()), "pos": int(yte.sum())}
        models[name] = (m, mu, sd)

    # TEST 1 -- the fair comparison: both models on the SAME anger rows
    print("\n" + "=" * 70)
    print("TEST 1  both models scored on the IDENTICAL anger-vs-calm rows")
    m_ang = np.array([e == "anger" or e in NEG for e in ete])
    y_ang = np.array([1 if e == "anger" else 0 for e in ete[m_ang]])
    preds = {}
    for name in ("anger+sad", "anger-only"):
        m, mu, sd = models[name]
        preds[name] = m.predict(
            ((Xte[m_ang] - mu) / sd).astype(np.float32), verbose=0).ravel()
        print("  %-11s anger detection: %.4f"
              % (name, roc_auc_score(y_ang, preds[name])))
    lo, hi, mean = paired_ci(y_ang, preds["anger-only"], preds["anger+sad"])
    print("\n  PAIRED (anger-only - anger+sad) %+.4f 95%% CI [%+.4f, %+.4f]"
          % (mean, lo, hi))
    helps = lo > 0.0
    rep["test1_anger_rows"] = {
        "anger_only": round(float(roc_auc_score(y_ang, preds["anger-only"])), 4),
        "pooled": round(float(roc_auc_score(y_ang, preds["anger+sad"])), 4),
        "paired_delta": round(mean, 4),
        "paired_ci95": [round(lo, 4), round(hi, 4)],
        "pooling_costs_anger_detection": bool(helps),
        "n": int(m_ang.sum()), "pos": int(y_ang.sum())}
    print("  -> %s" % ("POOLING COSTS ANGER DETECTION -- the sad rows "
                       "actively interfere" if helps else
                       "no measurable cost to pooling on anger rows"))

    # TEST 2 -- is sad learnable at all?
    s = rep["sad-only"]
    print("\nTEST 2  sad-vs-calm on its own rows: %.4f CI [%.4f, %.4f]"
          % (s["auc_own_testset"], s["ci95"][0], s["ci95"][1]))
    if s["ci95"][0] <= 0.55:
        print("  -> sad carries little or no prosodic signal here; pooling "
              "it into the positive class dilutes anger with noise")
    rep["_note"] = ("Whether m4 SHOULD narrow to anger is a product "
                    "decision, not a measurement. Narrowing drops any "
                    "ability to notice a distressed or tearful user.")
    json.dump(rep, open(os.path.join(HERE, "label_report.json"), "w"),
              indent=2)
    print("\nlabel_report written")


if __name__ == "__main__":
    main()
