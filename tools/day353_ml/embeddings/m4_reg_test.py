"""Day 358 - does m4 get the same free gain h_aggressive just got?

h_aggressive went 0.641 -> 0.671 from the recipe, and the 2x2 showed the
weighting dominated with a smaller regularisation effect on top
(0.6649 -> 0.6736 under class_weight).

m4 already uses class_weight and trains on ONE corpus, so the weighting half
does not apply -- there is nothing to rebalance. But its head is the same
over-parameterised shape (128/64, dropout 0.3/0.2) that a linear model beat
on h_aggressive's features, so the regularisation half might transfer.

Scored on the SAME held-out natural rows the gate uses for m4, so the number
is directly comparable to the gate's 0.648.
"""
import os, json
import numpy as np
W = r"C:\Users\hridy\Desktop\zapsafe\work"
SEEDS = (42, 7, 123, 2024, 31337)
GATE = 0.648

def load(p, ykey="y"):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d[ykey]).astype(int), (d["spk"] if "spk" in d.files else None)

import tensorflow as tf
from sklearn.metrics import roc_auc_score
from sklearn.linear_model import LogisticRegression

Xn, yn, spk = load(os.path.join(W, "m4_m5_v2", "feat_meld_train.npz"))
Xe, ye, _ = load(os.path.join(W, "m4_m5_v5_noesd", "eval_m4_natural.npz"))
# the gate's eval rows ARE the held-out speakers of this train set, so they
# must be removed from training or this measures memorisation
rng = np.random.RandomState(42)
groups = np.unique(spk); k = max(1, int(round(len(groups)*0.25)))
held = set(rng.permutation(groups)[:k].tolist())
tr = np.array([s not in held for s in spk])
Xtr, ytr = Xn[tr], yn[tr]
print("train %s pos=%d | gate eval %s pos=%d" % (Xtr.shape, ytr.sum(), Xe.shape, ye.sum()))
mu, sd = Xtr.mean(0), Xtr.std(0)+1e-8
Z = lambda A: ((A-mu)/sd).astype(np.float32)
n1, n0 = int(ytr.sum()), int((1-ytr).sum())
clsw = {0: len(ytr)/(2.0*max(n0,1)), 1: len(ytr)/(2.0*max(n1,1))}

def net(reg_on, seed):
    tf.keras.backend.clear_session(); tf.random.set_seed(seed); np.random.seed(seed)
    reg = tf.keras.regularizers.l2(1e-3) if reg_on else None
    d1, d2 = (0.5, 0.5) if reg_on else (0.3, 0.2)
    return tf.keras.Sequential([
        tf.keras.Input(shape=(Xtr.shape[1],)),
        tf.keras.layers.Dense(128, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.BatchNormalization(), tf.keras.layers.Dropout(d1),
        tf.keras.layers.Dense(64, activation="relu", kernel_regularizer=reg),
        tf.keras.layers.Dropout(d2),
        tf.keras.layers.Dense(1, activation="sigmoid", kernel_regularizer=reg)])

lr = LogisticRegression(max_iter=4000, class_weight="balanced").fit(Z(Xtr), ytr)
print("  logistic                %.4f" % roc_auc_score(ye, lr.predict_proba(Z(Xe))[:,1]))
res={}
for reg_on, name in ((False,"current head d0.3/0.2"), (True,"regularised d0.5 + L2")):
    a=[]
    for s in SEEDS:
        m = net(reg_on, s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        m.fit(Z(Xtr), ytr, epochs=60, batch_size=128, verbose=0, class_weight=clsw)
        a.append(float(roc_auc_score(ye, m.predict(Z(Xe), verbose=0).ravel())))
    a=np.array(a); res[name]={"mean":round(float(a.mean()),4),"min":round(float(a.min()),4),"max":round(float(a.max()),4)}
    print("  %-24s mean %.4f (min %.4f max %.4f)" % (name, a.mean(), a.min(), a.max()), flush=True)
b=max(res.items(), key=lambda kv: kv[1]["mean"])
print("\n  gate (shipped m4): %.3f" % GATE)
print("  best: %s at %.4f  (%+.4f vs gate)" % (b[0], b[1]["mean"], b[1]["mean"]-GATE))
print("  -> %s" % ("WORTH RETRAINING" if b[1]["mean"]-GATE >= 0.02 and b[1]["min"] > GATE
                   else "NOT WORTH IT - gain below 0.02 or not seed-stable"))
json.dump(res, open("m4_reg_test.json","w"), indent=2)
