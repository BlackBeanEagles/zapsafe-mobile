#!/usr/bin/env python3
"""Liveness gate for the .tflite models in assets/models/.

WHY THIS EXISTS
---------------
On Day 317 the shipped mg_gunshot_retrain.tflite was found to emit a CONSTANT
0.3633 for every input -- real gunshots and real urban negatives alike --
while flutter analyze and all 775 flutter test cases passed. They passed
because flutter test has no native TFLite interpreter, so nothing in the Dart
suite can execute a model at all. A dead safety-critical detector shipped
undetected.

WHAT THIS DOES, AND ITS LIMITS
------------------------------
A model whose output never changes cannot detect anything. This feeds each
model real recorded data and fails if the output is invariant.

Random noise is NOT good enough, and that was established the hard way:
  * m2_motion_b_retrain looks DEAD under random input but is genuinely ALIVE
    on real SisFall IMU windows (fall-vs-ADL AUC ~0.70).
  * motion_anomaly_v1 looks ALIVE under random input but emits a constant 0.0
    on real SisFall IMU.
Random probing produces BOTH false positives and false negatives, so a DEAD
verdict is only ever issued from real data. Where no real fixture exists for a
model's input shape this reports UNVERIFIED rather than guessing.

Run:   python tools/verify_shipped_models.py
Needs: tensorflow, numpy, librosa, and the local datasets under
       ../../ml_datasets. A working env: ../../.mlvenv
Exit 1 if any model is DEAD on real data, so this can gate CI.
"""
from __future__ import annotations

import csv
import glob
import os
import random
import sys

import numpy as np

try:
    import tensorflow as tf
except ImportError:
    print("tensorflow not installed - cannot verify models", file=sys.stderr)
    sys.exit(2)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ASSETS = os.path.join(REPO, "assets", "models")
DATASETS = os.path.abspath(os.path.join(REPO, "..", "..", "ml_datasets"))

# Not real models. Documented rather than silently skipped.
KNOWN_PLACEHOLDERS = {"dcs_fusion_v1.tflite"}

random.seed(42)


def _load(path):
    """Load an interpreter, retrying without XNNPACK.

    Some models fail to prepare under the desktop XNNPACK delegate
    (scene_analyzer_v1 hits "Node ... failed to prepare"). That is an
    environment quirk of desktop TF, not evidence the model is broken, so
    fall back rather than reporting a false failure.
    """
    try:
        it = tf.lite.Interpreter(model_path=path)
        it.allocate_tensors()
        return it, ""
    except Exception:
        # BUILTIN_REF uses the reference kernels, bypassing XNNPACK entirely.
        it = tf.lite.Interpreter(
            model_path=path,
            experimental_op_resolver_type=(
                tf.lite.experimental.OpResolverType.BUILTIN_REF),
        )
        it.allocate_tensors()
        return it, " (ref kernels; XNNPACK could not prepare)"


