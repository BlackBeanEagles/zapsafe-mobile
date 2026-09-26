"""Day 360 - v6's threshold, measured not assumed.

v5 ships 0.23, chosen to reproduce v4's operating point exactly. v6 drops
TESS and RAVDESS, which changes the training distribution and therefore the
sigmoid, so the constant cannot be carried across without checking -- that
mistake was caught once already when v5's regularisation compressed the
output and 0.45 would have silenced the detector.
"""
import json, os, numpy as np
HA = r"C:\Users\hridy\Desktop\zapsafe\work\h_aggressive_v4"
ASSETS = r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile\assets\models"
def load(p):
    d=np.load(p,allow_pickle=True)
    return np.nan_to_num(d["X"].astype(np.float32),nan=0.0,posinf=0.0,neginf=0.0), np.asarray(d["y"]).astype(int)
import tensorflow as tf
from sklearn.metrics import roc_auc_score, precision_recall_fscore_support
Xe, ye = load(os.path.join(HA,"feat_meld_eval.npz"))
n=json.load(open(os.path.join(ASSETS,"h_aggressive_v6_38_norm.json")))
mu=np.array(n["mean"]); sd=np.array(n["std"])
Z=((Xe-mu)/sd).astype(np.float32)
it=tf.lite.Interpreter(model_path=os.path.join(ASSETS,"h_aggressive_v6_38.tflite")); it.allocate_tensors()
i,o=it.get_input_details()[0],it.get_output_details()[0]
p=np.zeros(len(Z))
for k in range(len(Z)):
    it.set_tensor(i["index"],Z[k:k+1].astype(i["dtype"])); it.invoke()
    p[k]=float(it.get_tensor(o["index"]).ravel()[0])
print("v6 AUC %.4f | score p50 %.3f p90 %.3f max %.3f"%(roc_auc_score(ye,p),np.percentile(p,50),np.percentile(p,90),p.max()))
print("\n  thr    recall  precision  fires%")
rows=[]
for t in (0.15,0.20,0.23,0.25,0.30,0.35,0.40,0.45,0.50):
    pr,rc,_,_=precision_recall_fscore_support(ye,(p>=t).astype(int),average="binary",zero_division=0)
    rows.append({"t":t,"recall":round(float(rc),3),"precision":round(float(pr),3),"fires":round(100.0*float((p>=t).mean()),1)})
    print("  %.2f   %.3f    %.3f     %.1f%%"%(t,rc,pr,100.0*(p>=t).mean()))
# v5 at 0.23 delivered recall 0.758 precision 0.280 -- match that recall
TGT=0.758
best=min(rows,key=lambda r:abs(r["recall"]-TGT))
print("\n  v5 @0.23 delivered recall 0.758 precision 0.280")
print("  v6 matches that recall at t=%.2f -> recall %.3f precision %.3f"%(best["t"],best["recall"],best["precision"]))
json.dump({"auc":round(float(roc_auc_score(ye,p)),4),"curve":rows,"match":best},open("v6_calibration.json","w"),indent=2)
