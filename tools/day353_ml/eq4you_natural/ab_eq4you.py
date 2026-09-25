"""Day 353 - does adding EQ4You make m4 or h_aggressive better on MELD?

THE DESIGN
==========
EQ4You rows are TRAINING-SIDE ONLY. Both arms are scored on exactly the same
held-out MELD rows, which neither arm ever trains on:

    h_aggressive  eval = work/h_aggressive_v4/feat_meld_eval.npz  (2,911)
    m4            eval = work/m4_m5_crosscorpus/feat_meld_yin.npz (3,047)

So EQ4You cannot leak into the measurement, and the only thing that differs
between the arms is whether those extra rows were available to learn from.
The bootstrap uses the SAME resample indices for both arms, so the CI is on
the paired difference rather than on each arm separately.

THE RULE, FIXED BEFORE RUNNING
==============================
Adopt EQ4You only if the paired delta on the MELD eval set has a 95% CI
that EXCLUDES ZERO upward.

"It did not hurt" is not a reason to add a corpus. Every corpus added is
another licence to track, another provenance line in the gate, and another
way for a future model to partition instead of generalise. The bar is that
it demonstrably helps the deployment domain.

TWO LABEL DEFINITIONS, BOTH TRIED
=================================
    strict  angry + veryAngry        241 positives
    wide    + slightlyAngry          934 positives

WHAT EQ4You CANNOT FIX, STATED UP FRONT
=====================================
h_aggressive's positive class is angry OR fearful OR disgusted. EQ4You has
anger only. So even in the best case EQ4You reinforces one third of the
target definition, and a gain here should not be read as the model getting
better at fear or disgust.
"""
from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
SEED = 42


def load(p, ykey="y"):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    spk = d["spk"] if "spk" in d.files else np.arange(len(d["X"])).astype(str)
    return X, np.asarray(d[ykey]).astype(int), np.asarray(spk)


def balanced_w(y, corpus):
    w = np.ones(len(y), np.float64)
    n = len(np.unique(corpus))
    for c in np.unique(corpus):
        m = corpus == c
        w[m] *= len(y) / (n * max(int(m.sum()), 1))
        for lab in (0, 1):
            ml = m & (y == lab)
            if ml.sum():
                w[ml] *= m.sum() / (2.0 * max(int(ml.sum()), 1))
    return w


def fit(Xtr, ytr, wtr, Xva, yva, dim, units):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(SEED)
    np.random.seed(SEED)
    a, b = units
    m = tf.keras.Sequential([
        tf.keras.Input(shape=(dim,)),
        tf.keras.layers.Dense(a, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(b, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=150, batch_size=128,
          verbose=0, sample_weight=wtr,
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])
    return m


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


def run(tag, base_sets, eval_path, eq4you_path, ykey, units):
    from sklearn.metrics import roc_auc_score
    Xb = np.vstack([s[0] for s in base_sets])
    yb = np.concatenate([s[1] for s in base_sets])
    cb = np.concatenate([np.full(len(s[1]), s[2]) for s in base_sets])
    Xe, ye, _ = load(eval_path)
    Xl, yl, _ = load(eq4you_path, ykey)

    print("\n" + "=" * 72)
    print("=== %s   EQ4You labels: %s ===" % (tag, ykey))
    print("  base  %s pos=%d from %d corpora"
          % (Xb.shape, yb.sum(), len(base_sets)))
    print("  EQ4You  %s pos=%d" % (Xl.shape, yl.sum()))
    print("  eval  %s pos=%d  (MELD, never trained on by either arm)"
          % (Xe.shape, ye.sum()))

    preds, res = {}, {}
    for arm in ("WITHOUT", "WITH"):
        if arm == "WITH":
            Xtr = np.vstack([Xb, Xl])
            ytr = np.concatenate([yb, yl])
            ctr = np.concatenate([cb, np.full(len(yl), "eq4you")])
        else:
            Xtr, ytr, ctr = Xb, yb, cb
        mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8

        def Z(A):
            return ((A - mu) / sd).astype(np.float32)

        m = fit(Z(Xtr), ytr, balanced_w(ytr, ctr), Z(Xe), ye,
                Xb.shape[1], units)
        p = m.predict(Z(Xe), verbose=0).ravel()
        preds[arm] = p
        res[arm] = round(float(roc_auc_score(ye, p)), 4)
        print("  %-8s MELD eval %.4f   (n_train=%d)"
              % (arm, res[arm], len(ytr)))

    lo, hi, mean = paired_ci(ye, preds["WITH"], preds["WITHOUT"])
    print("\n  PAIRED delta (WITH - WITHOUT) %+.4f 95%% CI [%+.4f, %+.4f]"
          % (mean, lo, hi))
    adopt = lo > 0.0
    print("  -> %s" % ("ADOPT EQ4You" if adopt else
                       "DO NOT ADOPT -- no demonstrated gain on MELD"))
    return {"without": res["WITHOUT"], "with": res["WITH"],
            "paired_delta": round(mean, 4),
            "paired_ci95": [round(lo, 4), round(hi, 4)], "adopt": bool(adopt)}


def main():
    rep = {}
    # ---- h_aggressive, 2048/512 space ----
    ha = os.path.join(WORK, "h_aggressive_v4")
    base_ha = []
    for f in sorted(glob.glob(os.path.join(ha, "feat_*.npz"))):
        t = os.path.basename(f)[5:-4]
        if t == "meld_eval":
            continue
        X, y, _ = load(f)
        base_ha.append((X, y, t))
    # ---- m4, 512/256 space ----
    Xm, ym, _ = load(os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"))
    base_m4 = [(Xm, ym, "meld_train")]

    for ykey in ("y",):
        rep["h_aggressive_" + ykey] = run(
            "h_aggressive v4 (2048/512)", base_ha,
            os.path.join(ha, "feat_meld_eval.npz"),
            r"D:\zapsafe\eq4you\eq4you_yin2048.npz", ykey, (64, 32))
        rep["m4_" + ykey] = run(
            "m4 vocal stress (512/256)", base_m4,
            os.path.join(WORK, "m4_m5_crosscorpus", "feat_meld_yin.npz"),
            r"D:\zapsafe\eq4you\eq4you_yin512.npz", ykey, (128, 64))

    json.dump(rep, open(os.path.join(HERE, "ab_report.json"), "w"), indent=2)
    print("\nab_report written")


if __name__ == "__main__":
    main()