def real_mel_images(size, n=24):
    """Real UrbanSound8K audio turned into mel images of size x size x 3."""
    try:
        import librosa
    except ImportError:
        return None
    root = os.path.join(DATASETS, "audio_events", "DS09_UrbanSound8K")
    meta = os.path.join(root, "UrbanSound8K.csv")
    if not os.path.exists(meta):
        return None
    index = {os.path.basename(p): p
             for p in glob.glob(os.path.join(root, "**", "*.wav"), recursive=True)}
    paths = []
    with open(meta, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            p = index.get(row["slice_file_name"])
            if p:
                paths.append(p)
    if not paths:
        return None
    random.shuffle(paths)
    dur = 3.0 if size == 128 else 2.0
    out = []
    for p in paths:
        if len(out) >= n:
            break
        try:
            y, _ = librosa.load(p, sr=16000, mono=True)
            if len(y) < 3200:
                continue
            need = int(dur * 16000)
            y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
            mel = librosa.feature.melspectrogram(
                y=y, sr=16000, n_mels=size, hop_length=512, n_fft=2048, fmax=8000)
            db = librosa.power_to_db(mel, ref=np.max)
            nz = (db - db.min()) / (db.max() - db.min() + 1e-8)
            img = np.resize(nz, (size, size))
            out.append(np.stack([img] * 3, axis=-1).astype(np.float32))
        except Exception:
            continue
    return np.stack(out) if out else None


def real_imu(timesteps, channels, n=24):
    """Real SisFall IMU windows, day261 normalization clip(+/-8)/8."""
    sf = os.path.join(DATASETS, "motion", "DS13_SisFall", "Three Classes")
    xp = os.path.join(sf, "x_test_3")
    yp = os.path.join(sf, "y_test_3")
    if not (os.path.exists(xp) and os.path.exists(yp)):
        return None
    x = np.fromfile(xp, dtype=np.float32)
    y = np.fromfile(yp, dtype=np.float32)
    rows = y.size // 3
    per = x.size // rows
    if per % 6:
        return None
    arr = x.reshape(rows, per // 6, 6)
    labels = y.reshape(rows, 3).argmax(1)
    # Mix ADL and fall windows so a real detector has to respond differently.
    pick = list(np.flatnonzero(labels == 0)[: n // 2]) + \
        list(np.flatnonzero(labels > 0)[: n - n // 2])
    if not pick:
        return None
    t = arr.shape[1]
    start = max(0, (t - timesteps) // 2)   # centre crop: the impact is centred
    win = arr[pick, start:start + timesteps, :channels]
    if win.shape[1] < timesteps:
        return None
    return (np.clip(win, -8.0, 8.0) / 8.0).astype(np.float32)


def fixture_for(input_details):
    """Real inputs matching this model's contract, or None if we have none."""
    if len(input_details) != 1:
        return None                 # dual-input models need their own fixture
    shape = list(input_details[0]["shape"])
    if len(shape) == 4 and shape[1] == shape[2] and shape[3] == 3:
        return real_mel_images(int(shape[1]))
    if len(shape) == 3:
        return real_imu(int(shape[1]), int(shape[2]))
    return None


def evaluate(path):
    it, note = _load(path)
    ins, out = it.get_input_details(), it.get_output_details()[0]
    X = fixture_for(ins)
    if X is None:
        return "UNVERIFIED", "no real-data fixture for this input shape", note

    d = ins[0]
    vals = []
    for k in range(len(X)):
        x = X[k:k + 1]
        if d["dtype"] in (np.int8, np.uint8):
            scale, zero = d["quantization"]
            scale = scale or 1.0
            lo, hi = (-128, 127) if d["dtype"] is np.int8 else (0, 255)
            x = np.clip(np.round(x / scale + zero), lo, hi).astype(d["dtype"])
        it.set_tensor(d["index"], x)
        it.invoke()
        r = float(np.ravel(it.get_tensor(out["index"]))[0])
        if out["dtype"] == np.int8:
            scale, zero = out["quantization"]
            r = (r - zero) * (scale or 1.0)
        vals.append(r)

    arr = np.asarray(vals, dtype=np.float64)
    detail = "n=%d range[%.4f, %.4f] std=%.2e" % (
        len(arr), arr.min(), arr.max(), arr.std())
    return ("DEAD" if arr.std() < 1e-9 else "ok"), detail, note


def main():
    paths = sorted(glob.glob(os.path.join(ASSETS, "*.tflite")))
    if not paths:
        print("no models under %s" % ASSETS, file=sys.stderr)
        return 2
    if not os.path.isdir(DATASETS):
        print("note: %s not found - most models will report UNVERIFIED\n" % DATASETS)

    dead, unverified = [], []
    print("%-44s %9s  %-11s %s" % ("model", "size", "status", "detail"))
    print("-" * 104)
    for p in paths:
        name = os.path.basename(p)
        kb = os.path.getsize(p) / 1024
        if name in KNOWN_PLACEHOLDERS:
            print("%-44s %7.1fKB  PLACEHOLDER not a real model - see "
                  "DAY317_EXPORT_PATH_FIX.md" % (name, kb))
            continue
        try:
            status, detail, note = evaluate(p)
        except Exception as exc:
            print("%-44s %7.1fKB  LOAD-FAIL   %s" % (name, kb, str(exc)[:52]))
            dead.append(name)
            continue
        print("%-44s %7.1fKB  %-11s %s%s" % (name, kb, status, detail, note))
        if status == "DEAD":
            dead.append(name)
        elif status == "UNVERIFIED":
            unverified.append(name)

    print()
    if unverified:
        print("%d model(s) UNVERIFIED (no real fixture yet): %s"
              % (len(unverified), ", ".join(unverified)))
    if dead:
        print("FAILED: constant output on real data: %s" % ", ".join(dead))
        print("A constant-output model cannot detect anything. Do not ship it.")
        return 1
    print("No model was shown to be dead on real data.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
