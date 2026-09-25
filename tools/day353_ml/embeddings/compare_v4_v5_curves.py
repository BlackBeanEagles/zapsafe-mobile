"""Day 358 - v4 vs v5 at MATCHED operating points, not matched thresholds.

v5's AUC is higher (0.671 vs 0.641) but its sigmoid is compressed by L2 and
dropout 0.5, so the same numeric threshold means something different. The
question that decides whether v5 is actually better in service is: at the
SAME recall, does v5 give better precision?

A higher AUC implies yes, but implication is not measurement, and the
threshold constant that ships has to come from the curve rather than from
assuming the old one still applies.
"""
import json, os
import numpy as np
HA = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
ASSETS = r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile\assets\models"
HERE = r"D:\zapsafe\embeddings"

def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d["y"]).astype(int)

import tensorflow as tf
from sklearn.metrics import roc_auc_score, precision_recall_curve
Xe, ye = load(os.path.join(HA, "feat_meld_eval.npz"))
print("eval n=%d pos=%d (base rate %.3f)" % (len(ye), ye.sum(), ye.mean()))

def score(model_path, norm_path):
    n = json.load(open(norm_path))
    mu = np.array(n["mean"], np.float64); sd = np.array(n["std"], np.float64)
    Z = ((Xe - mu) / sd).astype(np.float32)
    it = tf.lite.Interpreter(model_path=model_path); it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    p = np.zeros(len(Z), np.float64)
    for k in range(len(Z)):
        it.set_tensor(i["index"], Z[k:k+1].astype(i["dtype"])); it.invoke()
        p[k] = float(it.get_tensor(o["index"]).ravel()[0])
    return p

p4 = score(os.path.join(HERE,"v4_restored.tflite"), os.path.join(HERE,"v4_restored_norm.json"))
p5 = score(os.path.join(ASSETS,"h_aggressive_v5_38.tflite"), os.path.join(ASSETS,"h_aggressive_v5_38_norm.json"))
print("v4 AUC %.4f | v5 AUC %.4f" % (roc_auc_score(ye,p4), roc_auc_score(ye,p5)))

def prec_at_recall(p, target):
    pr, rc, th = precision_recall_curve(ye, p)
    # precision_recall_curve returns arrays where rc is decreasing
    idx = np.argmin(np.abs(rc - target))
    t = th[min(idx, len(th)-1)]
    return float(pr[idx]), float(rc[idx]), float(t)

print("\n  precision at matched recall:")
print("  recall   v4 prec (thr)      v5 prec (thr)     v5-v4")
rows=[]
for target in (0.80, 0.70, 0.664, 0.60, 0.50, 0.40):
    a4, r4, t4 = prec_at_recall(p4, target)
    a5, r5, t5 = prec_at_recall(p5, target)
    rows.append({"recall": target, "v4_prec": round(a4,3), "v4_thr": round(t4,3),
                 "v5_prec": round(a5,3), "v5_thr": round(t5,3), "delta": round(a5-a4,3)})
    print("  %.2f     %.3f (%.3f)      %.3f (%.3f)     %+.3f" % (target, a4, t4, a5, t5, a5-a4))

wins = sum(1 for r in rows if r["delta"] > 0)
print("\n  v5 better precision at %d of %d recall levels" % (wins, len(rows)))
# v4 ships at 0.45; what recall does it actually deliver there?
r4_at_045 = float(((p4 >= 0.45) & (ye == 1)).sum() / max(ye.sum(),1))
pr4_at_045 = float(((p4 >= 0.45) & (ye == 1)).sum() / max((p4 >= 0.45).sum(),1))
print("  v4 at its shipped threshold 0.45: recall %.3f precision %.3f" % (r4_at_045, pr4_at_045))
m = min(rows, key=lambda r: abs(r["recall"] - r4_at_045))
print("  to match that recall, v5 needs threshold ~%.3f (precision %.3f)" % (m["v5_thr"], m["v5_prec"]))
json.dump({"v4_auc": round(float(roc_auc_score(ye,p4)),4), "v5_auc": round(float(roc_auc_score(ye,p5)),4),
           "matched_recall": rows, "v5_better_at": wins, "of": len(rows),
           "v4_shipped_thr_045": {"recall": round(r4_at_045,3), "precision": round(pr4_at_045,3)}},
          open(os.path.join(HERE,"v4_v5_curves.json"),"w"), indent=2)
