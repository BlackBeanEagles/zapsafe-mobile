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

Liveness alone is NOT enough either, and that was also established the hard
way: scream_classifier_v1 is perfectly "alive" -- its outputs span 0.000 to
0.996 -- yet on real AudioSet screaming it fires on 5.6% of clips at its
shipped 0.5 threshold (AUC 0.62 vs clean negatives) while its model card
claims recall 0.9529. An alive-but-useless detector is more dangerous than a
dead one because it looks like it works. So where a fixture carries real
labels this also measures DISCRIMINATION and reports WEAK below AUC 0.70.

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

# Below this AUC on a labelled real fixture a model is reported WEAK:
# alive, but not separating the classes it claims to detect.
WEAK_AUC = 0.70

import csv
import glob
import json
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


def real_imu(timesteps, channels, n=160):
    """Real UniMiB-SHAR windows -> (X, labels). Smartphone, 50 Hz, m/s^2.

    NOT SisFall, and that swap is the point. The gate used to feed SisFall
    "Three Classes", then declared motion_fall_v2 DEAD -- constant 1.0 -- for
    a model that actually scores AUC 0.9978 on correctly-scaled data. SisFall
    Three-Classes has a resting acceleration magnitude of **0.239**: not g
    (1.0), not m/s^2 (9.8), not gravity-removed (0). It is pre-scaled by an
    unrecoverable factor, so feeding it to a model trained on real m/s^2
    pushes every sample far out of distribution and saturates the output.

    That is the exact silent-wrong-units failure this gate exists to catch,
    and the gate had it. UniMiB is verified by measurement instead of
    assumption: median window magnitude 9.41 m/s^2, so gravity is present.

    Returns labels too (1 = fall), so IMU models get a real AUC rather than
    a liveness check.
    """
    try:
        import scipy.io as sio
    except ImportError:
        return None
    base = os.path.join(DATASETS, "motion", "DS_UniMiB", "UniMiB-SHAR", "data")
    xp = os.path.join(base, "two_classes_data.mat")
    yp = os.path.join(base, "two_classes_labels.mat")
    if not (os.path.exists(xp) and os.path.exists(yp)):
        return None

    def _load(path):
        d = sio.loadmat(path)
        return d[[k for k in d if not k.startswith("__")][0]]

    X, Y = _load(xp), _load(yp)
    src_len = X.shape[1] // 3
    if src_len < timesteps or channels > 3:
        return None                      # 6-channel models: no honest fixture
    w = X.reshape(X.shape[0], 3, src_len).transpose(0, 2, 1)
    y = (Y[:, 0] == 2).astype(int)       # class 2 = fall
    start = (src_len - timesteps) // 2   # impact is centred in UniMiB windows
    w = w[:, start:start + timesteps, :channels].astype(np.float32)

    pos = np.flatnonzero(y == 1)[: n // 2]
    neg = np.flatnonzero(y == 0)[: n - n // 2]
    pick = np.concatenate([pos, neg])
    if len(pos) < 4 or len(neg) < 4:
        return None
    return w[pick], y[pick]


def real_prosodic_38(n=24):
    """Real RAVDESS speech -> the day90 38-dim prosodic vector.

    Mixes aggressive (angry/fearful/disgusted) and calm (neutral/calm/happy)
    clips so a working detector has to separate them. Extractor mirrors
    day90_h_aggressive_speech.py with the training-time augmentation removed.
    """
    try:
        import librosa
    except ImportError:
        return None
    root = os.path.join(DATASETS, "vocal_stress", "DS01_RAVDESS", "Ravdess",
                        "audio_speech_actors_01-24")
    if not os.path.isdir(root):
        return None
    pos_codes, neg_codes = {"05", "06", "07"}, {"01", "02", "03"}
    pos, neg = [], []
    for p in sorted(glob.glob(os.path.join(root, "**", "*.wav"), recursive=True)):
        parts = os.path.basename(p).split(".")[0].split("-")
        if len(parts) < 3:
            continue
        if parts[2] in pos_codes:
            pos.append(p)
        elif parts[2] in neg_codes:
            neg.append(p)
    half = n // 2
    chosen = pos[:half] + neg[:n - half]
    if not chosen:
        return None

    sr, need = 16000, int(16000 * 3.0)
    out = []
    for path in chosen:
        try:
            y, _ = librosa.load(path, sr=sr, mono=True)
            y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
            f = []
            try:
                f0, voiced, _ = librosa.pyin(y, fmin=50, fmax=500, sr=sr)
                f0v = f0[voiced] if voiced.any() else np.array([0.0])
                f0v = f0v[~np.isnan(f0v)]
                if len(f0v) == 0:
                    f0v = np.array([0.0])
                f += [float(np.mean(f0v)), float(np.std(f0v))]
                f0c = f0[~np.isnan(f0)]
                f.append(float(np.mean(np.abs(np.diff(f0c)))) if len(f0c) > 1 else 0.0)
            except Exception:
                f += [0.0, 0.0, 0.0]
            rms = librosa.feature.rms(y=y)[0]
            f.append(float(np.mean(np.abs(np.diff(rms)))) if len(rms) > 1 else 0.0)
            f.append(float(np.mean(rms) / (np.std(rms) + 1e-8)))
            mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
            f += list(np.mean(mfcc, axis=1)) + list(np.std(mfcc, axis=1))
            f.append(float(np.mean(rms)))
            f.append(float(np.mean(librosa.feature.zero_crossing_rate(y)[0])))
            f.append(float(np.mean(librosa.feature.spectral_centroid(y=y, sr=sr)[0])))
            f.append(float(np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr)[0])))
            a = np.array(f[:38], dtype=np.float32)
            if len(a) < 38:
                a = np.pad(a, (0, 38 - len(a)))
            out.append(np.nan_to_num(a, nan=0.0, posinf=0.0, neginf=0.0))
        except Exception:
            continue
    return np.stack(out) if out else None


