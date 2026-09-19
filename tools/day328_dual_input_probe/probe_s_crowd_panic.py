"""Day 328 - does s_crowd_panic detect crowd panic, or detect its own data provenance?

Three input regimes against the SHIPPED asset:
  A  training-domain reproduction: real panic mel + synth_push IMU   vs  ZERO mel + PAMAP2[20:26]
  B  phone-realistic:              real panic mel + real acc/gyro    vs  real calm mel + real acc/gyro
  C  IMU shortcut alone:           ZERO mel + synth_push IMU         vs  ZERO mel + PAMAP2[20:26]
"""
import csv, glob, json, os, random
import numpy as np, librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score

random.seed(0); np.random.seed(0)
REPO = r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile"
DS   = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets"
SR, DUR, N_MELS, HOP, NFFT, MEL_H, MEL_W, IMU_LEN = 16000, 2.0, 64, 512, 2048, 64, 64, 128

PANIC = {"/m/07p6fty","/m/07sr1lc","/m/04gy_2","/t/dd00135","/m/03qc9zr","/m/03qtwd"}
CALM  = {"/m/07r04","/m/04ylt","/m/09x0r","/m/0k4j"}

norm = json.load(open(os.path.join(REPO,"assets","models","s_crowd_panic_norm.json")))
MM, MS = norm["mel_mean"], norm["mel_std"]
IM, IS = np.array(norm["imu_mean"],"float32"), np.array(norm["imu_std"],"float32")

def mel_of(y):
    m = librosa.feature.melspectrogram(y=y, sr=SR, n_fft=NFFT, hop_length=HOP, n_mels=N_MELS, fmax=8000)
    d = librosa.power_to_db(m, ref=np.max)
    if d.shape[1] < MEL_W: d = np.pad(d, ((0,0),(0,MEL_W-d.shape[1])))
    return d[:MEL_H,:MEL_W].astype("float32")

def load_wav(p):
    y,_ = librosa.load(p, sr=SR, mono=True, duration=DUR+0.1)
    n = int(DUR*SR)
    return (np.pad(y,(0,n-len(y))) if len(y)<n else y[:n]).astype("float32")

def synth_push(n):
    out=[]
    for _ in range(n):
        t=np.linspace(0,4*np.pi,IMU_LEN); push=np.sin(t*2.5)*3.0+np.sin(t*5.1)*1.5
        w=np.zeros((IMU_LEN,6),"float32")
        w[:,0]=push+np.random.randn(IMU_LEN)*0.3
        w[:,1]=push*0.7+np.random.randn(IMU_LEN)*0.3
        w[:,2]=np.random.randn(IMU_LEN)*0.5
        w[:,3:]=np.random.randn(IMU_LEN,3)*0.2
        out.append(w)
    return out

def pamap(cols, n):
    """Real PAMAP2 windows. cols=(20..25) reproduces training; cols=(21,22,23,27,28,29) is real acc+gyro."""
    out=[]
    for dat in sorted(glob.glob(os.path.join(DS,"motion","DS14_PAMAP2","**","*.dat"), recursive=True))[:6]:
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

# --- audio pools from real AudioSet ---
wav={os.path.splitext(f)[0]:os.path.join(DS,"audio_events","DS07_AudioSet","train_wav",f)
     for f in os.listdir(os.path.join(DS,"audio_events","DS07_AudioSet","train_wav"))}
pan,cal=[],[]
for nm in ("train.csv","balanced_train_segments.csv","unbalanced_train_segments.csv"):
    fp=os.path.join(DS,"audio_events","DS07_AudioSet",nm)
    if not os.path.exists(fp): continue
    for row in csv.reader(open(fp,newline="",encoding="utf-8",errors="replace")):
        if len(row)<4 or row[0].startswith("#"): continue
        labs={x.strip().strip('"') for x in ",".join(row[3:]).split(",")}
        p=wav.get(row[0].strip())
        if not p: continue
        if labs & PANIC and len(pan)<60: pan.append(p)
        elif labs & CALM and not (labs & PANIC) and len(cal)<60: cal.append(p)
    if len(pan)>=60 and len(cal)>=60: break
