"""
Day 267 -- real-data fp32-vs-int8 check for m4_vocal_stress_en_adversarial
and m5_vocal_stress_apac_adversarial. Day 259 flagged both as "pos/neg
medians identical -- quantisation noise, not signal" at AUC 0.667 (which
is itself just barely-there separability). Both are single-input mel
models (confirmed via get_input_details() -- no hidden-input bug here,
unlike i_vehicle_crash/k_confinement/s_crowd_panic). This checks whether
fp32 (pre-quantization) shows real separable medians on real CREMA-D audio
using the model's OWN label recipe (day104_m4_adversarial.py's
collect_cremad filters), to see if this is a quantization collapse (like
m1_pocket_muffled -- fixable by re-export) or a genuine fp32-level
generalization gap (like m_glass_breaking/mg_gunshot -- needs retraining
or is exhausted).
"""
import pathlib
import random

import numpy as np
import librosa
import tensorflow as tf
from sklearn.metrics import roc_auc_score

random.seed(42)
np.random.seed(42)

CREMA = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\vocal_stress\DS01_RAVDESS\Crema")

SR = 16000
DURATION = 3.0
N_MELS = 96
FMAX = 4000


def mel_for(path):
    y, _ = librosa.load(str(path), sr=SR, mono=True, duration=DURATION + 0.5)
    n = int(SR * DURATION)
    if len(y) >= n:
        y = y[:n]
    else:
        y = np.pad(y, (0, n - len(y)))
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS, n_fft=2048, hop_length=512, fmax=FMAX)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    img = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min() + 1e-8)
    img = tf.image.resize(img[:, :, None], [96, 96]).numpy()[:, :, 0]
    return np.stack([img, img, img], axis=-1).astype(np.float32)


def run_single(path, X):
    interp = tf.lite.Interpreter(model_path=str(path))
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]
    scores = []
    for x in X:
        xb = x[None, ...]
        if in_det["dtype"] in (np.int8, np.uint8):
            s, z = in_det["quantization"]
            xb_q = (xb / s + z).round().astype(in_det["dtype"])
        else:
            xb_q = xb.astype(in_det["dtype"])
        interp.set_tensor(in_det["index"], xb_q)
        interp.invoke()
        out = interp.get_tensor(out_det["index"])
        if out_det["dtype"] in (np.int8, np.uint8):
            s, z = out_det["quantization"]
            out = (out.astype(np.float32) - z) * s
        scores.append(float(out.ravel()[0]))
    return np.array(scores, dtype=np.float64)


def summarize(name, scores, y):
    y = np.array(y)
    pos, neg = scores[y == 1], scores[y == 0]
    print(f"\n--- {name} ---")
    print(f"n={len(scores)} std={scores.std():.6g} pos_median={np.median(pos):.6g} (n={len(pos)}) "
          f"neg_median={np.median(neg):.6g} (n={len(neg)})")
    try:
        print(f"AUC={roc_auc_score(y, scores):.4f}")
    except Exception as e:
        print("AUC fail:", e)


def main():
    wavs = list(CREMA.glob("*.wav"))
    print(f"CREMA-D real wavs found: {len(wavs)}")
    pos_codes = {"SAD", "ANG", "FEA", "DIS"}
    neg_codes = {"NEU", "HAP"}
    pos, neg = [], []
    for p in wavs:
        parts = p.stem.split("_")
        if len(parts) < 3:
            continue
        code = parts[2].upper()
        if code in pos_codes:
            pos.append(p)
        elif code in neg_codes:
            neg.append(p)
    random.shuffle(pos)
    random.shuffle(neg)
    n = min(len(pos), len(neg), 40)
    pos, neg = pos[:n], neg[:n]
    print(f"real CREMA-D per model's own label recipe: pos(stress)={len(pos)} neg(calm)={len(neg)}")

    X = np.stack([mel_for(p) for p in pos + neg])
    y = [1] * len(pos) + [0] * len(neg)

    STAGE = pathlib.Path(
        r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
        r"\_v10_pull\tflite_staging"
    )
    M4_F32 = pathlib.Path(
        r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day104_adversarial_push"
        r"\day104_adversarial_kaggle_output\saved\adversarial\day104_production\m4\m4_vocal_stress_en_adversarial_f32.tflite"
    )

    print("\n===== M4 vocal_stress_en_adversarial =====")
    int8_scores = run_single(STAGE / "m4_vocal_stress_en_adversarial.tflite", X)
    summarize("m4 int8 staged", int8_scores, y)
    if M4_F32.is_file():
        f32_scores = run_single(M4_F32, X)
        summarize("m4 fp32 (day104_production)", f32_scores, y)
    else:
        print("m4 fp32 not found at", M4_F32)

    print("\n===== M5 vocal_stress_apac_adversarial =====")
    int8_scores5 = run_single(STAGE / "m5_vocal_stress_apac_adversarial.tflite", X)
    summarize("m5 int8 staged", int8_scores5, y)
    f32_scores5 = run_single(STAGE / "m5_vocal_stress_apac_adversarial_f32.tflite", X)
    summarize("m5 fp32 staged", f32_scores5, y)


if __name__ == "__main__":
    main()
