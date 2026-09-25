"""Day 359 - threshold for the permissive glass model, on 267 positives.

The shipped model's threshold is 0.8754, chosen on THIRTEEN positives
(train_pos 92, eval_real_pos 13). This picks one on the gate's full FSD50K
eval fixture -- 2,226 clips, 267 positives -- and reports the curve so the
choice is visible rather than asserted.
"""
import json, os
import numpy as np
EVALDIR = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval"
ASSETS = r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile\assets\models"
SR, DUR, N_MELS, N_FFT, HOP, FMAX, IMG = 16000, 2.0, 96, 2048, 512, 8000, 96
NEED = int(SR*DUR)
import librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score, precision_recall_fscore_support

def mel_img(y):
    y = np.pad(y,(0,NEED-len(y))) if len(y)<NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y,sr=SR,n_mels=N_MELS,hop_length=HOP,n_fft=N_FFT,fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max); rng=db.max()-db.min()
    nz=(db-db.min())/(rng if rng>1e-8 else 1.0)
    return np.stack([np.resize(nz,(IMG,IMG))]*3,axis=-1).astype(np.float32)

man=json.load(open(os.path.join(EVALDIR,"manifest.json"),encoding="utf-8"))
X,y=[],[]
for m in man:
    p=os.path.join(EVALDIR,"audio",m["fname"])
    if not os.path.exists(p) or os.path.getsize(p)==0: continue
    try: w,_=librosa.load(p,sr=SR,mono=True)
    except Exception: continue
    if len(w)<SR*0.2: continue
    X.append(mel_img(w)); y.append(1 if "Glass" in m.get("labels",[]) else 0)
X=np.stack(X); y=np.asarray(y)
print("fixture %s pos=%d (base rate %.3f)"%(X.shape,y.sum(),y.mean()))

def score(path):
    it=tf.lite.Interpreter(model_path=path); it.allocate_tensors()
    i,o=it.get_input_details()[0],it.get_output_details()[0]
    p=np.zeros(len(X))
    for k in range(len(X)):
        it.set_tensor(i["index"],X[k:k+1].astype(i["dtype"])); it.invoke()
        p[k]=float(it.get_tensor(o["index"]).ravel()[0])
    return p

pn = score("m_glass_permissive_v1.tflite")
po = score(os.path.join(ASSETS,"m_glass_breaking_v3.tflite"))
print("permissive AUC %.4f | shipped NC AUC %.4f"%(roc_auc_score(y,pn),roc_auc_score(y,po)))
print("\n  thr    recall  precision  fires%")
rows=[]
for t in (0.20,0.30,0.40,0.50,0.60,0.70,0.80,0.8754,0.90):
    pr,rc,_,_=precision_recall_fscore_support(y,(pn>=t).astype(int),average="binary",zero_division=0)
    rows.append({"t":round(t,4),"recall":round(float(rc),3),"precision":round(float(pr),3),
                 "fires_pct":round(100.0*float((pn>=t).mean()),1)})
    print("  %.4f  %.3f    %.3f     %.1f%%"%(t,rc,pr,100.0*(pn>=t).mean()))
# shipped behaviour at its own threshold, for parity
pr_o,rc_o,_,_=precision_recall_fscore_support(y,(po>=0.8754).astype(int),average="binary",zero_division=0)
print("\n  shipped NC @0.8754: recall %.3f precision %.3f"%(rc_o,pr_o))
cand=[r for r in rows if r["precision"]>=max(pr_o,0.6)]
best=max(cand,key=lambda r:r["recall"]) if cand else max(rows,key=lambda r:r["recall"]*r["precision"])
print("  recommended: %.4f -> recall %.3f precision %.3f (fires %.1f%%)"
      %(best["t"],best["recall"],best["precision"],best["fires_pct"]))
json.dump({"permissive_auc":round(float(roc_auc_score(y,pn)),4),
           "shipped_auc":round(float(roc_auc_score(y,po)),4),
           "curve":rows,"shipped_at_0.8754":{"recall":round(float(rc_o),3),"precision":round(float(pr_o),3)},
           "recommended":best}, open("glass_calibration.json","w"), indent=2)

# --- Day 359 correction: the DETECTOR ships 0.22, not the recorded 0.8754.
# Day 346C rejected 0.8754 precisely because it was chosen on 13 positives.
# Comparing at 0.8754 compares at a threshold the app never uses.
print("\n=== at the ACTUAL shipped threshold 0.22 ===")
for name, p in (("shipped NC", po), ("permissive", pn)):
    pr, rc, _, _ = precision_recall_fscore_support(y, (p >= 0.22).astype(int),
                                                   average="binary", zero_division=0)
    print("  %-12s recall %.3f  precision %.3f  fires %.1f%%"
          % (name, rc, pr, 100.0*(p >= 0.22).mean()))
print("\n=== permissive, finer sweep near the low end ===")
extra=[]
for t in (0.10,0.15,0.20,0.22,0.25,0.35,0.45,0.55,0.65):
    pr, rc, _, _ = precision_recall_fscore_support(y, (pn >= t).astype(int),
                                                   average="binary", zero_division=0)
    extra.append({"t":t,"recall":round(float(rc),3),"precision":round(float(pr),3),
                  "fires_pct":round(100.0*float((pn>=t).mean()),1)})
    print("  %.2f  recall %.3f  precision %.3f  fires %.1f%%"%(t,rc,pr,100.0*(pn>=t).mean()))
d=json.load(open("glass_calibration.json")); d["at_shipped_022"]={}
for name,p in (("shipped",po),("permissive",pn)):
    pr,rc,_,_=precision_recall_fscore_support(y,(p>=0.22).astype(int),average="binary",zero_division=0)
    d["at_shipped_022"][name]={"recall":round(float(rc),3),"precision":round(float(pr),3)}
d["fine_sweep"]=extra
json.dump(d, open("glass_calibration.json","w"), indent=2)
