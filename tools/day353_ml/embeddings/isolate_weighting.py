"""Day 358 - it is the WEIGHTING, not the regularisation.

v5 (regularised head + corpus_weights)  mean 0.6410  == v4's 0.641, no gain
earlier run (regularised head + class_weight) 0.6709

Same data, same features, same architecture. The only difference was how
rows are weighted, so this isolates it as a 2x2: head x weighting.

corpus_weights upweights every corpus to parity, which means SAVEE's 360 rows
and RAVDESS's 1,056 are pushed to the same total influence as MELD's 7,961
and CREMA-D's 6,171. Three of the four upweighted corpora are ACTED studio
recordings. That forces the model to fit acted speech as hard as
conversational speech, and MELD eval is conversational.
"""
import glob, json, os
import numpy as np
HERE = r"D:\zapsafe\embeddings"
HA = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
SEEDS = (42, 7, 123, 2024, 31337)

def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d["y"]).astype(int)

def corpus_weights(y, corpus):
    w = np.ones(len(y), np.float64); n = len(np.unique(corpus))
    for c in np.unique(corpus):
        m = corpus == c
        w[m] *= len(y) / (n * max(int(m.sum()), 1))
        for lab in (0, 1):
            ml = m & (y == lab)
            if ml.sum(): w[ml] *= m.sum() / (2.0 * max(int(ml.sum()), 1))
    return w

def net(dim, seed, reg_on):
    import tensorflow as tf
    tf.keras.backend.clear_session(); tf.random.set_seed(seed); np.random.seed(seed)
    reg = tf.keras.regularizers.l2(1e-3) if reg_on else None
    dr = 0.5 if reg_on else 0.3
    dr2 = 0.5 if reg_on else 0.2
    return tf.keras.Sequential([
        tf.keras.Input(shape=(dim,)),
        tf.keras.layers.Dense(64, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(dr),
        tf.keras.layers.Dense(32, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.Dropout(dr2),
        tf.keras.layers.Dense(1, activation="sigmoid", kernel_regularizer=reg)])

import tensorflow as tf
from sklearn.metrics import roc_auc_score
Xs, ys, cs = [], [], []
for f in sorted(glob.glob(os.path.join(HA, "feat_*.npz"))):
    t = os.path.basename(f)[5:-4]
    if t == "meld_eval": continue
    X, y = load(f); Xs.append(X); ys.append(y); cs.append(np.full(len(y), t))
Xtr = np.vstack(Xs); ytr = np.concatenate(ys); ctr = np.concatenate(cs)
Xe, ye = load(os.path.join(HA, "feat_meld_eval.npz"))
mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
Z = lambda A: ((A - mu) / sd).astype(np.float32)
cw = corpus_weights(ytr, ctr)
n1, n0 = int(ytr.sum()), int((1-ytr).sum())
clsw = {0: len(ytr)/(2.0*max(n0,1)), 1: len(ytr)/(2.0*max(n1,1))}

rows = {}
for reg_on in (False, True):
    for wname in ("corpus_weights", "class_weight"):
        aucs = []
        for s in SEEDS:
            m = net(Xtr.shape[1], s, reg_on)
            m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                      loss="binary_crossentropy", metrics=[tf.keras.metrics.AUC(name="auc")])
            kw = {"sample_weight": cw} if wname == "corpus_weights" else {"class_weight": clsw}
            m.fit(Z(Xtr), ytr, epochs=60, batch_size=128, verbose=0, **kw)
            aucs.append(float(roc_auc_score(ye, m.predict(Z(Xe), verbose=0).ravel())))
        a = np.array(aucs)
        key = "%s + %s" % ("regularised" if reg_on else "v4 head", wname)
        rows[key] = {"mean": round(float(a.mean()),4), "min": round(float(a.min()),4), "max": round(float(a.max()),4)}
        print("  %-34s mean %.4f  (min %.4f max %.4f)" % (key, a.mean(), a.min(), a.max()), flush=True)
print("\n  v4 shipped, gate: 0.641")
best = max(rows.items(), key=lambda kv: kv[1]["mean"])
print("  best: %s at %.4f  (%+.4f vs gate)" % (best[0], best[1]["mean"], best[1]["mean"]-0.641))
json.dump(rows, open(os.path.join(HERE,"isolate_weighting.json"),"w"), indent=2)