print(f"real AudioSet clips: panic={len(pan)} calm={len(cal)}")

N=min(len(pan),len(cal),40)
mel_pan=[mel_of(load_wav(p)) for p in pan[:N]]
mel_cal=[mel_of(load_wav(p)) for p in cal[:N]]
mel_zero=mel_of(np.zeros(int(DUR*SR),"float32"))
print(f"zero-audio mel: min={mel_zero.min():.3f} max={mel_zero.max():.3f}  (all-zero => {np.allclose(mel_zero,0)})")

imu_tr  = pamap((20,21,22,23,24,25), N)                 # training slice: temp + acc dup
imu_ph  = pamap((21,22,23,27,28,29), N)                 # real acc(m/s2) + real gyro(rad/s)
imu_syn = synth_push(N)
n=min(N,len(imu_tr),len(imu_ph))
print(f"windows per class: {n}")
print(f"  training-slice   ch0 mean={np.mean([w[:,0].mean() for w in imu_tr[:n]]):7.3f}")
print(f"  phone-real       ch0 mean={np.mean([w[:,0].mean() for w in imu_ph[:n]]):7.3f}")
print(f"  synth_push       ch0 mean={np.mean([w[:,0].mean() for w in imu_syn[:n]]):7.3f}")

it=tf.lite.Interpreter(model_path=os.path.join(REPO,"assets","models","s_crowd_panic.tflite"))
it.allocate_tensors()
ins={d["name"]:d for d in it.get_input_details()}
i_mel=[d for k,d in ins.items() if "mel" in k][0]
i_imu=[d for k,d in ins.items() if "imu" in k][0]
od=it.get_output_details()[0]

def score(mel,imu):
    it.set_tensor(i_mel["index"], (((mel-MM)/MS)[None,:,:,None]).astype("float32"))
    it.set_tensor(i_imu["index"], (((imu-IM)/IS)[None]).astype("float32"))
    it.invoke()
    return float(np.ravel(it.get_tensor(od["index"]))[0])

def auc(pos,neg,tag):
    y=[1]*len(pos)+[0]*len(neg); s=pos+neg
    a=roc_auc_score(y,s)
    print(f"  {tag:52s} AUC={a:.4f}   pos_mean={np.mean(pos):.4f} neg_mean={np.mean(neg):.4f}")
    return a

print("\n=== A  training-domain reproduction ===")
auc([score(mel_pan[i], imu_syn[i]) for i in range(n)],
    [score(mel_zero,   imu_tr[i])  for i in range(n)],
    "real panic+synth IMU  vs  ZERO mel+PAMAP2[20:26]")

print("\n=== B  phone-realistic: real audio both sides, real acc+gyro both sides ===")
auc([score(mel_pan[i], imu_ph[i]) for i in range(n)],
    [score(mel_cal[i], imu_ph[i]) for i in range(n)],
    "panic audio  vs  calm audio, real IMU held constant")

print("\n=== C  IMU provenance shortcut alone (audio identical, zero) ===")
auc([score(mel_zero, imu_syn[i]) for i in range(n)],
    [score(mel_zero, imu_tr[i])  for i in range(n)],
    "synth IMU  vs  real PAMAP2[20:26], mel identical")

print("\n=== D  fire rate at the shipped kDefaultThreshold = 0.5, realistic phone input ===")
sp=[score(mel_pan[i], imu_ph[i]) for i in range(n)]
sc=[score(mel_cal[i], imu_ph[i]) for i in range(n)]
for tag,s in (("real panic audio",sp),("real calm audio",sc)):
    fired=sum(1 for v in s if v>=0.5)
    print(f"  {tag:18s} fires {fired:3d}/{len(s)} = {100*fired/len(s):5.1f}%   min={min(s):.4f} max={max(s):.4f}")
