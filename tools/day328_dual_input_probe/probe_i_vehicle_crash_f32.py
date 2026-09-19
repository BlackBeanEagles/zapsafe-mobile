"""Day 330 - i_vehicle_crash f32 vs int8, under g (training) and m/s^2 (app) units."""
import glob, os, numpy as np, librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score
np.random.seed(0)
REPO=r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile"
F32=r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\day303-zapsafe-mobile\assets\models\i_vehicle_crash_f32.tflite"
DS=r"C:\Users\hridy\Desktop\zapsafe\ml_datasets"
SR,DUR,N_MELS,IMU_LEN,G=16000,2.0,64,128,8.0
IMG_H=IMG_W=64; MS2=9.80665

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

IS=None
for c in glob.glob(os.path.join(DS,"motion","DS11_UCI-HAR","**","Inertial Signals"),recursive=True):
    if glob.glob(os.path.join(c,"*acc_x*")): IS=c; break
def sig(nm):
    f=glob.glob(os.path.join(IS,f"*{nm}*"))
    return np.array([[float(x) for x in l.split()] for l in open(f[0])],"float32") if f else None
ax,ay,az=sig("total_acc_x"),sig("total_acc_y"),sig("total_acc_z")
gx,gy,gz=sig("body_gyro_x"),sig("body_gyro_y"),sig("body_gyro_z")
N=60
wins=[np.concatenate([np.stack([ax[i],ay[i],az[i]],1),np.stack([gx[i],gy[i],gz[i]],1)],1) for i in range(N)]
wins=[w for w in wins if w.shape[0]==IMU_LEN][:N]
wavs=sorted(glob.glob(os.path.join(DS,"audio_events","DS21_ESC-50","**","*.wav"),recursive=True))
y,_=librosa.load(wavs[0],sr=SR,mono=True,duration=DUR+0.1); MEL=mel_img(y)

def make(path):
    it=tf.lite.Interpreter(model_path=path); it.allocate_tensors()
    ins={d["name"].lower():d for d in it.get_input_details()}
    im=[d for k,d in ins.items() if "mel" in k][0]; iu=[d for k,d in ins.items() if "imu" in k][0]
    od=it.get_output_details()[0]
    q8 = im["dtype"]==np.int8
    def q(x,d):
        if d["dtype"]!=np.int8: return x.astype("float32")
        s,z=d["quantization"]; return np.clip(np.round(x/s)+z,-128,127).astype(np.int8)
    def score(mel,imu):
        it.set_tensor(im["index"],q(mel,im)[None]); it.set_tensor(iu["index"],q(imu,iu)[None]); it.invoke()
        o=np.ravel(it.get_tensor(od["index"]))[0]
        if od["dtype"]==np.int8:
            s,z=od["quantization"]; return float((o-z)*s)
        return float(o)
    return score,("int8" if q8 else "f32")

for path in (os.path.join(REPO,"assets","models","i_vehicle_crash.tflite"), F32):
    score,kind=make(path)
    print(f"\n########## {kind}  ({os.path.basename(path)})")
    for tag,sc in (("g  (training units)",1.0),("m/s^2 (what the app feeds)",MS2)):
        pos=[score(MEL,spike(w*sc)) for w in wins]; neg=[score(MEL,norm_imu(w*sc)) for w in wins]
        a=roc_auc_score([1]*len(pos)+[0]*len(neg),pos+neg)
        print(f"  {tag:28s} AUC={a:.4f}  pos_mean={np.mean(pos):.4f} neg_mean={np.mean(neg):.4f} "
              f"sep={np.mean(pos)-np.mean(neg):+.4f}  distinct_out={len(set(np.round(pos+neg,6)))}")

print("\n\n########## CONTROL: vary the AUDIO branch (IMU held at a fixed real calm window)")
import csv
esc=os.path.join(DS,"audio_events","DS21_ESC-50")
rows=list(csv.DictReader(open(os.path.join(esc,"esc50.csv"),newline="",encoding="utf-8")))
files={os.path.basename(p):p for p in glob.glob(os.path.join(esc,"**","*.wav"),recursive=True)}
CRASH={"glass_breaking","car_horn","siren","engine"}
QUIET={"rain","wind","chirping_birds","crickets","water_drops"}
cw=[files[r["filename"]] for r in rows if r["category"] in CRASH and r["filename"] in files][:40]
qw=[files[r["filename"]] for r in rows if r["category"] in QUIET and r["filename"] in files][:40]
print(f"  crash-ish clips={len(cw)}  quiet clips={len(qw)}")
def m_of(p):
    y,_=librosa.load(p,sr=SR,mono=True,duration=DUR+0.1); return mel_img(y)
MC=[m_of(p) for p in cw]; MQ=[m_of(p) for p in qw]
IMU_FIXED=norm_imu(wins[0])
for path in (os.path.join(REPO,"assets","models","i_vehicle_crash.tflite"), F32):
    score,kind=make(path)
    pos=[score(m,IMU_FIXED) for m in MC]; neg=[score(m,IMU_FIXED) for m in MQ]
    a=roc_auc_score([1]*len(pos)+[0]*len(neg),pos+neg)
    allv=pos+neg
    print(f"  {kind:5s} AUC(crash-audio vs quiet-audio)={a:.4f}  pos_mean={np.mean(pos):.4f} "
          f"neg_mean={np.mean(neg):.4f}  full_output_range=[{min(allv):.4f},{max(allv):.4f}] "
          f"distinct={len(set(np.round(allv,6)))}")
