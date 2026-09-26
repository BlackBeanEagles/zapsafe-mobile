"""Compare permissive vs shipped gunshot at the ACTUAL shipped threshold 0.70."""
import json, os, numpy as np
import importlib.util
spec = importlib.util.spec_from_file_location("g", "build_train_gunshot.py")
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
import tensorflow as tf
from sklearn.metrics import roc_auc_score, precision_recall_fscore_support
Xe, ye = g.load_eval()
print("eval %s pos=%d"%(Xe.shape, ye.sum()))
def score(p):
    it=tf.lite.Interpreter(model_path=p); it.allocate_tensors()
    i,o=it.get_input_details()[0],it.get_output_details()[0]
    out=np.zeros(len(Xe))
    for k in range(len(Xe)):
        it.set_tensor(i["index"],Xe[k:k+1].astype(i["dtype"])); it.invoke()
        out[k]=float(it.get_tensor(o["index"]).ravel()[0])
    return out
po = score(os.path.join(g.ASSETS, g.SHIPPED))
pn = score("mg_gunshot_permissive_v1.tflite")
print("shipped AUC %.4f | permissive AUC %.4f"%(roc_auc_score(ye,po),roc_auc_score(ye,pn)))
print("\n  at the SHIPPED threshold 0.70:")
res={}
for name,p in (("shipped NC",po),("permissive",pn)):
    pr,rc,_,_=precision_recall_fscore_support(ye,(p>=0.70).astype(int),average="binary",zero_division=0)
    res[name]={"recall":round(float(rc),3),"precision":round(float(pr),3),"fires_pct":round(100.0*float((p>=0.70).mean()),1)}
    print("    %-12s recall %.3f  precision %.3f  fires %.1f%%"%(name,rc,pr,100.0*(p>=0.70).mean()))
# where does permissive match the shipped recall?
tgt=res["shipped NC"]["recall"]
best=None
for t in np.arange(0.05,0.96,0.01):
    pr,rc,_,_=precision_recall_fscore_support(ye,(pn>=t).astype(int),average="binary",zero_division=0)
    if rc>=tgt and (best is None or t>best[0]): best=(float(t),float(rc),float(pr))
if best: print("    permissive matches that recall at t=%.2f -> recall %.3f precision %.3f"%best)
json.dump({"at_070":res,"match_point":best}, open("gunshot_calibration.json","w"), indent=2)
