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

# Day 330 - AUC alone CANNOT detect a collapsed model, and this gate proved it.
#
# roc_auc_score is rank-based, so it is completely scale-invariant: a model
# that returns 0.4999 for every negative and 0.5001 for every positive scores
# a perfect 1.0. i_vehicle_crash_f32 is exactly that model. Measured over 80
# unrelated real audio clips and 60 real IMU windows its ENTIRE output range
# is [0.4945, 0.5040] - 0.0095 wide, centred on 0.5, because its final
# sigmoid sits at logit ~ 0 for every input. It still scores AUC 0.9236 on
# the IMU axis, and Day 271 recorded that as "0.9622 fp32", a genuinely
# strong result. It never was one.
#
# The old DEAD check (std < 1e-9) could not see this: that model's std is
# ~2e-3, six orders of magnitude above the floor. So these two thresholds
# exist to catch the shape AUC is blind to.
#
# A detector whose whole dynamic range is under 5% of the output scale cannot
# be usefully thresholded - kDefaultThreshold 0.5 sits inside the noise - and
# two class means closer than 0.05 cannot survive any real-world calibration
# drift. Healthy shipped models are nowhere near these floors: gunshot spans
# 0.479 (std 0.150), h_aggressive_speech 0.984 (std 0.399), motion_fall and
# scream effectively the full [0, 1].
COLLAPSE_SPAN = 0.05      # max(out) - min(out) below this = not thresholdable
COLLAPSE_SEP = 0.05       # |mean(pos) - mean(neg)| below this = no effect size

import csv
import glob
import io
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