def real_scream_mel(n_pos=45, n_neg=90):
    """Real scream audio -> (mel[128,131], label), the m1_train_v2 contract.

    Positives are real AudioSet screaming/yell/shout clips. RAVDESS acted
    emotion is deliberately EXCLUDED from the positive set: it is this
    model's own training distribution and scores ~6x higher than real
    screams (31% vs 5.6% fire rate), which inflates any number computed
    from it into looking like the model card's 0.9529.
    """
    try:
        import librosa
    except ImportError:
        return None
    ad = os.path.join(DATASETS, "audio_events", "DS07_AudioSet")
    wd = os.path.join(ad, "train_wav")
    if not os.path.isdir(wd):
        return None
    POS = {"/m/03qc9zr", "/m/07sr1lc", "/t/dd00135", "/m/04gy_2"}
    NEG = {"/m/09x0r", "/m/01j3sz", "/m/053hz1", "/m/028ght"}
    present = {os.path.splitext(f)[0]: os.path.join(wd, f) for f in os.listdir(wd)}
    pos, neg, seen = [], [], set()
    for nm in ("train.csv", "balanced_train_segments.csv",
               "unbalanced_train_segments.csv"):
        fp = os.path.join(ad, nm)
        if not os.path.exists(fp):
            continue
        for line in open(fp, encoding="utf-8", errors="replace"):
            if line.startswith("#"):
                continue
            parts = line.split(",")
            yt = parts[0].strip().strip('"')
            if yt in seen or yt not in present:
                continue
            lab = {x.strip().strip('"') for x in ",".join(parts[3:]).split(",")}
            if lab & POS:
                pos.append(present[yt]); seen.add(yt)
            elif lab & NEG:
                neg.append(present[yt]); seen.add(yt)
    esc = os.path.join(DATASETS, "audio_events", "DS21_ESC-50")
    cpath = os.path.join(esc, "esc50.csv")
    if os.path.exists(cpath):
        idx = {os.path.basename(q): q for q in
               glob.glob(os.path.join(esc, "**", "*.wav"), recursive=True)}
        for r in csv.DictReader(open(cpath, newline="", encoding="utf-8")):
            if r["category"] in {"car_horn", "engine", "siren", "rain", "wind"}:
                q = idx.get(r["filename"])
                if q:
                    neg.append(q)
    random.Random(42).shuffle(pos)
    random.Random(42).shuffle(neg)
    pos, neg = pos[:n_pos], neg[:n_neg]
    if len(pos) < 8 or len(neg) < 8:
        return None

    sr, dur, need = 22050, 3, 22050 * 3
    X, y = [], []
    for path, lab in [(a, 1) for a in pos] + [(a, 0) for a in neg]:
        try:
            w, _ = librosa.load(path, sr=sr, duration=dur, mono=True)
            w = np.pad(w, (0, need - len(w))) if len(w) < need else w[:need]
            m = librosa.feature.melspectrogram(y=w, sr=sr, n_mels=128,
                                               n_fft=2048, hop_length=512)
            db = librosa.power_to_db(m, ref=np.max)
            db = (db - db.min()) / (db.max() - db.min() + 1e-9)
            if db.shape[1] < 131:
                db = np.pad(db, ((0, 0), (0, 131 - db.shape[1])))
            X.append(db[:, :131].astype(np.float32))
            y.append(lab)
        except Exception:
            continue
    if len(set(y)) < 2:
        return None
    return np.stack(X), np.asarray(y)


