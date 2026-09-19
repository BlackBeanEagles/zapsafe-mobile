"""Day 328 - i_vehicle_crash: g (training) vs m/s^2 (what the app feeds)."""
import glob, os, numpy as np, librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score
np.random.seed(0)
REPO=r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile"
DS=r"C:\Users\hridy\Desktop\zapsafe\ml_datasets"
SR,DUR,N_MELS,IMU_LEN,G=16000,2.0,64,128,8.0
IMG_H=IMG_W=64

def norm_imu(w): return np.clip(w,-G,G)/G
def spike(w):
    out=w.copy(); mid=IMU_LEN//2; n=min(10,IMU_LEN-mid-1)
    out[mid:mid+n,0]-=np.linspace(1.5,5.5,n)
    out[mid:mid+n,1]+=np.random.uniform(-1.0,1.0,n)
    out[mid:mid+n,5]+=np.linspace(0,2.5,n)
    return norm_imu(out)

def mel_img(y):
    n=int(DUR*SR); y=np.pad(y,(0,n-len(y))) if len(y)<n else y[:n]
    m=librosa.feature.melspectrogram(y=y,sr=SR,n_mels=N_MELS,fmax=8000)
    d=librosa.power_to_db(m,ref=np.max); mn,mx=d.min(),d.max()
    img=np.resize((d-mn)/(mx-mn+1e-8),(IMG_H,IMG_W))
    return np.stack([img]*3,-1).astype("float32")

# real UCI-HAR 6-axis inertial signals, in g / rad-s
IS=None
for c in glob.glob(os.path.join(DS,"motion","DS11_UCI-HAR","**","Inertial Signals"),recursive=True):
    if glob.glob(os.path.join(c,"*acc_x*")): IS=c; break
def sig(nm):
    f=glob.glob(os.path.join(IS,f"*{nm}*"))
    return np.array([[float(x) for x in l.split()] for l in open(f[0])],"float32") if f else None
ax,ay,az=sig("total_acc_x"),sig("total_acc_y"),sig("total_acc_z")
gx,gy,gz=sig("body_gyro_x"),sig("body_gyro_y"),sig("body_gyro_z")
print(f"UCI-HAR Inertial Signals: {IS is not None}   total_acc_z resting mean={az.mean():.3f} (g units if ~1.0)")
N=40
wins=[np.concatenate([np.stack([ax[i],ay[i],az[i]],1),np.stack([gx[i],gy[i],gz[i]],1)],1) for i in range(N)]
wins=[w for w in wins if w.shape[0]==IMU_LEN][:N]

# one real ESC-50 clip, held constant so only IMU varies
wavs=sorted(glob.glob(os.path.join(DS,"audio_events","DS21_ESC-50","**","*.wav"),recursive=True))
y,_=librosa.load(wavs[0],sr=SR,mono=True,duration=DUR+0.1)
MEL=mel_img(y)

it=tf.lite.Interpreter(model_path=os.path.join(REPO,"assets","models","i_vehicle_crash.tflite"))
it.allocate_tensors()
ins={d["name"].lower():d for d in it.get_input_details()}
i_mel=[d for k,d in ins.items() if "mel" in k][0]
i_imu=[d for k,d in ins.items() if "imu" in k][0]
od=it.get_output_details()[0]
def q(x,d):
    s,z=d["quantization"]; return np.clip(np.round(x/s)+z,-128,127).astype(np.int8)
def score(mel,imu):
    it.set_tensor(i_mel["index"],q(mel,i_mel)[None])
    it.set_tensor(i_imu["index"],q(imu,i_imu)[None])
    it.invoke()
    s,z=od["quantization"]; return float((np.ravel(it.get_tensor(od["index"]))[0]-z)*s)

MS2=9.80665
print("\n=== A  TRAINING domain: UCI-HAR in g ===")
pos=[score(MEL,spike(w)) for w in wins]; neg=[score(MEL,norm_imu(w)) for w in wins]
print(f"  crash-spike vs normal   AUC={roc_auc_score([1]*len(pos)+[0]*len(neg),pos+neg):.4f}"
      f"  pos_mean={np.mean(pos):.4f} neg_mean={np.mean(neg):.4f}")

print("\n=== B  WHAT THE APP FEEDS: same windows scaled to m/s^2 ===")
pos2=[score(MEL,spike(w*MS2)) for w in wins]; neg2=[score(MEL,norm_imu(w*MS2)) for w in wins]
print(f"  crash-spike vs normal   AUC={roc_auc_score([1]*len(pos2)+[0]*len(neg2),pos2+neg2):.4f}"
      f"  pos_mean={np.mean(pos2):.4f} neg_mean={np.mean(neg2):.4f}")

print("\n=== saturation caused by the unit mismatch ===")
for tag,sc in (("g (training)",1.0),("m/s^2 (app)",MS2)):
    n=norm_imu(wins[0]*sc)
    print(f"  {tag:14s} |value|==1.0 (clipped) in {100*np.mean(np.abs(n)>=0.999):5.1f}% of the 768 floats; mean|v|={np.abs(n).mean():.4f}")
print(f"\n  fires at kDefaultThreshold 0.5 -> g: {sum(1 for v in pos if v>=0.5)}/{len(pos)} crash, "
      f"{sum(1 for v in neg if v>=0.5)}/{len(neg)} normal | m/s^2: {sum(1 for v in pos2 if v>=0.5)}/{len(pos2)} crash, "
      f"{sum(1 for v in neg2 if v>=0.5)}/{len(neg2)} normal")
