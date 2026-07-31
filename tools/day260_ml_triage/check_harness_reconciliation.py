"""
Day 260C -- reconciling two Day 259-vs-today discrepancies flagged as
unresolved in DAY260_QUANTIZATION_ROOTCAUSE.md (m_glass_breaking) and
DAY260B_HIDDEN_INPUT_CHECK.md (o_running_fleeing). Full writeup:
../../assets/models/DAY260C_HARNESS_RECONCILIATION.md -- this script
produced every number pasted there. Re-run to reproduce.

Both tests below feed the SAME staged fp32/int8 files used in the prior two
docs. Only the REAL DATA SOURCE changes -- no synthetic/placeholder signal
is used anywhere in this file, per the project's standing rule (a synthetic
test signal falsely made a model look broken earlier in this project).

Test 1 -- m_glass_breaking: today's earlier ESC-50 test (clean, in-training-
distribution audio) found strong real signal (AUC 0.89-0.97), contradicting
Day 259's "exactly constant, AUC 0.500". Hypothesis: Day 259 used harder,
out-of-distribution real audio -- specifically real AudioSet clips carrying
the exact glass/shatter/smash MIDs and keyword terms day93_m_glass_breaking.py
itself defines (GLASS_MIDS, GLASS_TERMS) -- not ESC-50's curated
`glass_breaking` category. Tests that directly.

Test 2 -- o_running_fleeing: today's earlier test used the model's OWN
training-time panic-running augmentation (apply_panic_running) on real
UCI-HAR walking windows and found the score moves UP (correct), contradicting
Day 259's "collapses to exactly 0 on fall-injected -- wrong direction".
Hypothesis: "fall-injected" in Day 259's own wording literally meant real
fall-impact data (a different physical event from panic running), not this
model's own running augmentation. Tests that directly using SisFall (a real
wearable-accelerometer fall dataset present locally at
ml_datasets/motion/DS13_SisFall/Three Classes/), resampled from its native
256-sample window to the model's expected 128-sample window -- a real
recorded waveform, just resampled, not synthesized.

Requires: tensorflow, librosa, numpy, (sklearn optional for AUC).
"""
import csv
import json
import pathlib
import random

import numpy as np
import librosa
import tensorflow as tf

random.seed(42)
np.random.seed(42)

ESC50_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS21_ESC-50")
ESC50_AUDIO = ESC50_ROOT / "audio" / "audio"
ESC50_CSV = ESC50_ROOT / "esc50.csv"
AUDIOSET_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS07_AudioSet")
AUDIOSET_WAV = AUDIOSET_ROOT / "train_wav"
AUDIOSET_TRAINCSV = AUDIOSET_ROOT / "train.csv"
SISFALL_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\motion\DS13_SisFall\Three Classes")

STAGE = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
    r"\day108_kaggle_output\saved\int4_m9\day108-int4-m9-kaggle-20260703-v5-production\tflite_staging"
)
SWEEP = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day102_sweep_push"
    r"\day102_sweep_kaggle_output\saved\sweep"
)

# exact matching lists copied from kaggle_notebooks/m_glass_breaking_push/day93_m_glass_breaking.py
GLASS_MIDS = {"/m/039jq", "/m/0d31p", "/m/04zmvq", "/m/0316dw"}
GLASS_TERMS = ("glass", "shatter", "smash", "breaking", "break", "crack")
NEG_MIDS = {
    "/m/02dgv", "/m/03wwcy", "/m/07pbtc8", "/m/04brg2", "/m/023pjk", "/m/032n05",
    "/m/0k4j", "/m/07r04", "/m/0bt9lr", "/m/04ylt", "/m/06d_3", "/m/0gvgw",
    "/m/0199g", "/m/04rlf", "/m/09x0r", "/m/01h8n0", "/m/07qcp", "/m/028v0c",
}
NEG_TERMS = (
    "door", "knock", "slam", "wood", "engine", "motor", "speech", "talk",
    "dishes", "cup", "drawer", "footstep", "traffic", "horn", "car", "truck",
    "domestic", "cupboard", "closet", "sliding", "knock", "tap", "hammer",
)