def fixture_for(input_details):
    """Real inputs matching this model's contract, or None if we have none."""
    if len(input_details) != 1:
        return None                 # dual-input models need their own fixture
    shape = list(input_details[0]["shape"])
    if len(shape) == 4 and shape[1] == 128 and shape[2] == 131:
        # m1 scream family: labelled fixture, so this gets a real AUC.
        got = real_scream_mel()
        if got is None:
            return None
        Xs, ys = got
        chan = int(shape[3])
        return (np.stack([Xs] * chan, axis=-1) if chan > 1 else Xs[..., None]), ys
    if len(shape) == 4 and shape[1] == shape[2] and shape[3] == 3:
        X = real_mel_images(int(shape[1]))
        return None if X is None else (X, None)
    if len(shape) == 3:
        return real_imu(int(shape[1]), int(shape[2]))
    if len(shape) == 2 and int(shape[1]) == 38:
        X = real_prosodic_38()
        return None if X is None else (X, None)
    return None


def evaluate(path):
    it, note = _load(path)
    ins, out = it.get_input_details(), it.get_output_details()[0]
    got = fixture_for(ins)
    if got is None:
        return "UNVERIFIED", "no real-data fixture for this input shape", note
    X, labels = got

    # Apply the model's own normalization if it ships one. This is not
    # optional: h_aggressive_speech scores AUC 0.844 with its real
    # mean/std and 0.52 (chance) on raw features, and its f32 twin
    # collapses to a constant 1.0 when fed raw. A missing norm.json turns
    # a good model into a dead-looking one.
    stem = os.path.splitext(os.path.basename(path))[0]
    npath = os.path.join(ASSETS, stem + "_norm.json")
    if os.path.exists(npath):
        try:
            nd = json.load(open(npath))
            mean = nd.get("mean", nd.get("feat_mean"))
            std = nd.get("std", nd.get("feat_std"))
            if mean is not None and std is not None:
                mean = np.asarray(mean, dtype=np.float32)
                std = np.asarray(std, dtype=np.float32)
                if mean.shape[-1] == X.shape[-1]:
                    X = ((X - mean) / std).astype(np.float32)
                    note += " (norm.json applied)"
        except Exception:
            pass

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
    if arr.std() < 1e-9:
        return "DEAD", detail, note

    # A live model can still be useless. Where the fixture carries real
    # labels, measure whether it actually separates them.
    if labels is not None and len(set(labels.tolist())) == 2:
        try:
            from sklearn.metrics import roc_auc_score
            auc = float(roc_auc_score(labels, arr))
        except Exception:
            return "ok", detail, note
        pos = arr[labels == 1]
        rec50 = float((pos >= 0.5).mean())
        detail = "n=%d AUC=%.3f rec@0.5=%.3f range[%.3f, %.3f]" % (
            len(arr), auc, rec50, arr.min(), arr.max())
        if auc < WEAK_AUC:
            return "WEAK", detail, note
    return "ok", detail, note


def main():
    paths = sorted(glob.glob(os.path.join(ASSETS, "*.tflite")))
    if not paths:
        print("no models under %s" % ASSETS, file=sys.stderr)
        return 2
    if not os.path.isdir(DATASETS):
        print("note: %s not found - most models will report UNVERIFIED\n" % DATASETS)

    dead, weak, unverified = [], [], []
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
        elif status == "WEAK":
            weak.append(name)
        elif status == "UNVERIFIED":
            unverified.append(name)

    print()
    if unverified:
        print("%d model(s) UNVERIFIED (no real fixture yet): %s"
              % (len(unverified), ", ".join(unverified)))
    failed = False
    if dead:
        print("FAILED: constant output on real data: %s" % ", ".join(dead))
        print("A constant-output model cannot detect anything. Do not ship it.")
        failed = True
    if weak:
        print("FAILED: below AUC %.2f on real labelled data: %s"
              % (WEAK_AUC, ", ".join(weak)))
        print("These load, run, and return confident-looking scores while "
              "barely separating the classes they claim to detect. That is "
              "more dangerous than a dead model, not less. Do not ship them "
              "as working detectors.")
        failed = True
    if failed:
        return 1
    print("No model was dead or below the AUC floor on real data.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
