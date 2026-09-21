"""Does the shipped scream detector already cover crowd-panic audio?"""
import csv, os, numpy as np, librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score
REPO=r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile_main_reconcile"
AD=r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS07_AudioSet"
SR,DUR,N_MELS,N_FFT,HOP,FRAMES=22050,3,128,2048,512,131
NEED=SR*DUR
SEEN={"/m/03qc9zr":"Screaming","/m/07sr1lc":"Yell","/t/dd00135":"Children shouting","/m/04gy_2":"Battle cry"}
UNSEEN={"/m/07p6fty":"Shout","/m/03qtwd":"Crowd"}
CALM={"/m/07r04","/m/04ylt","/m/09x0r","/m/0k4j"}

def mel_from(y,sr):
    if y.ndim>1: y=y.mean(axis=1)
    if sr!=SR: y=librosa.resample(y,orig_sr=sr,target_sr=SR)
    if len(y)<SR*0.2: return None
    y=np.pad(y,(0,NEED-len(y))) if len(y)<NEED else y[:NEED]
    m=librosa.feature.melspectrogram(y=y,sr=SR,n_mels=N_MELS,n_fft=N_FFT,hop_length=HOP)
    db=librosa.power_to_db(m,ref=np.max); rng=float(db.max()-db.min())
    if rng<1e-6: return None
    db=(db-db.min())/(rng+1e-9)
    if db.shape[1]<FRAMES: db=np.pad(db,((0,0),(0,FRAMES-db.shape[1])))
    return db[:,:FRAMES].astype("float32")

wd=os.path.join(AD,"train_wav")
have={os.path.splitext(f)[0]:os.path.join(wd,f) for f in os.listdir(wd)}
buckets={"seen":[], "unseen":[], "calm":[]}
for nm in ("train.csv","balanced_train_segments.csv","unbalanced_train_segments.csv"):
    fp=os.path.join(AD,nm)
    if not os.path.exists(fp): continue
    for row in csv.reader(open(fp,newline="",encoding="utf-8",errors="replace")):
        if len(row)<4 or row[0].startswith("#"): continue
        p=have.get(row[0].strip())
        if not p: continue
        labs={x.strip().strip('"') for x in ",".join(row[3:]).split(",")}
        if labs & set(UNSEEN) and len(buckets["unseen"])<50: buckets["unseen"].append(p)
        elif labs & set(SEEN) and len(buckets["seen"])<50: buckets["seen"].append(p)
        elif labs & CALM and len(buckets["calm"])<60: buckets["calm"].append(p)
print({k:len(v) for k,v in buckets.items()})

# Day 346: v3 left assets/ when v5 shipped; byte-identical copy in work/.
it=tf.lite.Interpreter(model_path=r"C:\Users\hridy\Desktop\zapsafe\work\scream_v3\m1_scream_v3_float16.tflite")
it.allocate_tensors(); i0=it.get_input_details()[0]; o0=it.get_output_details()[0]
def score(p):
    y,sr=librosa.load(p,sr=None,mono=True)
    m=mel_from(y,sr)
    if m is None: return None
    it.set_tensor(i0["index"],m[None,:,:,None]); it.invoke()
    return float(np.ravel(it.get_tensor(o0["index"]))[0])
S={k:[v for v in (score(p) for p in ps) if v is not None] for k,ps in buckets.items()}
for k,v in S.items(): print(f"  {k:7s} n={len(v):3d} mean={np.mean(v):.4f} fires>=0.30: {sum(1 for x in v if x>=0.30)}/{len(v)}")
print()
print(f"AUC seen-panic   vs calm = {roc_auc_score([1]*len(S['seen'])+[0]*len(S['calm']), S['seen']+S['calm']):.4f}   (Screaming/Yell/Children shouting/Battle cry - scream v3 trained on these)")
print(f"AUC UNSEEN-panic vs calm = {roc_auc_score([1]*len(S['unseen'])+[0]*len(S['calm']), S['unseen']+S['calm']):.4f}   (Shout/Crowd - scream v3 never saw these)")