def run_tflite_single_input(model_path, X):
    interp = tf.lite.Interpreter(model_path=str(model_path))
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]
    in_scale, in_zp = in_det["quantization"]
    out_scale, out_zp = out_det["quantization"]
    scores = []
    for x in X:
        xb = x[None, ...]
        if in_det["dtype"] in (np.int8, np.uint8):
            xb_q = (xb / in_scale + in_zp).round().astype(in_det["dtype"])
        else:
            xb_q = xb.astype(in_det["dtype"])
        interp.set_tensor(in_det["index"], xb_q)
        interp.invoke()
        out = interp.get_tensor(out_det["index"])
        if out_det["dtype"] in (np.int8, np.uint8):
            out = (out.astype(np.float32) - out_zp) * out_scale
        scores.append(float(out.ravel()[0]))
    return np.array(scores, dtype=np.float64)


def summarize(name, scores, y=None):
    std = float(np.std(scores))
    print(f"\n--- {name} ---")
    print(f"n={len(scores)}  std={std:.6g}  min={scores.min():.6g}  max={scores.max():.6g}  mean={scores.mean():.6g}")
    if y is not None:
        y = np.array(y)
        pos, neg = scores[y == 1], scores[y == 0]
        if len(pos) and len(neg):
            print(f"pos median={np.median(pos):.6g} (n={len(pos)})  neg median={np.median(neg):.6g} (n={len(neg)})")
            try:
                from sklearn.metrics import roc_auc_score
                print(f"AUC={roc_auc_score(y, scores):.4f}")
            except Exception as e:
                print("AUC calc failed:", e)
    return std


def glass_melspec(y, sr=16000):
    n = int(2.0 * sr)
    y = np.pad(y, (0, max(0, n - len(y))))[:n]
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=96, hop_length=512, n_fft=2048, fmax=8000)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    mn, mx = mel_db.min(), mel_db.max()
    img = np.resize((mel_db - mn) / (mx - mn + 1e-8), (96, 96))
    return np.stack([img, img, img], axis=-1).astype(np.float32)


def test1_glass_breaking_audioset():
    print("\n" + "=" * 70 + "\nTEST 1: m_glass_breaking on real AudioSet glass/shatter/smash audio\n"
          "(day93_m_glass_breaking.py's own GLASS_MIDS + GLASS_TERMS + NEG_MIDS/NEG_TERMS)\n" + "=" * 70)
    pos_ids, neg_ids = set(), set()
    with open(AUDIOSET_TRAINCSV, newline="", encoding="utf-8", errors="ignore") as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            if len(row) < 4:
                continue
            blob = " ".join(row[3:]).replace('"', "").lower()
            labels = [x.strip() for x in " ".join(row[3:]).replace('"', "").split(",")]
            if any(t in blob for t in GLASS_TERMS) or any(m in labels for m in GLASS_MIDS):
                pos_ids.add(row[0])
            elif any(m in labels for m in NEG_MIDS) or any(t in blob for t in NEG_TERMS):
                neg_ids.add(row[0])

    pos_wavs = [p for p in AUDIOSET_WAV.glob("*.wav") if p.stem in pos_ids]
    neg_wavs = [p for p in AUDIOSET_WAV.glob("*.wav") if p.stem in neg_ids]
    random.shuffle(pos_wavs)
    random.shuffle(neg_wavs)
    print(f"real AudioSet glass-labelled clips found locally: {len(pos_wavs)}")
    print(f"real AudioSet hard-neg (day93 NEG_MIDS/NEG_TERMS) clips found locally: {len(neg_wavs)}")

    n = min(len(pos_wavs), 40)
    pos_wavs, neg_wavs = pos_wavs[:n], neg_wavs[:n]

    X, y = [], []
    for p in pos_wavs:
        try:
            yy, _ = librosa.load(str(p), sr=16000, mono=True)
        except Exception:
            continue
        X.append(glass_melspec(yy))
        y.append(1)
    for p in neg_wavs:
        try:
            yy, _ = librosa.load(str(p), sr=16000, mono=True)
        except Exception:
            continue
        X.append(glass_melspec(yy))
        y.append(0)
    X = np.stack(X)
    print(f"final set: n={len(X)} pos={sum(y)} neg={len(y) - sum(y)}")

    norm = json.loads((SWEEP / "m" / "d" / "m_glass_breaking_d_norm.json").read_text())
    mn = np.array(norm["min"], dtype=np.float32)
    mx = np.array(norm["max"], dtype=np.float32)
    Xn = (X - mn) / (mx - mn + 1e-8)

    fp32 = run_tflite_single_input(SWEEP / "m" / "d" / "m_glass_breaking_d_f32.tflite", Xn)
    int8 = run_tflite_single_input(STAGE / "m_glass_breaking.tflite", Xn)
    return {
        "fp32_std": summarize("fp32 -- real AudioSet glass audio", fp32, y),
        "int8_std": summarize("int8 staged -- real AudioSet glass audio", int8, y),
    }


