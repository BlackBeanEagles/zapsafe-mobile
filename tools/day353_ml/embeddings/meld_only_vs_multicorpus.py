"""Day 358 - is MELD-only genuinely better, or just in-domain?

THE OBSERVATION
===============
    shipped h_aggressive_v4 (5 corpora, 17,548 rows)   0.641 on MELD eval
    same 64/32 arch, MELD train ONLY (7,961 rows)      0.6672  (5 seeds)
    64/32 + dropout 0.5 + L2, MELD train only          0.6875  (5 seeds)

Four of the shipped model's five corpora are ACTED (CREMA-D, TESS, RAVDESS,
SAVEE). Day 353 showed ESD was not merely useless but actively harmful --
its per-feature direction correlation with conversational speech was -0.56.
The same may be true of the rest.

THE CONFOUND, WHICH IS REAL
===========================
Training on MELD train and scoring on MELD test+dev is IN-DOMAIN. Same
programme, same actors, same broadcast chain. A MELD-only model should beat
a multi-corpus one there almost by construction, and "improving" the gate
number that way is partly gaming the metric rather than the model.

So MELD eval cannot settle it. What can: score both on corpora NEITHER
trains on.

THE TEST
========
Two training sets, four evaluations:

    train A: MELD train only
    train B: the shipped five corpora (CREMA-D, TESS, RAVDESS, SAVEE, MELD)

    eval 1: MELD test+dev        in-domain for A, cross for B
    eval 2: EQ4You               cross-corpus for BOTH
    eval 3: NaturalVoices        cross-corpus for BOTH

If A wins on EQ4You and NaturalVoices as well, the acted corpora are hurting
and dropping them is a real improvement. If A wins only on MELD, it is
in-domain overfitting and the shipped multi-corpus recipe is right.

Both arms use the SAME regularised head (64/32, dropout 0.5, L2 1e-3) so the
architecture is not a confounder, and every number is the mean of five seeds
because single runs on these sets bounce ~0.02.
"""
from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
HA = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
EQ = r"D:\zapsafe\eq4you\eq4you_yin2048.npz"
NV = r"D:\zapsafe\naturalvoices\nv_yin2048.npz"
SEEDS = (42, 7, 123, 2024, 31337)


def load(path, key="y"):
    d = np.load(path, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d[key]).astype(int)


def net(dim, seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    reg = tf.keras.regularizers.l2(1e-3)
    return tf.keras.Sequential([
        tf.keras.Input(shape=(dim,)),
        tf.keras.layers.Dense(64, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.5),
        tf.keras.layers.Dense(32, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.Dropout(0.5),
        tf.keras.layers.Dense(1, activation="sigmoid",
                              kernel_regularizer=reg),
    ])


def run(name, Xtr, ytr, evals):
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
    Z = lambda A: ((A - mu) / sd).astype(np.float32)
    out = {k: [] for k in evals}
    for s in SEEDS:
        m = net(Xtr.shape[1], s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
        m.fit(Z(Xtr), ytr, epochs=60, batch_size=128, verbose=0,
              class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                            1: len(ytr) / (2.0 * max(n1, 1))})
        for k, (Xe, ye) in evals.items():
            out[k].append(float(roc_auc_score(
                ye, m.predict(Z(Xe), verbose=0).ravel())))
    res = {}
    print("  %-26s n_train=%d" % (name, len(ytr)))
    for k, v in out.items():
        a = np.array(v)
        res[k] = {"mean": round(float(a.mean()), 4),
                  "min": round(float(a.min()), 4),
                  "max": round(float(a.max()), 4)}
        print("     %-16s mean %.4f  (min %.4f max %.4f)"
              % (k, a.mean(), a.min(), a.max()), flush=True)
    return res


def main():
    Xm, ym = load(os.path.join(HA, "feat_meld_train.npz"))
    parts = []
    for f in sorted(glob.glob(os.path.join(HA, "feat_*.npz"))):
        t = os.path.basename(f)[5:-4]
        if t == "meld_eval":
            continue
        parts.append(load(f))
    Xa = np.vstack([p[0] for p in parts])
    ya = np.concatenate([p[1] for p in parts])

    evals = {}
    Xe, ye = load(os.path.join(HA, "feat_meld_eval.npz"))
    evals["MELD eval"] = (Xe, ye)
    if os.path.exists(EQ):
        evals["EQ4You"] = load(EQ)
    if os.path.exists(NV):
        evals["NaturalVoices"] = load(NV)
    print("evals: %s\n" % list(evals))

    a = run("A: MELD train only", Xm, ym, evals)
    print()
    b = run("B: five corpora (shipped)", Xa, ya, evals)

    print("\n" + "=" * 62)
    wins = 0
    cross = 0
    for k in evals:
        d = a[k]["mean"] - b[k]["mean"]
        tag = "in-domain for A" if k == "MELD eval" else "cross for BOTH"
        print("  %-16s A-B %+.4f   (%s)" % (k, d, tag))
        if k != "MELD eval":
            cross += 1
            if d > 0:
                wins += 1
    if cross and wins == cross:
        v = ("DROP THE ACTED CORPORA - MELD-only wins on every corpus "
             "neither arm trains on, so the gain is not in-domain")
    elif cross and wins == 0:
        v = ("KEEP THE MULTI-CORPUS RECIPE - MELD-only wins only where it "
             "has the in-domain advantage")
    else:
        v = ("MIXED - %d of %d cross-corpus evals favour MELD-only; not "
             "decisive" % (wins, cross))
    print("  -> %s" % v)
    json.dump({"meld_only": a, "five_corpora": b, "verdict": v},
              open(os.path.join(HERE, "meldonly_report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
