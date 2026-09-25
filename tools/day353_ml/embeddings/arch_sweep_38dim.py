"""Day 358 - the shipped h_aggressive may be leaving 0.045 on the table.

THE OBSERVATION
===============
Matching protocols to compare representations turned up something unrelated
and more useful:

    shipped h_aggressive_v4 on MELD eval (gate)        0.641
    38-dim + plain LOGISTIC REGRESSION, same rows      0.6863
    38-dim + the 128/64 MLP                           0.6671
    WavLM layer 12 + 128/64 MLP                       0.7054

A linear model on the SAME 38 features beats the shipped network by 0.045
and lands within 0.019 of a 94M-parameter speech encoder. That suggests the
shipped model is not limited by its features so much as by its own
architecture and training -- 7,961 rows against a 64/32 MLP with dropout
0.3/0.2 and 150 epochs is easy to overfit.

If a smaller or better-regularised head recovers that 0.045, it is free:
same features, same 12 KB asset class, no new data, no new Dart path. That
is worth more than a 377 MB encoder for +0.019.

WHAT THIS SWEEPS
================
Architectures from bare logistic regression up to the shipped 64/32, plus
L2 and dropout variants, all on identical rows with identical splits.
Reported with bootstrap CIs so a 0.01 difference is not mistaken for a
finding.

SEED-REPLICATED. Day 356 retracted a "CONFIRMED" that came from four seeds;
anything that looks better here is re-run across five seeds and reported as
a distribution, because a single number on this eval set bounces ~0.02.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
SEEDS = (42, 7, 123, 2024, 31337)
SHIPPED_GATE = 0.641


def load(split):
    f = "feat_meld_train.npz" if split == "train" else "feat_meld_eval.npz"
    d = np.load(os.path.join(WORK, f), allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d["y"]).astype(int)


def boot(y, p, n=3000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    b = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        b.append(roc_auc_score(y[i], p[i]))
    return float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))


def net(dim, units, dropout, l2, seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    reg = tf.keras.regularizers.l2(l2) if l2 else None
    layers = [tf.keras.Input(shape=(dim,))]
    for i, u in enumerate(units):
        layers.append(tf.keras.layers.Dense(u, activation="relu",
                                            kernel_regularizer=reg))
        if i == 0:
            layers.append(tf.keras.layers.BatchNormalization())
        layers.append(tf.keras.layers.Dropout(dropout))
    layers.append(tf.keras.layers.Dense(1, activation="sigmoid",
                                        kernel_regularizer=reg))
    return tf.keras.Sequential(layers)


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    from sklearn.linear_model import LogisticRegression

    Xtr, ytr = load("train")
    Xte, yte = load("eval")
    mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
    Ztr = ((Xtr - mu) / sd).astype(np.float32)
    Zte = ((Xte - mu) / sd).astype(np.float32)
    print("train %s pos=%d | eval %s pos=%d"
          % (Xtr.shape, ytr.sum(), Xte.shape, yte.sum()))
    print("shipped model on these rows (gate): %.3f\n" % SHIPPED_GATE)

    rows = []

    # --- linear, with a C sweep; no seed dependence worth replicating
    for C in (0.01, 0.1, 1.0, 10.0):
        m = LogisticRegression(max_iter=5000, C=C, class_weight="balanced")
        m.fit(Ztr, ytr)
        p = m.predict_proba(Zte)[:, 1]
        a = float(roc_auc_score(yte, p))
        lo, hi = boot(yte, p)
        print("  logistic C=%-5s  AUC %.4f  CI [%.4f, %.4f]"
              % (C, a, lo, hi), flush=True)
        rows.append({"model": "logistic C=%s" % C, "auc": round(a, 4),
                     "ci95": [round(lo, 4), round(hi, 4)], "seeds": 1})

    # --- networks, each across SEEDS
    configs = [
        ((64, 32), 0.3, 0.0, "shipped 64/32 d0.3"),
        ((32,), 0.3, 0.0, "32 d0.3"),
        ((16,), 0.2, 0.0, "16 d0.2"),
        ((64, 32), 0.5, 1e-3, "64/32 d0.5 L2"),
        ((32,), 0.5, 1e-3, "32 d0.5 L2"),
    ]
    for units, dr, l2, name in configs:
        aucs = []
        for s in SEEDS:
            m = net(Xtr.shape[1], units, dr, l2, s)
            m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                      loss="binary_crossentropy",
                      metrics=[tf.keras.metrics.AUC(name="auc")])
            n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
            m.fit(Ztr, ytr, epochs=60, batch_size=128, verbose=0,
                  class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                                1: len(ytr) / (2.0 * max(n1, 1))})
            aucs.append(float(roc_auc_score(
                yte, m.predict(Zte, verbose=0).ravel())))
        a = np.array(aucs)
        print("  %-20s mean %.4f  median %.4f  min %.4f  max %.4f  (%d seeds)"
              % (name, a.mean(), np.median(a), a.min(), a.max(), len(a)),
              flush=True)
        rows.append({"model": name, "auc": round(float(a.mean()), 4),
                     "median": round(float(np.median(a)), 4),
                     "min": round(float(a.min()), 4),
                     "max": round(float(a.max()), 4), "seeds": len(a)})

    best = max(rows, key=lambda r: r["auc"])
    print("\n  best: %s at %.4f" % (best["model"], best["auc"]))
    print("  vs shipped gate %.3f -> %+.4f"
          % (SHIPPED_GATE, best["auc"] - SHIPPED_GATE))
    print("  vs WavLM L12 0.7054 -> %+.4f" % (best["auc"] - 0.7054))
    if best["auc"] - SHIPPED_GATE > 0.02:
        print("  -> a FREE gain on the shipped asset: same 38 features, "
              "same ~12 KB class, no new data and no new Dart path")
    json.dump({"shipped_gate": SHIPPED_GATE, "wavlm_l12": 0.7054,
               "rows": rows, "best": best},
              open(os.path.join(HERE, "arch_sweep_report.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