def resample_256_to_128(w):
    """Real recorded SisFall waveform, resampled (not synthesized) from its
    native 256-sample window to o_running_fleeing's expected 128-sample
    window length."""
    orig_t = np.linspace(0, 1, w.shape[0])
    new_t = np.linspace(0, 1, 128)
    out = np.zeros((128, 6), dtype=np.float32)
    for c in range(6):
        out[:, c] = np.interp(new_t, orig_t, w[:, c])
    return out


def test2_o_running_fleeing_sisfall():
    print("\n" + "=" * 70 + "\nTEST 2: o_running_fleeing on real SisFall fall-impact IMU data\n" + "=" * 70)
    y = np.fromfile(SISFALL_ROOT / "y_test_3", dtype=np.uint8).reshape(-1, 3)
    x = np.fromfile(SISFALL_ROOT / "x_test_3", dtype=np.float32).reshape(-1, 256, 6)
    print("SisFall test split total windows:", x.shape[0], " class counts (ADL/Fall/NearFall):", y.sum(axis=0))

    fall_idx = np.where(y[:, 1] == 1)[0]
    adl_idx = np.where(y[:, 0] == 1)[0]
    rng = np.random.RandomState(42)
    fall_idx = rng.choice(fall_idx, size=min(60, len(fall_idx)), replace=False)
    adl_idx = rng.choice(adl_idx, size=min(60, len(adl_idx)), replace=False)

    X_fall = np.stack([resample_256_to_128(w) for w in x[fall_idx]])
    X_adl = np.stack([resample_256_to_128(w) for w in x[adl_idx]])
    print(f"real SisFall fall windows used: {len(X_fall)}  real SisFall ADL windows used: {len(X_adl)}")

    out = {}
    for path, tag in [(STAGE / "o_running_fleeing_f32.tflite", "fp32"),
                       (STAGE / "o_running_fleeing.tflite", "int8 staged")]:
        adl_scores = run_tflite_single_input(path, X_adl)
        fall_scores = run_tflite_single_input(path, X_fall)
        adl_std = summarize(f"{tag} -- real SisFall ADL (calm)", adl_scores)
        fall_std = summarize(f"{tag} -- real SisFall FALL (impact)", fall_scores)
        print(f"{tag}: ADL mean={adl_scores.mean():.6g}  FALL mean={fall_scores.mean():.6g}  "
              f"delta={fall_scores.mean() - adl_scores.mean():+.6g}")
        out[tag] = {
            "adl_std": adl_std, "fall_std": fall_std,
            "adl_mean": float(adl_scores.mean()), "fall_mean": float(fall_scores.mean()),
        }
    return out


if __name__ == "__main__":
    results = {
        "m_glass_breaking_audioset": test1_glass_breaking_audioset(),
        "o_running_fleeing_sisfall": test2_o_running_fleeing_sisfall(),
    }
    print("\n" + "=" * 70 + "\nSUMMARY\n" + "=" * 70)
    print(json.dumps(results, indent=2))
