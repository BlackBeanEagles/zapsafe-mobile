"""Day 328 - k_confinement_decorrelated: does it use IMU, or just the light scalar?"""
import glob, os, numpy as np, tensorflow as tf
from sklearn.metrics import roc_auc_score
np.random.seed(0)
REPO=r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile"
DS=r"C:\Users\hridy\Desktop\zapsafe\ml_datasets"
IMU_LEN=128
IM=np.array([18.82670783996582,-1.5446271896362305,3.4640188217163086,
             -0.2883187234401703,0.15556541085243225,3.3361189365386963],"float32")
IS=np.array([33.07301712036133,15.915735244750977,6.720554828643799,
             2.901996374130249,1.4621796607971191,5.33461332321167],"float32")

def pamap(cols,n):
    out=[]
    for dat in sorted(glob.glob(os.path.join(DS,"motion","DS14_PAMAP2","**","*.dat"),recursive=True))[:6]:
        rows=[]
        for ln in open(dat):
            f=ln.split()
            if len(f)<33: continue
            rows.append([np.nan if x=="NaN" else float(x) for x in f[:33]])
        if not rows: continue
        a=np.array(rows,"float64")
        for j in range(a.shape[1]):
            c=a[:,j]; idx=np.where(~np.isnan(c))[0]
            if len(idx): c[:idx[0]]=c[idx[0]]
            for i in range(1,len(c)):
                if np.isnan(c[i]): c[i]=c[i-1]
        a=np.nan_to_num(a)[::2]
        sel=a[:,list(cols)].astype("float32")
        for s in range(0,len(sel)-IMU_LEN,IMU_LEN):
            out.append(sel[s:s+IMU_LEN].copy())
            if len(out)>=n: return out
    return out

it=tf.lite.Interpreter(model_path=os.path.join(REPO,"assets","models","k_confinement_decorrelated.tflite"))
it.allocate_tensors()
ins={d["name"].lower():d for d in it.get_input_details()}
i_imu=[d for k,d in ins.items() if "imu" in k][0]
i_lt =[d for k,d in ins.items() if "light" in k][0]
od=it.get_output_details()[0]

def score(imu,light):
    it.set_tensor(i_imu["index"], (((imu-IM)/IS)[None]).astype("float32"))
    it.set_tensor(i_lt["index"], np.full((1,32,1),light,"float32"))
    it.invoke()
    return float(np.ravel(it.get_tensor(od["index"]))[0])

N=40
imu_tr=pamap((20,21,22,23,24,25),N)          # training slice: temp + duplicated acc
imu_ph=pamap((21,22,23,27,28,29),N)          # real acc(m/s2) + real gyro(rad/s)
n=min(N,len(imu_tr),len(imu_ph))
print(f"windows={n}  training-slice ch0 mean={np.mean([w[:,0].mean() for w in imu_tr[:n]]):.2f}"
      f"   phone-real ch0 mean={np.mean([w[:,0].mean() for w in imu_ph[:n]]):.2f}")
print(f"declared kImuMean[0]={IM[0]:.2f} kImuStd[0]={IS[0]:.2f}\n")

print("=== light sensitivity with REAL phone IMU held identical ===")
for lt in (0.0,0.05,0.2,0.5,0.85):
    s=[score(imu_ph[i],lt) for i in range(n)]
    print(f"  light={lt:<5} mean={np.mean(s):.4f}  min={min(s):.4f} max={max(s):.4f}  fires>=0.5: {sum(1 for v in s if v>=0.5)}/{n}")

print("\n=== IMU sensitivity with light held identical ===")
for lt in (0.0,0.85):
    a=roc_auc_score([1]*n+[0]*n,[score(w,lt) for w in imu_ph[:n]]+[score(w,lt) for w in imu_tr[:n]])
    print(f"  light={lt:<5} AUC(phone-real IMU vs training-slice IMU) = {a:.4f}")

print("\n=== how much does light alone explain? (dark vs lit, IMU identical) ===")
a=roc_auc_score([1]*n+[0]*n,[score(imu_ph[i],0.0) for i in range(n)]+[score(imu_ph[i],0.85) for i in range(n)])
print(f"  AUC(dark vs lit, same real IMU) = {a:.4f}")
