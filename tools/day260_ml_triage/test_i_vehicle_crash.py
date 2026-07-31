"""
Day 267 -- real-data hidden-input check for i_vehicle_crash (+f32).
Hypothesis: like k_confinement/s_crowd_panic, i_vehicle_crash is a dual-input
fusion model (serving_default_audio_mel [1,64,64,3] + serving_default_imu_window
[1,128,6], confirmed via interpreter.get_input_details()) and Day 259's triage
harness (PREPROCESSING_SPEC.md's 64x64 mel family test) only fed the audio
branch, leaving imu_window as TFLite allocator garbage -- same bug class as
k_confinement's `light` and s_crowd_panic's `mel`.
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
from sklearn.metrics import roc_auc_score

random.seed(42)
np.random.seed(42)

ESC50_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS21_ESC-50")
ESC50_AUDIO = ESC50_ROOT / "audio" / "audio"
ESC50_CSV = ESC50_ROOT / "esc50.csv"
UCIHAR_ROOT = pathlib.Path(r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\motion\DS11_UCI-HAR\UCI HAR Dataset")

STAGE = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
    r"\_v10_pull\tflite_staging"
)
TRAIN_SCRIPT = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\i_vehicle_crash_push"
    r"\day91_i_vehicle_crash.py"
)


def _import_from_path(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def load_uci_har_windows(split, n=None, seed=42):
    sig_dir = UCIHAR_ROOT / split / "Inertial Signals"
    chans = ["body_acc_x", "body_acc_y", "body_acc_z", "body_gyro_x", "body_gyro_y", "body_gyro_z"]
    arrs = [np.loadtxt(sig_dir / f"{c}_{split}.txt", dtype=np.float32) for c in chans]
    stacked = np.stack(arrs, axis=-1)
    if n is not None:
        rng = np.random.RandomState(seed)
        stacked = stacked[rng.choice(stacked.shape[0], size=min(n, stacked.shape[0]), replace=False)]
    return stacked


def run_dual(path, mel, imu):
    interp = tf.lite.Interpreter(model_path=str(path))
    interp.allocate_tensors()
    dets = interp.get_input_details()
    imu_det = next(d for d in dets if "imu" in d["name"])
    mel_det = next(d for d in dets if "mel" in d["name"] or "audio" in d["name"])
    out_det = interp.get_output_details()[0]
    scores = []
    for i in range(len(mel)):
        mb = mel[i][None, ...]
        ib = imu[i][None, ...]
        if mel_det["dtype"] in (np.int8, np.uint8):
            s, z = mel_det["quantization"]
            mb_q = (mb / s + z).round().astype(mel_det["dtype"])
        else:
            mb_q = mb.astype(mel_det["dtype"])
        if imu_det["dtype"] in (np.int8, np.uint8):
            s, z = imu_det["quantization"]
            ib_q = (ib / s + z).round().astype(imu_det["dtype"])
        else:
            ib_q = ib.astype(imu_det["dtype"])
        interp.set_tensor(mel_det["index"], mb_q)
        interp.set_tensor(imu_det["index"], ib_q)
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
                print(f"AUC={roc_auc_score(labels, scores):.4f}")
            except Exception as e:
                print("AUC calc failed:", e)
    return std


def main():
    i = _import_from_path("day91_i_vehicle_crash", TRAIN_SCRIPT)

    cats = {}
    with open(ESC50_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cats.setdefault(row["category"], []).append(row["filename"])

    # Real "crash-like" positive audio proxy per the model's own POS_EXACT set
    # (day91 has no dedicated vehicle_crash ESC-50 class -- glass_breaking is
    # the closest real impact/shatter audio present in this local ESC-50 copy).
    pos_files = cats.get("glass_breaking", []) + cats.get("thunderstorm", [])[:10]
    # Real negative audio: car horn / engine -- exact NEG classes from
    # load_esc50_audio()'s own NEG_CLASSES via category name match, plus
    # UrbanSound-style engine/traffic proxies available in local ESC-50.
    neg_cat_names = ["car_horn", "engine", "train"]
    neg_files = [f for c in neg_cat_names for f in cats.get(c, [])]
    if not neg_files:
        # fall back to whatever vehicle-adjacent categories exist locally
        neg_files = cats.get("train", []) + cats.get("engine", [])
    random.shuffle(pos_files)
    random.shuffle(neg_files)
    n = min(len(pos_files), len(neg_files), 30)
    pos_files, neg_files = pos_files[:n], neg_files[:n]
    print(f"real ESC-50 audio: pos(crash-proxy)={len(pos_files)} neg(vehicle)={len(neg_files)}")

    def mel_for(fn):
        p = ESC50_AUDIO / fn
        y, _ = librosa.load(str(p), sr=i.SR, mono=True)
        return i.audio_to_melspec(y)

    mel_pos = np.stack([mel_for(f) for f in pos_files])
    mel_neg = np.stack([mel_for(f) for f in neg_files])

    # Real IMU: UCI-HAR windows, negative = unmodified normal activity,
    # positive = the model's OWN real crash-injection function applied to
    # the same real windows (the exact function used at training time to
    # turn real UCI-HAR IMU into crash positives).
    X_imu_neg = load_uci_har_windows("test", n=n, seed=42)
    X_imu_pos = np.stack([i.inject_crash_spike(w.copy()) for w in X_imu_neg])
    X_imu_neg_norm = np.stack([i.normalize_imu(w.copy()) for w in X_imu_neg])

    mel_all = np.concatenate([mel_pos, mel_neg], axis=0)
    imu_all_matched = np.concatenate([X_imu_pos, X_imu_neg_norm], axis=0)
    y = np.array([1] * len(mel_pos) + [0] * len(mel_neg))

    # Garbage-IMU replica of Day 259's original (buggy) harness: only audio
    # set correctly, IMU left at whatever np.zeros the interpreter allocator
    # would show up as (closest deterministic stand-in for "unset").
    imu_garbage = np.zeros_like(imu_all_matched)

    results = {}
    for tag, path in [("int8 staged", STAGE / "i_vehicle_crash.tflite"),
                       ("fp32 staged", STAGE / "i_vehicle_crash_f32.tflite")]:
        print("\n" + "=" * 70 + f"\n{tag}\n" + "=" * 70)
        s_correct = run_dual(path, mel_all, imu_all_matched)
        s_garbage = run_dual(path, mel_all, imu_garbage)
        std_correct = summarize(f"{tag} -- BOTH real inputs matched (audio label == imu label)", s_correct, y)
        std_garbage = summarize(f"{tag} -- audio real, imu=zeros (Day259-style single-input replica)", s_garbage, y)
        results[tag] = {
            "both_inputs_std": std_correct,
            "both_inputs_auc": float(roc_auc_score(y, s_correct)),
            "garbage_imu_std": std_garbage,
            "garbage_imu_auc": float(roc_auc_score(y, s_garbage)),
        }

    print("\n" + "=" * 70 + "\nSUMMARY\n" + "=" * 70)
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
