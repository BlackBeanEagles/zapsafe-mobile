"""Day 360 - can h_aggressive drop its two NC corpora and hold?

"No permissive replacement exists" was too quick. h_aggressive's NC flag
comes from exactly TWO of its five corpora:

    CREMA-D   6,171 clips  3,813 pos   Open Database License   <- permissive
    TESS      2,000 clips  1,200 pos   CC BY-NC 4.0            <- NC
    RAVDESS   1,056 clips    576 pos   CC BY-NC-SA 4.0         <- NC
    SAVEE       360 clips    180 pos   research
    MELD      7,961 clips  1,626 pos   research

Dropping TESS and RAVDESS leaves 14,492 clips and 5,619 positives -- 83% of
the rows and 76% of the positives. That is not obviously fatal, and it was
never measured.

WHY IT MIGHT STILL FAIL: Day 358 showed that dropping corpora is not free.
MELD-only scored 0.6869 in-domain but COLLAPSED to 0.5088 on NaturalVoices,
while the five-corpus recipe reached 0.5622 -- the acted corpora were buying
generalisation. TESS and RAVDESS are both acted, so removing them removes
some of exactly that.

So this is scored on THREE sets, not one:
    MELD eval        in-domain-ish, the gate's own number
    EQ4You           cross-corpus, neither arm trains on it
    NaturalVoices    cross-corpus, neither arm trains on it

SHIP RULE, fixed before running: the NC-free model must hold MELD eval
within 0.01 of the current 0.671 AND not lose more than 0.02 on either
cross-corpus set. Clearing the licence flag by quietly giving up
generalisation would be a trade dressed as a fix.

Recipe is Day 358's: class_weight (NOT corpus_weights, which was costing
0.03) plus dropout 0.5 and L2 1e-3.
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
NC_CORPORA = {"tess", "ravdess"}
CURRENT = 0.671          # v5 as the gate measures it


def load(p, key="y"):
    d = np.load(p, allow_pickle=True)
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


def run(tag, keep, evals):
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    Xs, ys = [], []
    used = []
    for f in sorted(glob.glob(os.path.join(HA, "feat_*.npz"))):
        t = os.path.basename(f)[5:-4]
        if t == "meld_eval" or not keep(t):
            continue
        X, y = load(f)
        Xs.append(X)
        ys.append(y)
        used.append("%s(%d)" % (t, len(y)))
    Xtr = np.vstack(Xs)
    ytr = np.concatenate(ys)
    mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
    Z = lambda A: ((A - mu) / sd).astype(np.float32)
    n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
    clsw = {0: len(ytr) / (2.0 * max(n0, 1)),
            1: len(ytr) / (2.0 * max(n1, 1))}
    out = {k: [] for k in evals}
    for s in SEEDS:
        m = net(Xtr.shape[1], s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        m.fit(Z(Xtr), ytr, epochs=60, batch_size=128, verbose=0,
              class_weight=clsw)
        for k, (Xe, ye) in evals.items():
            out[k].append(float(roc_auc_score(
                ye, m.predict(Z(Xe), verbose=0).ravel())))
    print("  %-22s %s  n=%d pos=%d" % (tag, ",".join(used), len(ytr),
                                       ytr.sum()))
    res = {}
    for k, v in out.items():
        a = np.array(v)
        res[k] = {"mean": round(float(a.mean()), 4),
                  "min": round(float(a.min()), 4)}
        print("     %-16s mean %.4f (min %.4f)" % (k, a.mean(), a.min()),
              flush=True)
    return res


def main():
    evals = {}
    Xe, ye = load(os.path.join(HA, "feat_meld_eval.npz"))
    evals["MELD eval"] = (Xe, ye)
    for name, p in (("EQ4You", EQ), ("NaturalVoices", NV)):
        if os.path.exists(p):
            evals[name] = load(p)
    print("evals: %s\n" % list(evals))

    allc = run("A: all 5 (current)", lambda t: True, evals)
    print()
    ncf = run("B: NC-free (no TESS/RAVDESS)",
              lambda t: t.lower() not in NC_CORPORA, evals)

    print("\n" + "=" * 60)
    ok = True
    for k in evals:
        d = ncf[k]["mean"] - allc[k]["mean"]
        limit = 0.01 if k == "MELD eval" else 0.02
        bad = d < -limit
        ok = ok and not bad
        print("  %-16s B-A %+.4f   (limit -%.2f) %s"
              % (k, d, limit, "FAIL" if bad else "ok"))
    print("  -> %s" % ("NC-FREE HOLDS - drop TESS and RAVDESS, clearing the "
                       "licence flag at no measured cost" if ok else
                       "NC-FREE LOSES - this is a licence-for-accuracy "
                       "trade, reporting rather than shipping"))
    json.dump({"all_five": allc, "nc_free": ncf, "holds": ok,
               "current_gate": CURRENT},
              open(os.path.join(HERE, "h_aggressive_ncfree.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
