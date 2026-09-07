"""Fix the int8 export path for mg_gunshot_retrain.

The shipped int8 model is dead: its final logit tensor is clamped at the
int8 floor because the activation ranges were calibrated on a representative
dataset that did not cover the real input distribution.

This rebuilds the exact day261 architecture, loads the real trained weights,
verifies the rebuild reproduces the known-good f32 TFLite export, then
re-quantizes using a representative dataset built from REAL audio spanning
both classes.
"""
import csv, glob, os, random, sys
import numpy as np, librosa, tensorflow as tf
from sklearn.metrics import roc_auc_score

random.seed(42); np.random.seed(42); tf.random.set_seed(42)

ROOT = r"C:\Users\hridy\Desktop\zapsafe"
K = os.path.join(ROOT, r"letsstartbuilding\kaggle_notebooks\day261_mg_gunshot_retrain_push\kaggle_output")
WEIGHTS = os.path.join(K, "mg_gunshot_retrain_ckpt", "best.weights.h5")
F32 = os.path.join(K, "mg_gunshot_retrain_f32.tflite")
US8K = os.path.join(ROOT, r"ml_datasets\audio_events\DS09_UrbanSound8K")
OUT = os.path.join(ROOT, "work", "export_fix")

SR, DUR, IMG = 16000, 3.0, 128

def mel_image(y):
    n = int(DUR * SR)
    y = np.pad(y, (0, n - len(y))) if len(y) < n else y[:n]
    m = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=128, hop_length=512,
                                       n_fft=2048, fmax=8000)
    db = librosa.power_to_db(m, ref=np.max)
    nz = (db - db.min()) / (db.max() - db.min() + 1e-8)
    return np.stack([np.resize(nz, (IMG, IMG))] * 3, axis=-1).astype(np.float32)

# ---- architecture: verbatim from day261_mg_gunshot_retrain.py::build_model ----
def build_model():
    base = tf.keras.applications.MobileNetV2(input_shape=(IMG, IMG, 3),
                                             include_top=False, weights=None)
    base.trainable = True
    inp = tf.keras.Input(shape=(IMG, IMG, 3), name="mel_spec")
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inp)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="gunshot")(x)
    return tf.keras.Model(inp, out, name="mg_gunshot_retrain")

print("[1] rebuilding architecture and loading real trained weights ...")
model = build_model()
model.load_weights(WEIGHTS)
print("    weights loaded OK")

# ---- real audio ----
print("[2] loading real UrbanSound8K audio ...")
index = {os.path.basename(p): p for p in glob.glob(os.path.join(US8K, "**", "*.wav"), recursive=True)}
NEG = {"car_horn","drilling","engine_idling","jackhammer","siren","street_music",
       "dog_bark","children_playing","air_conditioner"}
pos, neg = [], []
for r in csv.DictReader(open(os.path.join(US8K, "UrbanSound8K.csv"), newline="", encoding="utf-8")):
    p = index.get(r["slice_file_name"])
    if not p: continue
    if r["class"] == "gun_shot": pos.append(p)
    elif r["class"] in NEG: neg.append(p)
random.shuffle(pos); random.shuffle(neg)

def featurise(paths):
    out = []
    for p in paths:
        try:
            w, _ = librosa.load(p, sr=SR, mono=True)
            if len(w) < SR * 0.2: continue
            out.append(mel_image(w))
        except Exception:
            pass
    return out

# calibration split (for quantization) kept DISJOINT from the eval split
cal_pos, ev_pos = pos[:120], pos[120:270]
cal_neg, ev_neg = neg[:240], neg[240:690]
Xcal = np.stack(featurise(cal_pos) + featurise(cal_neg))
Xev_p, Xev_n = featurise(ev_pos), featurise(ev_neg)
Xev = np.stack(Xev_p + Xev_n)
yev = np.array([1]*len(Xev_p) + [0]*len(Xev_n))
print(f"    calibration set: {Xcal.shape[0]} clips (both classes, disjoint from eval)")
print(f"    eval set       : pos={int(yev.sum())} neg={int((1-yev).sum())}")

def tflite_probs(path_or_bytes, X):
    it = tf.lite.Interpreter(model_path=path_or_bytes) if isinstance(path_or_bytes, str) \
         else tf.lite.Interpreter(model_content=path_or_bytes)
    it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    pr = []
    for k in range(len(X)):
        x = X[k:k+1]
        if i["dtype"] == np.int8:
            s, z = i["quantization"]
            x = np.clip(np.round(x/s + z), -128, 127).astype(np.int8)
        it.set_tensor(i["index"], x); it.invoke()
        r = float(np.ravel(it.get_tensor(o["index"]))[0])
        if o["dtype"] == np.int8:
            s, z = o["quantization"]; r = (r - z) * s
        pr.append(r)
    return np.array(pr)

print("[3] verifying the rebuild matches the known-good f32 export ...")
probe = Xev[:40]
keras_p = model.predict(probe, verbose=0).ravel()
f32_p = tflite_probs(F32, probe)
mad = float(np.max(np.abs(keras_p - f32_p)))
print(f"    max |keras - f32_tflite| over 40 real clips = {mad:.6f}")
if mad > 1e-3:
    print("    !! rebuild does NOT match the f32 export - aborting, would be unsafe to ship")
    sys.exit(1)
print("    rebuild is faithful.")

print("[4] re-quantizing to int8 with a REAL, class-balanced representative dataset ...")
def rep_ds():
    idxs = np.random.permutation(len(Xcal))
    for i in idxs:
        yield [Xcal[i:i+1].astype(np.float32)]

conv = tf.lite.TFLiteConverter.from_keras_model(model)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
conv.representative_dataset = rep_ds
conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
conv.inference_input_type = tf.int8
conv.inference_output_type = tf.int8
int8_bytes = conv.convert()
open(os.path.join(OUT, "mg_gunshot_retrain_int8_fixed.tflite"), "wb").write(int8_bytes)
print(f"    new int8 size = {len(int8_bytes)/1024:.1f} KB")

print("[5] evaluating on the held-out real eval split ...")
rows = [("SHIPPED int8 (current)", os.path.join(ROOT, r"letsstartbuilding\zapsafe_mobile_main_reconcile\assets\models\mg_gunshot_retrain.tflite")),
        ("f32 reference",          F32),
        ("NEW int8 (re-quantized)", int8_bytes)]
for tag, src in rows:
    pr = tflite_probs(src, Xev)
    if pr.std() < 1e-9:
        print(f"  {tag:26s} CONSTANT {pr[0]:.4f}  -> DEAD")
        continue
    auc = roc_auc_score(yev, pr)
    line = f"  {tag:26s} AUC={auc:.4f} out[{pr.min():.3f},{pr.max():.3f}]"
    best = None
    for t in np.arange(0.30, 0.96, 0.01):
        tp = int(((pr>=t)&(yev==1)).sum()); fp = int(((pr>=t)&(yev==0)).sum())
        rec = tp/max(1,int(yev.sum())); prec = tp/max(1,tp+fp)
        f1 = 0 if rec+prec==0 else 2*rec*prec/(rec+prec)
        if best is None or f1 > best[3]: best = (t, rec, prec, f1)
    print(line + f"  bestF1 t={best[0]:.2f} rec={best[1]:.3f} prec={best[2]:.3f} f1={best[3]:.3f}")
