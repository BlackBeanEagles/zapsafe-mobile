"""Day 358 - v5 has a better AUC and a dead operating point. Fix the threshold.

The gate reported:
    v4   AUC 0.641   rec@0.5 = 0.664
    v5   AUC 0.671   rec@0.5 = 0.057

AUC is threshold-independent, so the ranking genuinely improved. But L2 1e-3
plus dropout 0.5 compresses the sigmoid toward zero, so the SAME numeric
threshold now sits far out in the tail. Shipping v5 behind the existing 0.45
constant would have produced a detector with a better score and almost no
detections -- a silent regression that the AUC alone would have hidden.

This picks the threshold from v5's own curve, matched to what v4 actually
delivered rather than to a round number.
"""
import json, os
import numpy as np
HA = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
ASSETS = r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile\assets\models"

def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d["y"]).astype(int)

import tensorflow as tf
from sklearn.metrics import roc_auc_score, precision_recall_fscore_support
Xe, ye = load(os.path.join(HA, "feat_meld_eval.npz"))
norm = json.load(open(os.path.join(ASSETS, "h_aggressive_v5_38_norm.json")))
mu = np.array(norm["mean"], np.float64); sd = np.array(norm["std"], np.float64)
Z = ((Xe - mu) / sd).astype(np.float32)

it = tf.lite.Interpreter(model_path=os.path.join(ASSETS, "h_aggressive_v5_38.tflite"))
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
p = np.zeros(len(Z), np.float64)
for i in range(len(Z)):
    it.set_tensor(inp["index"], Z[i:i+1].astype(inp["dtype"])); it.invoke()
    p[i] = float(it.get_tensor(out["index"]).ravel()[0])

print("v5 through the shipped tflite: AUC %.4f" % roc_auc_score(ye, p))
print("score distribution: min %.4f  p50 %.4f  p90 %.4f  p99 %.4f  max %.4f"
      % (p.min(), np.percentile(p,50), np.percentile(p,90), np.percentile(p,99), p.max()))
print("\n  thr    recall  precision   fires%")
rows=[]
for t in (0.05,0.10,0.15,0.20,0.25,0.30,0.35,0.40,0.45,0.50):
    pred = (p >= t).astype(int)
    pr, rc, _, _ = precision_recall_fscore_support(ye, pred, average="binary", zero_division=0)
    rows.append({"t": t, "recall": round(float(rc),3), "precision": round(float(pr),3),
                 "fires_pct": round(100.0*pred.mean(),1)})
    print("  %.2f   %.3f    %.3f      %.1f%%" % (t, rc, pr, 100.0*pred.mean()))

# v4 delivered recall 0.664 at its 0.45 threshold; match that recall
target = 0.664
best = min(rows, key=lambda r: abs(r["recall"] - target))
print("\n  v4 delivered recall %.3f at threshold 0.45" % target)
print("  v5 matches that recall at threshold %.2f (precision %.3f, fires %.1f%%)"
      % (best["t"], best["precision"], best["fires_pct"]))
json.dump({"auc": round(float(roc_auc_score(ye,p)),4), "curve": rows,
           "v4_recall_at_045": target, "recommended_threshold": best["t"],
           "recommended_precision": best["precision"]},
          open(os.path.join(r"D:\zapsafe\embeddings","v5_calibration.json"),"w"), indent=2)
