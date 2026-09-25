"""Day 358 - the FAIR 38-dim comparison, same protocol as the WavLM run.

The +0.0644 headline compared WavLM against 0.641 -- the gate's measurement
of the SHIPPED .tflite, which was trained by a different script, on slightly
different rows (7,961 train / 2,911 eval vs WavLM's 8,640 / 3,226) and with
a different architecture. That is a cross-pipeline comparison, not a
representation comparison.

This trains the 38-dim features with the IDENTICAL architecture, optimiser,
epochs and class weighting used for the embeddings, on the same task, so the
only thing differing is the representation.
"""
import os, json, numpy as np
HERE = r"D:\zapsafe\embeddings"
WORK = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
import sys
sys.path.insert(0, HERE)
from compare_representations import mlp, boot

def load38(split):
    f = "feat_meld_train.npz" if split == "train" else "feat_meld_eval.npz"
    d = np.load(os.path.join(WORK, f), allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d["y"]).astype(int)

from sklearn.metrics import roc_auc_score
from sklearn.linear_model import LogisticRegression
Xtr, ytr = load38("train"); Xte, yte = load38("eval")
mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
Ztr = ((Xtr-mu)/sd).astype(np.float32); Zte = ((Xte-mu)/sd).astype(np.float32)
print("38-dim  train %s pos=%d | eval %s pos=%d" % (Xtr.shape, ytr.sum(), Xte.shape, yte.sum()))
lr = LogisticRegression(max_iter=3000, class_weight="balanced").fit(Ztr, ytr)
a_lin = float(roc_auc_score(yte, lr.predict_proba(Zte)[:,1]))
p = mlp(Ztr, ytr, Zte, Xtr.shape[1])
a = float(roc_auc_score(yte, p)); lo, hi = boot(yte, p)
print("\n  38-dim SAME PROTOCOL   linear %.4f   MLP %.4f  CI [%.4f, %.4f]" % (a_lin, a, lo, hi))
print("  WavLM layer 12                          0.7054  CI [0.6835, 0.7275]")
print("  honest delta: %+.4f" % (0.7054 - a))
json.dump({"dim38_linear": round(a_lin,4), "dim38_mlp": round(a,4),
           "dim38_ci": [round(lo,4), round(hi,4)], "wavlm_l12": 0.7054,
           "honest_delta": round(0.7054-a,4)},
          open(os.path.join(HERE,"matched_baseline.json"),"w"), indent=2)
