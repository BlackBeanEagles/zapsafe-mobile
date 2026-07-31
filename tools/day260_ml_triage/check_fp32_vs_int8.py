"""
Day 260 -- fp32 vs int8 root-cause check for 3 of the 7 models that Day 259's
triage flagged as "exactly constant" (std < 1e-4) on real data:

  m_glass_breaking, mg_gunshot, k_confinement

Question asked: is the *fp32* checkpoint (pre-quantization) also constant on
real data, or does only the int8 export collapse? Real results and the paths
they came from are written up in
../../assets/models/DAY260_QUANTIZATION_ROOTCAUSE.md -- this script is what
produced those numbers. Re-run it to reproduce them; the paths below are
absolute to this machine's dataset/checkpoint layout and will need editing
elsewhere.

IMPORTANT CORRECTNESS NOTE (found the hard way, see writeup):
k_confinement takes TWO tflite inputs -- `imu` [1,128,6] and `light` [1,32,1]
-- not just IMU as PREPROCESSING_SPEC.md's tensor-shape table implies. Feeding
only the IMU tensor leaves `light` as whatever TFLite's allocator happens to
put in an unset buffer, which silently produces numbers that look like a
real result but aren't one. `run_k_confinement()` below sets both inputs
explicitly and sweeps light across the realistic value for the real IMU data
(0.85, "lit/normal" per day92_k_confinement.py's own light encoding) and the
dark/confinement proxy (0.0) so the effect of that input is visible instead
of hidden.

Requires: tensorflow, librosa, numpy, (sklearn optional for AUC).
"""
import csv
import importlib.util
import json
import pathlib
import random
import sys

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
UCIHAR_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\motion\DS11_UCI-HAR\UCI HAR Dataset")

STAGE = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
    r"\day108_kaggle_output\saved\int4_m9\day108-int4-m9-kaggle-20260703-v5-production\tflite_staging"
)
SWEEP = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day102_sweep_push"
    r"\day102_sweep_kaggle_output\saved\sweep"
)
GUNSHOT_PUSH = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\mg_gunshot_push\output_v5"
)
O_TRAIN_SCRIPT = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\o_running_fleeing_push"
    r"\day94_o_running_fleeing.py"
)
S_TRAIN_SCRIPT = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\s_crowd_panic_push"
    r"\day95_s_crowd_panic.py"
)