def real_prosodic_28(n=240):
    """Real ESD Mandarin audio -> (28-dim prosodic vectors, labels).

    For `m5_vocal_stress_v2`. Built from the SAME THREE HELD-OUT SPEAKERS the
    model never trained on ('0001', '0006', '0007' -- the deterministic
    seed-42 split in work/m5_28/train_m5_28.py). That is the whole point of
    this fixture: the identical data scores **0.9984** when training speakers
    leak into it and **0.7988** when they do not. A fixture drawn from
    training speakers would report ~0.99 and be worse than no fixture,
    because it would look like a pass.

    28 features, in the order the model expects:
        [ 0..12]  mfcc_mean[0..12]
        [13..25]  mfcc_std[0..12]
        [26]      zcr
        [27]      spectral centroid Hz / (sr/2)    <- the /(sr/2) matters

    librosa params: sr=16000, n_mfcc=13, n_fft=512, hop=256, 3.0 s clips.
    No pyin needed -- the 10 pitch/RMS features the training script also
    defines were measured to contribute nothing (0.7986 with them, 0.7988
    without), so this is the full input, not a subset.

    SAMPLING LIMITATION, stated rather than hidden: this takes the FIRST
    `n/2` per class encountered while scanning shards, not a uniform sample
    over all held-out clips. It therefore reads AUC 0.850 where the training
    run's full 1,020-clip held-out evaluation reads **0.7988**. The
    authoritative number is 0.7988; treat this as a regression guard -- "the
    shipped artifact still separates real held-out-speaker audio" -- not as a
    replacement for the training report. Making it uniform needs reservoir
    sampling across all 7 shards (~3 GB of parquet reads), which is too slow
    for a gate meant to run routinely.

    ESD lives on an external drive rather than under DATASETS. If it is not
    attached this returns None and the model honestly reports UNVERIFIED.
    """
    try:
        import librosa
        import pyarrow.parquet as pq
        import soundfile as sf
    except ImportError:
        return None

    esd = r"D:\zapsafe\ESD_Dataset"
    shards = sorted(glob.glob(os.path.join(esd, "train-*.parquet")))
    if not shards:
        return None

    HELD_OUT = {"0001", "0006", "0007"}
    POS = {"angry", "anger", "sad", "sadness"}
    NEG = {"neutral", "happy", "happiness"}
    SR, NEED = 16000, 16000 * 3
    per_class = max(8, n // 2)

    raw, want = [], {0: 0, 1: 0}
    for sh in shards:
        if want[0] >= per_class and want[1] >= per_class:
            break
        try:
            t = pq.read_table(sh, columns=["audio", "emotion", "language",
                                           "speaker_id"])
        except Exception:
            return None
        for a, e, lang, spk in zip(t.column("audio").to_pylist(),
                                   t.column("emotion").to_pylist(),
                                   t.column("language").to_pylist(),
                                   t.column("speaker_id").to_pylist()):
            if (lang or "").strip().lower() != "zh" or spk not in HELD_OUT:
                continue
            em = (e or "").strip().lower()
            lab = 1 if em in POS else (0 if em in NEG else None)
            if lab is None or want[lab] >= per_class:
                continue
            b = a.get("bytes") if isinstance(a, dict) else None
            if b:
                raw.append((b, lab))
                want[lab] += 1
    if want[0] < 8 or want[1] < 8:
        return None

    # Deterministic order for reproducible logs. NOTE this does not affect
    # the metric -- AUC is order-independent, and the shuffle happens after
    # collection, so it changes neither which clips were chosen nor the score.
    random.Random(42).shuffle(raw)

    X, y = [], []
    for b, lab in raw:
        try:
            wav, sr = sf.read(io.BytesIO(b), dtype="float32")
            if wav.ndim > 1:
                wav = wav.mean(axis=1)
            if sr != SR:
                wav = librosa.resample(wav, orig_sr=sr, target_sr=SR)
            if len(wav) < SR * 0.3:
                continue
            wav = (np.pad(wav, (0, NEED - len(wav)))
                   if len(wav) < NEED else wav[:NEED])
            m = librosa.feature.mfcc(y=wav, sr=SR, n_mfcc=13, n_fft=512,
                                     hop_length=256)
            zcr = float(librosa.feature.zero_crossing_rate(
                wav, frame_length=512, hop_length=256)[0].mean())
            cen = float(librosa.feature.spectral_centroid(
                y=wav, sr=SR, n_fft=512, hop_length=256)[0].mean() / (SR / 2))
            X.append(np.concatenate([m.mean(axis=1), m.std(axis=1),
                                     [zcr, cen]]).astype(np.float32))
            y.append(lab)
        except Exception:
            continue
    if len(set(y)) < 2 or len(y) < 16:
        return None
    return np.stack(X), np.asarray(y)


# Day 328 - models measured non-functional on real phone input.
#
# These four used to report UNVERIFIED because this gate had no dual-input
# fixture for them. Building one would have been actively harmful: a fixture
# drawn from their training domain reports AUC 1.0000 / 0.9959 / 1.0000, so
# it would have flipped UNVERIFIED to "ok" while every one of them remains
# incapable of producing a usable detection on a phone.
#
# The defect is not in the weights, it is in the contract between the
# training data and what the app feeds, which is why it is recorded as a
# table rather than measured here. Full evidence, and the numbers below,
# in assets/models/DAY328_DUAL_INPUT_DEAD_ON_PHONE.md; reproduce with
# tools/day328_dual_input_probe/.
KNOWN_BROKEN = {
    "s_crowd_panic.tflite": (
        "separates classes by data provenance, not panic: negatives paired "
        "with digital silence, and PAMAP2 df.iloc[:,20:26] puts chest SKIN "
        "TEMPERATURE (~35) in 'IMU' channel 0 vs ~0 for the synthetic "
        "positives. AUC 1.0000 with the mel held byte-identical. On real "
        "acc+gyro: pins ~0.54, scream-vs-calm separation 0.0048, labels "
        "97.5% of CALM windows 'panic'"),
    "k_confinement_decorrelated.tflite": (
        "same temperature-contaminated PAMAP2 slice; kImuMean[0]=18.83 is "
        "physically impossible for a carried phone. On real input outputs "
        "~0.019 and never fires at any light value; AUC(phone-real IMU vs "
        "training-slice IMU)=0.0063, i.e. near-perfect separation INVERTED"),
    "i_vehicle_crash.tflite": (
        "COLLAPSED AT SOURCE, not by quantization (Day 328 blamed int8; that "
        "was wrong). The f32 twin's entire output range over 80 real audio "
        "clips is [0.4945, 0.5040] - 0.0095 wide - and its audio branch "
        "scores AUC 0.4738, below chance. int8 faithfully encodes an already "
        "flat parent, so re-exporting cannot fix it. Separately, trained on "
        "UCI-HAR in g while the pipeline feeds sensors_plus m/s^2: 8x larger, "
        "saturating 16.7% of every window, AUC 0.5000 in app units. Needs a "
        "retrain, and no real crash IMU exists on any attached drive"),
    "m2_motion_b_retrain.tflite": (
        "BIT-EXACT DEAD: returns exactly 0.00000000 for every input. Probed "
        "15 ways - real UCI-HAR windows swept across six orders of input "
        "magnitude (x0.001 to x1000, covering g, m/s^2, SisFall ~0.24 and "
        "UniMiB scales), plus all-zeros, all-ones, randn*5 and pure 9.81 "
        "gravity: ONE distinct output. float32 tensors, so quantization is "
        "not involved. The g-vs-m/s^2 mismatch it shares with "
        "i_vehicle_crash via normalize_imu is real but irrelevant here - "
        "this model does not respond to its input at all"),
}


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
    if len(shape) == 2 and int(shape[1]) == 28:
        # Labelled, so this yields a real AUC rather than a liveness check.
        return real_prosodic_28()
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
    span = float(arr.max() - arr.min())
    if span < COLLAPSE_SPAN:
        return ("COLLAPSED",
                detail + " span=%.4f < %.2f" % (span, COLLAPSE_SPAN), note)

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
        pos = arr[labels == 1]
        neg = arr[labels == 0]
        sep = abs(float(pos.mean() - neg.mean())) if len(pos) and len(neg) else 0.0
        detail += " sep=%.4f" % sep
        if auc < WEAK_AUC:
            return "WEAK", detail, note
        # A high AUC with no effect size is the i_vehicle_crash failure: a
        # consistent ordering of numbers that are all the same. Checked AFTER
        # the AUC floor so the reported reason is the more specific one.
        if sep < COLLAPSE_SEP:
            return ("COLLAPSED",
                    detail + " (AUC %.3f is an ordering of near-identical "
                             "outputs)" % auc, note)
    return "ok", detail, note


# DCSInferenceEngine.create() declares an expectedInputSize per slot and
# calls TfliteInterpreter.tryLoad with it. That helper returns **null** when
# the model's real input size differs, and the engine then silently swaps in
# a constant-valued stub (FixedStubInterpreter, score 0.15 for motion / 0.25
# for scene). The fused DCS score drives SOS escalation via
# onDCSThresholdExceeded(), so a stubbed slot means escalation stops
# depending on that modality without anything failing.
#
# Keys are the slot name; values are (asset filename, declared input floats)
# read from lib/ml/inference/dcs_inference_engine.dart.
DCS_SLOTS = {
    "motion": ("motion_fall_v2.tflite", 6),
    "scene": ("scene_analyzer_v1.tflite", 8),
    "fusion": ("dcs_fusion_v1.tflite", 3),
}


def check_dcs_slots():
    """Compare declared vs actual input size for each DCS fusion slot."""
    import numpy as np
    rows = []
    for slot, (fname, declared) in DCS_SLOTS.items():
        path = os.path.join(ASSETS, fname)
        if not os.path.exists(path):
            rows.append((slot, fname, declared, None, "asset missing"))
            continue
        if fname in KNOWN_PLACEHOLDERS:
            rows.append((slot, fname, declared, None, "placeholder, not a model"))
            continue
        try:
            it = tf.lite.Interpreter(model_path=path)
            it.allocate_tensors()
            actual = int(np.prod(it.get_input_details()[0]["shape"]))
            rows.append((slot, fname, declared, actual,
                         "ok" if actual == declared else "STUBBED"))
        except Exception as exc:
            rows.append((slot, fname, declared, None,
                         f"load fails: {type(exc).__name__}"))
    return rows


def main():
    paths = sorted(glob.glob(os.path.join(ASSETS, "*.tflite")))
    if not paths:
        print("no models under %s" % ASSETS, file=sys.stderr)
        return 2
    if not os.path.isdir(DATASETS):
        print("note: %s not found - most models will report UNVERIFIED\n" % DATASETS)

    dead, weak, unverified, broken = [], [], [], []
    collapsed = []
    print("%-44s %9s  %-11s %s" % ("model", "size", "status", "detail"))
    print("-" * 104)
    for p in paths:
        name = os.path.basename(p)
        kb = os.path.getsize(p) / 1024
        if name in KNOWN_PLACEHOLDERS:
            print("%-44s %7.1fKB  PLACEHOLDER not a real model - see "
                  "DAY317_EXPORT_PATH_FIX.md" % (name, kb))
            continue
        if name in KNOWN_BROKEN:
            print("%-44s %7.1fKB  %-11s %s" % (name, kb, "BROKEN",
                                               KNOWN_BROKEN[name]))
            broken.append(name)
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
        elif status == "COLLAPSED":
            collapsed.append(name)
        elif status == "WEAK":
            weak.append(name)
        elif status == "UNVERIFIED":
            unverified.append(name)

    print()
    if unverified:
        print("%d model(s) UNVERIFIED (no real fixture yet): %s"
              % (len(unverified), ", ".join(unverified)))
    # --- DCS fusion slot wiring ---------------------------------------
    print()
    print("DCS fusion slots (declared input size vs the shipped model):")
    stubbed = []
    for slot, fname, declared, actual, verdict in check_dcs_slots():
        got = "n/a" if actual is None else str(actual)
        print("  %-8s %-30s declares %-5d model wants %-7s %s"
              % (slot, fname, declared, got, verdict))
        if verdict in ("STUBBED",) or verdict.startswith("load fails"):
            if fname not in KNOWN_PLACEHOLDERS:
                stubbed.append(slot)
    if stubbed:
        print("  -> %s silently fall(s) back to a CONSTANT-valued stub."
              % ", ".join(stubbed))
        print("     The fused DCS score drives SOS escalation, so escalation")
        print("     stops depending on those modalities. See")
        print("     assets/models/DAY326_DCS_FUSION_NEVER_FUSED.md")

    failed = False
    if collapsed:
        print("FAILED: output collapsed - not thresholdable: %s"
              % ", ".join(collapsed))
        print("These return nearly the same number for every input. A high "
              "AUC does not rescue that: roc_auc_score is rank-based and "
              "scale-invariant, so a consistent ordering of near-identical "
              "outputs scores well while no usable threshold exists. See "
              "COLLAPSE_SPAN / COLLAPSE_SEP.")
        failed = True
    if broken:
        print("FAILED: measured non-functional on real phone input: %s"
              % ", ".join(broken))
        print("These are not merely unverified. Each was measured against "
              "the shipped asset on real data and cannot produce a usable "
              "detection on a phone - see the per-model detail above and "
              "assets/models/DAY328_DUAL_INPUT_DEAD_ON_PHONE.md. Their live "
              "pipelines are disabled via kDualInputModelsDisabled in "
              "lib/domain/providers/live_detection_providers.dart. This gate "
              "stays red until a retrained asset replaces them, so the "
              "failure is the intended steady state, not a regression.")
        failed = True
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