def _import_from_path(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


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


def run_tflite_imu_light(model_path, X_imu, light_val):
    interp = tf.lite.Interpreter(model_path=str(model_path))
    interp.allocate_tensors()
    dets = interp.get_input_details()
    imu_det = next(d for d in dets if "imu" in d["name"])
    light_det = next(d for d in dets if "light" in d["name"])
    out_det = interp.get_output_details()[0]
    light_arr = np.full((1, 32, 1), light_val, dtype=np.float32)
    scores = []
    for x in X_imu:
        xb = x[None, ...]
        if imu_det["dtype"] in (np.int8, np.uint8):
            s, z = imu_det["quantization"]
            xb_q = (xb / s + z).round().astype(imu_det["dtype"])
        else:
            xb_q = xb.astype(imu_det["dtype"])
        if light_det["dtype"] in (np.int8, np.uint8):
            s, z = light_det["quantization"]
            light_q = (light_arr / s + z).round().astype(light_det["dtype"])
        else:
            light_q = light_arr.astype(light_det["dtype"])
        interp.set_tensor(imu_det["index"], xb_q)
        interp.set_tensor(light_det["index"], light_q)
        interp.invoke()
        out = interp.get_tensor(out_det["index"])
        if out_det["dtype"] in (np.int8, np.uint8):
            s, z = out_det["quantization"]
            out = (out.astype(np.float32) - z) * s
        scores.append(float(out.ravel()[0]))
    return np.array(scores, dtype=np.float64)


def summarize(name, scores, labels=None):
    std = float(np.std(scores))
    print(f"\n--- {name} ---")
    print(f"n={len(scores)}  std={std:.6g}  min={scores.min():.6g}  max={scores.max():.6g}  mean={scores.mean():.6g}")
    if labels is not None:
        labels = np.array(labels)
        pos, neg = scores[labels == 1], scores[labels == 0]
        if len(pos) and len(neg):
            print(f"pos median={np.median(pos):.6g} (n={len(pos)})  neg median={np.median(neg):.6g} (n={len(neg)})")
            try:
                from sklearn.metrics import roc_auc_score
                print(f"AUC={roc_auc_score(labels, scores):.4f}")
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


def run_glass_breaking():
    print("\n" + "=" * 70 + "\nMODEL: m_glass_breaking / m_best\n" + "=" * 70)
    cats = {}
    with open(ESC50_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cats.setdefault(row["category"], []).append(row["filename"])
    pos_files = cats.get("glass_breaking", [])
    neg_cats = ["can_opening", "clock_alarm", "clock_tick", "door_wood_creaks",
                "door_wood_knock", "hand_saw", "pouring_water", "washing_machine"]
    neg_files = [f for c in neg_cats for f in cats.get(c, [])]
    random.shuffle(neg_files)
    neg_files = neg_files[:40]

    X, y = [], []
    for fn in pos_files + neg_files:
        p = ESC50_AUDIO / fn
        if not p.exists():
            continue
        yy, _ = librosa.load(str(p), sr=16000, mono=True)
        X.append(glass_melspec(yy))
        y.append(1 if fn in pos_files else 0)
    X = np.stack(X)
    print(f"real ESC-50 clips: {len(X)} (pos={sum(y)}, neg={len(y) - sum(y)})")

    norm = json.loads((SWEEP / "m" / "d" / "m_glass_breaking_d_norm.json").read_text())
    mn = np.array(norm["min"], dtype=np.float32)
    mx = np.array(norm["max"], dtype=np.float32)
    Xn = (X - mn) / (mx - mn + 1e-8)

    fp32 = run_tflite_single_input(SWEEP / "m" / "d" / "m_glass_breaking_d_f32.tflite", Xn)
    int8 = run_tflite_single_input(STAGE / "m_glass_breaking.tflite", Xn)
    return {"fp32_std": summarize("fp32", fp32, y), "int8_std": summarize("int8 staged", int8, y)}


def gunshot_melspec(y, sr=16000):
    n = int(3.0 * sr)
    y = np.pad(y, (0, max(0, n - len(y))))[:n]
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=128, hop_length=512, n_fft=2048, fmax=8000)
    mel_db = librosa.power_to_db(mel, ref=np.max)
    img = np.resize((mel_db - mel_db.min()) / (mel_db.max() - mel_db.min() + 1e-8), (128, 128))
    return np.stack([img, img, img], axis=-1).astype(np.float32)


def run_gunshot():
    print("\n" + "=" * 70 + "\nMODEL: mg_gunshot\n" + "=" * 70)
    gun_mid = "/m/032s66"  # "Gunshot, gunfire" in AudioSet ontology
    pos_ids = set()
    with open(AUDIOSET_TRAINCSV, newline="", encoding="utf-8", errors="ignore") as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            if len(row) >= 4 and gun_mid in ",".join(row):
                pos_ids.add(row[0])
    pos_wavs = [p for p in AUDIOSET_WAV.glob("*.wav") if p.stem in pos_ids]
    random.shuffle(pos_wavs)
    pos_wavs = pos_wavs[:50]

    cats = {}
    with open(ESC50_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cats.setdefault(row["category"], []).append(row["filename"])
    neg_files = [f for c in ["car_horn", "chainsaw", "clapping", "engine", "fireworks", "siren", "thunderstorm"]
                 for f in cats.get(c, [])]
    random.shuffle(neg_files)
    neg_files = neg_files[:50]

    X, y = [], []
    for p in pos_wavs:
        try:
            yy, _ = librosa.load(str(p), sr=16000, mono=True)
        except Exception:
            continue
        X.append(gunshot_melspec(yy))
        y.append(1)
    for fn in neg_files:
        p = ESC50_AUDIO / fn
        if p.exists():
            yy, _ = librosa.load(str(p), sr=16000, mono=True)
            X.append(gunshot_melspec(yy))
            y.append(0)
    X = np.stack(X)
    print(f"real clips: {len(X)} (pos={sum(y)} real AudioSet gunshot-labelled, neg={len(y) - sum(y)} ESC-50)")

    fp32 = run_tflite_single_input(GUNSHOT_PUSH / "mg_gunshot_f32.tflite", X)
    int8 = run_tflite_single_input(STAGE / "mg_gunshot.tflite", X)
    return {"fp32_std": summarize("fp32", fp32, y), "int8_std": summarize("int8 staged", int8, y)}


def load_uci_har_windows(split, n=None, seed=42):
    sig_dir = UCIHAR_ROOT / split / "Inertial Signals"
    chans = ["body_acc_x", "body_acc_y", "body_acc_z", "body_gyro_x", "body_gyro_y", "body_gyro_z"]
    arrs = [np.loadtxt(sig_dir / f"{c}_{split}.txt", dtype=np.float32) for c in chans]
    stacked = np.stack(arrs, axis=-1)
    if n is not None:
        rng = np.random.RandomState(seed)
        stacked = stacked[rng.choice(stacked.shape[0], size=min(n, stacked.shape[0]), replace=False)]
    return stacked


def run_k_confinement():
    print("\n" + "=" * 70 + "\nMODEL: k_confinement / k_best\n" + "=" * 70)
    X = load_uci_har_windows("test", n=120, seed=42)
    print(f"real UCI-HAR IMU windows (mixed activities, no confinement label): {len(X)}")
    fp32_path = SWEEP / "k" / "a" / "k_confinement_a_f32.tflite"
    int8_path = STAGE / "k_confinement.tflite"
    out = {}
    for light_val, label in [(0.85, "lit/normal -- correct value for real UCI-HAR daily-activity data"),
                              (0.0, "dark -- confinement proxy per day92_k_confinement.py's own encoding")]:
        print(f"\n[light={light_val}  ({label})]")
        fp32 = run_tflite_imu_light(fp32_path, X, light_val)
        int8 = run_tflite_imu_light(int8_path, X, light_val)
        out[f"light_{light_val}"] = {
            "fp32_std": summarize(f"fp32 light={light_val}", fp32),
            "int8_std": summarize(f"int8 staged light={light_val}", int8),
        }
    return out


def run_o_running_fleeing():
    """
    Day 260B -- o_running_fleeing has only ONE real input (confirmed via
    interpreter.get_input_details(): serving_default_imu:0 [1,128,6], no
    second tensor -- unlike k_confinement/s_crowd_panic). So Day 259's
    "wrong-direction on fall-injected" result was not measured with a
    missing/garbage second input. This re-runs it anyway, real data only,
    to get real current numbers using the model's OWN training-time panic
    augmentation (`apply_panic_running` from day94_o_running_fleeing.py --
    sudden burst + cadence jitter + direction change -- the exact function
    used to build the RUNNING/panic positive class) applied to real
    UCI-HAR calm windows, rather than guessing at what "fall-injected"
    meant.
    """
    print("\n" + "=" * 70 + "\nMODEL: o_running_fleeing (+f32)\n" + "=" * 70)
    o = _import_from_path("day94_o_running_fleeing", O_TRAIN_SCRIPT)

    X_calm = load_uci_har_windows("test", n=60, seed=7)
    X_panic = np.stack([o.apply_panic_running(w.copy()) for w in X_calm])
    print(f"real UCI-HAR calm windows: {len(X_calm)}; same windows put through "
          f"o_running's own apply_panic_running() augmentation: {len(X_panic)}")

    out = {}
    for path, tag in [(STAGE / "o_running_fleeing_f32.tflite", "fp32"),
                       (STAGE / "o_running_fleeing.tflite", "int8 staged")]:
        calm_scores = run_tflite_single_input(path, X_calm)
        panic_scores = run_tflite_single_input(path, X_panic)
        calm_std = summarize(f"{tag} -- calm (real UCI-HAR)", calm_scores)
        panic_std = summarize(f"{tag} -- panic-injected (real UCI-HAR + apply_panic_running)", panic_scores)
        print(f"{tag}: calm mean={calm_scores.mean():.6g}  panic mean={panic_scores.mean():.6g}  "
              f"delta={panic_scores.mean() - calm_scores.mean():+.6g}")
        out[tag] = {
            "calm_std": calm_std, "panic_std": panic_std,
            "calm_mean": float(calm_scores.mean()), "panic_mean": float(panic_scores.mean()),
        }
    return out


def run_s_crowd_panic():
    """
    Day 260B -- s_crowd_panic_a / s_best / s_crowd_panic_a_f32 have TWO real
    inputs (confirmed via get_input_details(), not assumed):
    serving_default_imu:0 [1,128,6] and serving_default_mel:0 [1,64,64,1].
    This is NOT documented in PREPROCESSING_SPEC.md's tensor-shape table,
    which lists s_crowd_panic_* under the plain "[1,128,6]" IMU family
    alongside k_confinement/o_running_fleeing/m2_motion_b.

    Per day95_s_crowd_panic.py / day102_s_sweep.py (day102_sweep_common.py's
    run_dual_sweep -- confirmed by reading, no normalisation is applied to
    either branch for this dual model, same as the rest of the o/k/s IMU
    family), `mel` is a real 64x64 audio mel-spectrogram (2.0s, 16kHz,
    n_mels=64, fmax=8000, power_to_db, NOT resized/normalised beyond that)
    and `imu` is a raw-units 128x6 accelerometer+gyro window. This is a
    real second modality (paired real audio), not a broadcast scalar like
    k_confinement's `light` -- there is no single "physically correct
    constant" to set it to. The correct fix is to feed a REAL matched
    audio clip for every IMU window, using the model's own recovered
    positive/negative recipe:
      calm  = real ESC-50 negative-category audio (day95 ESC_NEG cats) +
              real UCI-HAR walking IMU (unmodified)
      panic = real AudioSet audio carrying a day95 PANIC_MID label +
              real UCI-HAR walking IMU run through day95's own
              `apply_crush_imu()` overlay (the exact function the training
              script uses to turn MobiAct fall/bump recordings into crush
              positives -- raw MobiAct .txt files are not present in this
              machine's local dataset cache, so the real UCI-HAR baseline +
              the model's own real crush-overlay function is the closest
              reproducible substitute; this is disclosed, not silently
              swapped in for real MobiAct data).
    Also runs the two "mixed" combinations (panic audio x calm IMU, calm
    audio x crush IMU) to see which branch the model is actually keying on.
    """
    print("\n" + "=" * 70 + "\nMODEL: s_crowd_panic_a / s_best (+f32)\n" + "=" * 70)
    s = _import_from_path("day95_s_crowd_panic", S_TRAIN_SCRIPT)

    cats = {}
    with open(ESC50_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cats.setdefault(row["category"], []).append(row["filename"])
    calm_files = [f for c in s.ESC_NEG for f in cats.get(c, [])]
    random.shuffle(calm_files)
    calm_files = calm_files[:30]

    gun_mid_blob_ok = None  # not used; reuse s.PANIC_MIDS directly
    pos_ids = set()
    with open(AUDIOSET_TRAINCSV, newline="", encoding="utf-8", errors="ignore") as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            if len(row) >= 4 and any(m in ",".join(row) for m in s.PANIC_MIDS):
                pos_ids.add(row[0])
    panic_wavs = [p for p in AUDIOSET_WAV.glob("*.wav") if p.stem in pos_ids]
    random.shuffle(panic_wavs)
    panic_wavs = panic_wavs[:30]

    def mel_for(path):
        y, _ = librosa.load(str(path), sr=s.SR, mono=True)
        return s.audio_to_mel(y[: int(s.DURATION * s.SR)] if len(y) else y)

    calm_mels = []
    for fn in calm_files:
        p = ESC50_AUDIO / fn
        if p.exists():
            calm_mels.append(mel_for(p))
    panic_mels = []
    for p in panic_wavs:
        try:
            panic_mels.append(mel_for(p))
        except Exception:
            pass

    print(f"real calm ESC-50 audio clips: {len(calm_mels)}  "
          f"real AudioSet panic-labelled audio clips: {len(panic_mels)}")
    if not calm_mels or not panic_mels:
        print("insufficient real audio found for one class -- ABORTING s_crowd_panic real test")
        return {"error": "insufficient real audio", "n_calm": len(calm_mels), "n_panic": len(panic_mels)}

    n = min(len(calm_mels), len(panic_mels), 25)
    calm_mels = np.stack(calm_mels[:n])[..., np.newaxis]
    panic_mels = np.stack(panic_mels[:n])[..., np.newaxis]

    X_imu_calm = load_uci_har_windows("test", n=n, seed=11)
    X_imu_crush = np.stack([s.apply_crush_imu(w.copy()) for w in X_imu_calm])

    def run_dual(path, mel, imu):
        interp = tf.lite.Interpreter(model_path=str(path))
        interp.allocate_tensors()
        dets = interp.get_input_details()
        imu_det = next(d for d in dets if "imu" in d["name"])
        mel_det = next(d for d in dets if "mel" in d["name"])
        out_det = interp.get_output_details()[0]
        scores = []
        for i in range(len(mel)):
            mb = mel[i][None, ...]
            ib = imu[i][None, ...]
            mb_q = mb.astype(mel_det["dtype"]) if mel_det["dtype"] == np.float32 else (
                (mb / mel_det["quantization"][0] + mel_det["quantization"][1]).round().astype(mel_det["dtype"]))
            ib_q = ib.astype(imu_det["dtype"]) if imu_det["dtype"] == np.float32 else (
                (ib / imu_det["quantization"][0] + imu_det["quantization"][1]).round().astype(imu_det["dtype"]))
            interp.set_tensor(mel_det["index"], mb_q)
            interp.set_tensor(imu_det["index"], ib_q)
            interp.invoke()
            out = interp.get_tensor(out_det["index"])
            if out_det["dtype"] in (np.int8, np.uint8):
                s_, z_ = out_det["quantization"]
                out = (out.astype(np.float32) - z_) * s_
            scores.append(float(out.ravel()[0]))
        return np.array(scores, dtype=np.float64)

    files = [
        (STAGE / "s_crowd_panic_a_f32.tflite", "fp32"),
        (STAGE / "s_crowd_panic_a.tflite", "int8 staged (== s_best.tflite, byte-identical)"),
    ]
    out = {}
    for path, tag in files:
        calm_calm = run_dual(path, calm_mels, X_imu_calm)
        panic_panic = run_dual(path, panic_mels, X_imu_crush)
        panic_audio_calm_imu = run_dual(path, panic_mels, X_imu_calm)
        calm_audio_crush_imu = run_dual(path, calm_mels, X_imu_crush)
        summarize(f"{tag} -- calm audio + calm IMU (true negative combo)", calm_calm)
        summarize(f"{tag} -- panic audio + crush IMU (true positive combo)", panic_panic)
        summarize(f"{tag} -- panic audio + calm IMU (mixed)", panic_audio_calm_imu)
        summarize(f"{tag} -- calm audio + crush IMU (mixed)", calm_audio_crush_imu)
        print(f"{tag}: neg mean={calm_calm.mean():.6g}  pos mean={panic_panic.mean():.6g}  "
              f"delta={panic_panic.mean() - calm_calm.mean():+.6g}")
        out[tag] = {
            "neg_mean": float(calm_calm.mean()), "pos_mean": float(panic_panic.mean()),
            "neg_std": float(calm_calm.std()), "pos_std": float(panic_panic.std()),
            "panic_audio_calm_imu_mean": float(panic_audio_calm_imu.mean()),
            "calm_audio_crush_imu_mean": float(calm_audio_crush_imu.mean()),
        }
    return out


if __name__ == "__main__":
    results = {
        "m_glass_breaking": run_glass_breaking(),
        "mg_gunshot": run_gunshot(),
        "k_confinement": run_k_confinement(),
        "o_running_fleeing": run_o_running_fleeing(),
        "s_crowd_panic": run_s_crowd_panic(),
    }
    print("\n" + "=" * 70 + "\nSUMMARY\n" + "=" * 70)
    print(json.dumps(results, indent=2))
