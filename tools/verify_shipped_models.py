#!/usr/bin/env python3
"""Liveness gate for the .tflite models in assets/models/.

WHY THIS EXISTS
---------------
On Day 317 the shipped mg_gunshot_v2.tflite was found to emit a CONSTANT
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
import re
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
ROOT_WORK = os.path.join(os.path.dirname(ASSETS), "..", "..", "..", "work")
ROOT_WORK = os.path.abspath(ROOT_WORK)
DATASETS = os.path.abspath(os.path.join(REPO, "..", "..", "ml_datasets"))

# Not real models. Documented rather than silently skipped.
KNOWN_PLACEHOLDERS = {"dcs_fusion_v1.tflite"}

# Day 336 - models that are feature extractors, not detectors.
#
# The gate's whole method is "feed real data, check the output separates the
# classes". That is meaningless for an encoder: mobilenetv3small's output is
# a 576-dim embedding, not a probability, so an AUC or an output-span check
# says nothing about whether it works. Evaluating it as a detector made it
# report DEAD, which is wrong rather than merely unhelpful.
#
# It is verified instead by PAIR parity against its Keras source and by the
# end-to-end chain it feeds - see tools/day334_m3_burst/probe_end_to_end.py
# and assets/models/DAY334_M3_BURST_WIRING.md.
FEATURE_EXTRACTORS = {"mobilenetv3small_encoder_float16.tflite"}

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


def real_mel_images_fsd50k(size, name=None):
    """LABELLED mel images from FSD50K eval -> (X[n,size,size,3], labels).

    This is what lets gunshot report an AUC instead of a range. Through Day
    345 the GATE's fixture was 24 UNLABELLED UrbanSound8K clips, so the gate
    itself could confirm the output moved and nothing more.

    That was a gap in the gate, not in the model's evidence -- a correction
    to an earlier reading of this. `mg_gunshot_v2` records a
    training-time held-out AUC of 0.9225 (DAY262C) and a labelled 598-clip
    UrbanSound8K measurement behind its 0.70 threshold (recall 0.960,
    precision 0.603). What it had never had is a CROSS-CORPUS number.

    Day 346 supplies one: **AUC 0.8071**, 95% CI [0.7544, 0.8605] on FSD50K
    against hard negatives. 0.92 -> 0.81 across a corpus boundary is the
    motion_fall_v2 pattern (0.99 -> 0.95), not the m3_violence one
    (0.91 -> 0.48). It generalises.

    Note `rec@0.5` is meaningless for gunshot: its outputs occupy
    [0.472, 0.984], so 0.5 fires on everything. The app ships 0.70.

    Routing is BY FILENAME, not by shape. Gunshot (128) and glass (96) share
    the [1,S,S,3] contract but need opposite label sets, and picking the
    wrong one would produce a confident, meaningless number -- the same trap
    that made two models share the [1,38] shape with different features.

    The negatives are the hard ones on purpose. Explosion (158 clips) is a
    gunshot NEGATIVE: it is the single worst confusion for this detector,
    and one that cannot separate the two fires on fireworks. Likewise
    Chink_and_clink against glass. Against easy negatives both models look
    fine, which is the trap this fixture exists to avoid.

    Preprocessing matches real_mel_images() exactly, including np.resize.

    Returns None when the extraction is absent or the model is not one of
    these two, so the caller falls back rather than inventing data.
    """
    try:
        import librosa
    except ImportError:
        return None
    key = (name or "").lower()
    if "gunshot" in key:
        POS = {"Gunshot_and_gunfire"}
        NEG = {"Explosion", "Fireworks", "Boom", "Burst_or_pop", "Crack",
               "Crackle", "Slam", "Knock", "Thump_and_thud", "Hammer",
               "Door", "Tap", "Crushing", "Drum", "Bass_drum"}
    elif "glass" in key:
        POS = {"Glass"}
        NEG = {"Chink_and_clink", "Dishes_and_pots_and_pans", "Ceramic",
               "Cutlery_and_silverware", "Coin_(dropping)", "Bell",
               "Church_bell", "Crack", "Crackle", "Tap", "Knock", "Slam",
               "Crushing", "Crumpling_and_crinkling"}
    else:
        return None

    base = os.path.join(ROOT_WORK, "fsd50k_eval")
    man_p = os.path.join(base, "manifest.json")
    audio = os.path.join(base, "audio")
    if not (os.path.exists(man_p) and os.path.isdir(audio)):
        return None
    try:
        man = json.load(open(man_p))
    except Exception:
        return None

    dur = 3.0 if size == 128 else 2.0
    out, labels = [], []
    for m in man:
        labs = set(m.get("labels", []))
        if labs & POS:
            lab = 1
        elif labs & NEG:
            lab = 0
        else:
            continue
        p = os.path.join(audio, m["fname"])
        if not os.path.exists(p):
            continue
        try:
            y, _ = librosa.load(p, sr=16000, mono=True)
            if len(y) < 3200:
                continue
            need = int(dur * 16000)
            y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
            mel = librosa.feature.melspectrogram(
                y=y, sr=16000, n_mels=size, hop_length=512, n_fft=2048,
                fmax=8000)
            db = librosa.power_to_db(mel, ref=np.max)
            rng = float(db.max() - db.min())
            if rng < 1e-8:
                continue
            nz = (db - db.min()) / (rng + 1e-8)
            img = np.resize(nz, (size, size))
            out.append(np.stack([img] * 3, axis=-1).astype(np.float32))
            labels.append(lab)
        except Exception:
            continue
    if sum(labels) < 20 or len(labels) - sum(labels) < 20:
        return None
    return np.stack(out), np.asarray(labels)


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


def _scream_mel_from_wav(path, librosa):
    """One clip -> mel[128,131], the m1_train_v2 contract. None if unusable."""
    y, sr = librosa.load(path, sr=22050, mono=True)
    if len(y) < 22050 * 0.2:
        return None
    need = 22050 * 3
    y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
    mel = librosa.feature.melspectrogram(y=y, sr=22050, n_mels=128,
                                         n_fft=2048, hop_length=512)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = float(db.max() - db.min())
    if rng < 1e-6:
        return None
    db = (db - db.min()) / (rng + 1e-9)
    if db.shape[1] < 131:
        db = np.pad(db, ((0, 0), (0, 131 - db.shape[1])))
    return db[:, :131].astype(np.float32)


def real_scream_fsd50k(n_pos=287, n_neg=1477):
    """FSD50K eval clips -> (mel[128,131], label). PREFERRED over AudioSet.

    Day 345 retired the 135-clip AudioSet fixture below. With 45 positives
    its confidence interval was ~+-0.05 -- wide enough that `scream v4`
    came back "indistinguishable" when it was in fact significantly worse,
    and wide enough that v3's recorded 0.839 survived for 20 days before
    being measured at **0.7675** here.

    This fixture is 287 positives against 1,477 negatives that are speech,
    chatter, laughter and singing -- the sounds a scream detector actually
    false-fires on. CI is ~+-0.018. It is adversarial on purpose, so the
    precision it reports is a worst case, not a field estimate.

    Returns None if the extraction is absent, so the gate falls back to the
    AudioSet fixture rather than inventing data. Build it with
    work/fsd50k_eval/extract_by_scan.py.
    """
    try:
        import librosa
    except ImportError:
        return None
    base = os.path.join(ROOT_WORK, "fsd50k_eval")
    man_p = os.path.join(base, "manifest.json")
    audio = os.path.join(base, "audio")
    if not (os.path.exists(man_p) and os.path.isdir(audio)):
        return None
    POS = {"Screaming", "Shout", "Yell"}
    NEG = {"Speech", "Chatter", "Laughter", "Singing", "Cough", "Sneeze",
           "Conversation", "Male_speech_and_man_speaking",
           "Female_speech_and_woman_speaking"}
    try:
        man = json.load(open(man_p))
    except Exception:
        return None
    rows = []
    for m in man:
        labs = set(m.get("labels", []))
        if labs & POS:
            rows.append((m["fname"], 1))
        elif labs & NEG:
            rows.append((m["fname"], 0))
    out, labels, npos, nneg = [], [], 0, 0
    for fname, lab in rows:
        if lab == 1 and npos >= n_pos:
            continue
        if lab == 0 and nneg >= n_neg:
            continue
        p = os.path.join(audio, fname)
        if not os.path.exists(p):
            continue
        try:
            mel = _scream_mel_from_wav(p, librosa)
        except Exception:
            continue
        if mel is None:
            continue
        out.append(mel)
        labels.append(lab)
        npos += lab
        nneg += 1 - lab
    if npos < 20 or nneg < 20:
        return None
    return np.stack(out), np.asarray(labels)


def real_scream_mel(n_pos=45, n_neg=90):
    """Real scream audio -> (mel[128,131], label), the m1_train_v2 contract.

    FALLBACK ONLY -- prefer real_scream_fsd50k(). Day 345 showed this
    fixture's 45 positives give a ~+-0.05 confidence interval, which is what
    let v3's 0.839 stand for 20 days against a real value of 0.7675.

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
# Day 336: s_crowd_panic and m2_motion_b_retrain were DELETED rather than
# left here. The first was a strictly worse duplicate of scream_classifier_v3
# (0.6062 against 0.8230 on the AudioSet classes it targets); the second
# returned exactly 0.0 for every input and is superseded by motion_fall_v2 at
# 0.999. Deleting beats an entry in a table nobody can act on.
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
}


def real_violence_sequences(n=400):
    """Real held-out violence clips -> ([N,16,576] embedding sequences, labels).

    For `m3_violence_temporal`. Loads the TRAINING-TIME cached features from
    `work/m3_violence/feat_val.npz` -- real MobileNetV3Small embeddings of
    real val clips from the dataset's own val/ split, which no clip in
    training appeared in.

    Using the cache rather than decoding video here is deliberate: the gate
    should not need OpenCV and 20 minutes to run, and these are the exact
    features the model was evaluated against, so a regression in the shipped
    .tflite shows up immediately. What this does NOT cover is the encoder and
    the frame sampling in front of it -- that whole chain is checked by
    tools/day334_m3_burst/probe_end_to_end.py, which scores AUC 0.9176 on raw
    video against the 0.9126 this fixture gives on cached features.

    SCOPE OF THE NUMBER THIS PRODUCES
    ---------------------------------
    The ~0.91 here is a REGRESSION check against the weights we accepted.
    Both it and the end-to-end probe use RWF -- the corpus M3 trained on --
    so on its own it says nothing about generalisation.

    It is backed by a cross-corpus number, though. Day 348 scored the
    shipped model on an independent, unprocessed violence corpus
    (A-Dataset-for-Automatic-Violence-Detection, 230 violent / 120
    non-violent) and got **AUC 0.9749, CI [0.9602, 0.9863]** -- higher than
    its own val split -- with every violent action class outranking every
    non-violent one, `choke`/`stab` (low motion) at the top and
    `jump`/`highfive` (high motion) at the bottom. It is not a motion
    detector.

    The one measured failure is narrow and worth knowing: on
    **face-anonymised** video (Dataverse, blurred/masked) it scores 0.4821,
    chance, with identical class distributions. Day 346 read that as a
    general failure to transfer; the third corpus showed Dataverse is the
    outlier. Nothing in the pipeline anonymises frames before inference, so
    this is not the shipping condition.

    See assets/models/DAY348_M3_GENERALISES_ANONYMISATION_BREAKS_IT.md
    (and DAY346_M3_DOES_NOT_TRANSFER.md, whose conclusion it supersedes).

    Returns None if the cache is absent, so the model honestly reports
    UNVERIFIED rather than the gate inventing data.
    """
    path = os.path.join(ROOT_WORK, "m3_violence", "feat_val.npz")
    if not os.path.exists(path):
        return None
    try:
        d = np.load(path)
        X, y = d["X"], d["y"]
    except Exception:
        return None
    if X.ndim != 3 or X.shape[1:] != (16, 576) or len(set(y.tolist())) < 2:
        return None
    if len(X) > n:
        idx = np.random.RandomState(0).choice(len(X), n, replace=False)
        X, y = X[idx], y[idx]
    return X.astype(np.float32), np.asarray(y)


def real_prosodic_38_yin(n=400):
    """Real ESD English -> (38-dim yin_lite vectors, labels), held-out speakers.

    For `m4_vocal_stress_en_38`. **Not interchangeable with
    `real_prosodic_38`**, even though both are [1,38]: that fixture computes
    pitch with `librosa.pyin` while this model was trained on plain YIN
    (`work/yin_lite/yin_lite.py`). Feeding it the librosa variant reports the
    model DEAD at a constant 1.0 -- a domain mismatch dressed up as a dead
    model, and the reason `fixture_for` routes this one by FILENAME rather
    than by shape.

    Rows come from `work/yin_lite/yin_lite_feats.npz`, restricted to the
    three speakers the model never trained on ('0012', '0016', '0019' -- the
    deterministic seed-42 split in work/m4_en_38/train_m4_en_38.py). Drawing
    from training speakers would report ~0.99 and be worse than no fixture.
    """
    path = os.path.join(ROOT_WORK, "yin_lite", "yin_lite_feats.npz")
    if not os.path.exists(path):
        return None
    try:
        d = np.load(path, allow_pickle=True)
        X, y, spk = d["X"], d["y"], d["spk"]
    except Exception:
        return None
    held = {"0012", "0016", "0019"}
    m = np.array([str(v) in held for v in spk])
    X, y = X[m], y[m]
    if len(X) == 0 or len(set(y.tolist())) < 2:
        return None
    if len(X) > n:
        idx = np.random.RandomState(0).choice(len(X), n, replace=False)
        X, y = X[idx], y[idx]
    return X.astype(np.float32), np.asarray(y)


def real_trac_tokens(n=3000):
    """Held-out TRAC-1 dev rows as [N, 60] int32 token ids.

    Apache-2.0, so unlike every other corpus in this gate these rows carry
    no licence problem.

    This is the IN-CORPUS number and will read ~0.83. The honest figure for
    this model is the CROSS-CORPUS one, 0.7081 on 58,477 Indo-HateSpeech
    rows -- see work/trac_aggression/crosscorpus_indo.py and
    DAY353B_FIXTURE_LEGO_REJECTED_TRAC_CROSSCORPUS.md. The gate scores
    in-corpus because that is the split with a matching label definition;
    it is not the number to quote.
    """
    path = os.path.join(ROOT_WORK, "trac_aggression", "eval_trac_dev.npz")
    if not os.path.exists(path):
        return None
    try:
        d = np.load(path, allow_pickle=True)
        X, y = d["X"].astype(np.int32), np.asarray(d["y"])
    except Exception:
        return None
    if n and len(X) > n:
        idx = np.random.RandomState(0).choice(len(X), n, replace=False)
        X, y = X[idx], y[idx]
    return X, y


def _natural_eval(tag, n=None):
    """Held-out NATURAL-speech rows for the ESD-free vocal-stress models.

    Day 353 stopped scoring m4/m5 on ESD, and the reason is not the licence
    -- it is that the acted corpus disagrees with natural speech about what
    stress looks like. `work/m4_m5_v4_signflip/diagnose.py` measured the
    per-feature direction agreement at r = -0.07 (English, CI spanning
    zero) and r = -0.56 (Mandarin, CI [-0.76, -0.29]). On Mandarin the
    eight features ESD leans on hardest every one point the other way on
    spontaneous speech.

    So an ESD score for these models is not a weak measurement, it is a
    measurement of the wrong thing, and it would read BELOW CHANCE for a
    model that is working correctly (m4 0.4069, m5 0.4913). Left routed to
    ESD, this gate would have reported both models broken on the day they
    got better.

    Rows are the exact held-out speakers from
    `work/m4_m5_v5_noesd/train_final.py`, written out by that directory's
    export step so there is one definition of "held out" rather than two
    that can drift.
    """
    sub = ("h_aggressive_v4" if tag == "h_aggressive" else "m4_m5_v5_noesd")
    path = os.path.join(ROOT_WORK, sub, "eval_%s_natural.npz" % tag)
    if not os.path.exists(path):
        return None
    try:
        d = np.load(path, allow_pickle=True)
        X, y = d["X"], np.asarray(d["y"])
    except Exception:
        return None
    if n and len(X) > n:
        idx = np.random.RandomState(0).choice(len(X), n, replace=False)
        X, y = X[idx], y[idx]
    return X.astype(np.float32), y


def real_prosodic_38_yin_zh(n=400):
    """ESD **MANDARIN** -> 38-dim yin_lite vectors, held-out speakers.

    For `m5_vocal_stress_v3_38`. The English fixture above is NOT a valid
    substitute: Day 343 measured English->Mandarin prosodic transfer at
    0.4537, so scoring a Mandarin model on English audio measures language
    transfer rather than the model. The first Day 350 gate run did exactly
    that and reported 0.709, a number that means nothing about m5.

    Rows come from `work/m5_mandarin/features.npz` (the same 38-dim
    yin_lite-compatible vector), restricted to the three speakers the model
    never trained on -- the first three by sort order, matching the
    deterministic seed-42 split in work/m4_m5_v2/train_v2.py.

    This is an in-corpus ESD number. The cross-corpus one (EmotionTalk
    natural Mandarin, 0.7810) is in DAY350_VOCAL_STRESS_V2.md and cannot be
    reproduced here without the 14,000-clip feature cache.
    """
    path = os.path.join(ROOT_WORK, "m5_mandarin", "features.npz")
    if not os.path.exists(path):
        return None
    try:
        d = np.load(path, allow_pickle=True)
        X, y, spk = d["X"], d["y"], d["spk"]
    except Exception:
        return None
    held = set(sorted({str(v) for v in spk})[:3])
    m = np.array([str(v) in held for v in spk])
    X, y = X[m], y[m]
    if len(X) == 0 or len(set(y.tolist())) < 2:
        return None
    if len(X) > n:
        idx = np.random.RandomState(0).choice(len(X), n, replace=False)
        X, y = X[idx], y[idx]
    return X.astype(np.float32), np.asarray(y)


### Day 351 - TRAINING DATA PROVENANCE AND LICENCE.
#
# This gate has always answered "does the model work". It has never answered
# "are we allowed to ship it", and Day 350 found out why that matters: the
# ESD corpus under both vocal-stress models declares cc-by-nc-4.0 on its
# HuggingFace card, while its official NUS/SUTD page states no licence at
# all, only a citation request. An absent grant is not a permissive one.
#
# That was archaeology. This table makes it an audit: every shipped asset
# names what it was trained on and the terms as recorded, and the gate
# prints a licence section on every run.
#
# "research" means released for research use with no commercial grant.
# "NC" means an explicit Non-Commercial licence. Neither is a legal opinion
# -- they are what the dataset cards and release pages say. See
# assets/models/DAY350_TRAINING_DATA_LICENCES.md.
TRAINING_DATA = {
    "scream_classifier_v5.tflite": [
        ("VocalAffectBench", "MIT"),
        ("FSD50K", "per-clip CC (CC0/BY/BY-NC mix)"),
        ("AudioSet", "labels CC-BY; audio YouTube-sourced"),
        ("ASVP-ESD", "research"),
        ("ESC-50", "CC BY-NC 3.0"),
    ],
    # Day 359: retrained on CC0/CC-BY FSD50K only. UrbanSound8K (CC BY-NC)
    # and AudioSet (YouTube-sourced audio) are both gone. Third model in the
    # project with no NC training data.
    "mg_gunshot_v2.tflite": [
        ("FSD50K (CC0 + CC BY subset only)", "CC0 / CC BY 4.0"),
    ],
    # Day 359: retrained on CC0/CC-BY FSD50K ONLY -- UrbanSound8K and the
    # Freesound-derived set are both gone, so this is the SECOND model in the
    # project with no NC training data (after trac_aggression's Apache-2.0).
    # CC BY obliges the app to credit FSD50K contributors somewhere a user can
    # reach; that is a real product task and cheaper than NC, which forbids
    # commercial use outright.
    "m_glass_breaking_v4.tflite": [
        ("FSD50K (CC0 + CC BY subset only)", "CC0 / CC BY 4.0"),
    ],
    "motion_fall_v2.tflite": [("UniMiB-SHAR", "research")],
    "m3_violence_temporal_v1.tflite": [("RWF-2000", "research")],
    # Day 353 dropped ESD from both. Not a licence-driven capability
    # sacrifice: the paired A/B put the natural-domain cost at -0.0044
    # (m5) and -0.0054 (m4), neither CI excluding zero in ESD's favour.
    "m4_vocal_stress_v3_38.tflite": [
        ("MELD", "research; audio from copyrighted broadcast"),
    ],
    "m5_vocal_stress_v3_38.tflite": [
        # Day 353 second pass: NOT unknown. The dataset's own source repo
        # (EmotionTalk-main.zip -> README.md) carries a CC BY-NC-SA 4.0
        # badge. The extracted D:\zapsafe\EmotionTalk folder holds only
        # Audio.tar and .cache, which is why the first pass read UNKNOWN --
        # the licence was one directory away, in the code repo rather than
        # the data drop. So dropping ESD did NOT trade a known NC term for
        # an unstated one; it traded NC for NC.
        ("EmotionTalk", "NC - CC BY-NC-SA 4.0 (source repo README badge)"),
    ],
    # The only Apache-2.0 entry in this table.
    "trac_aggression_v1.tflite": [("TRAC-1 (COLING 2018)", "Apache-2.0")],
    "h_aggressive_v5_38.tflite": [
        ("CREMA-D", "Open Database License"),
        ("TESS", "CC BY-NC 4.0"),
        ("RAVDESS", "CC BY-NC-SA 4.0"),
        ("SAVEE", "research"),
        ("MELD", "research; audio from copyrighted broadcast"),
    ],
    "i_vehicle_crash.tflite": [("UCI-HAR", "research")],
    "k_confinement_decorrelated.tflite": [("PAMAP2", "research")],
    "mobilenetv3small_encoder_float16.tflite": [("ImageNet", "research")],
    "dcs_fusion_v1.tflite": [("n/a - text placeholder, not a model", "n/a")],
}


def licence_report():
    """Print training-data terms for every shipped asset.

    An asset with NO entry is the loud case: unrecorded provenance is
    exactly how the ESD exposure went unnoticed for 25 days.
    """
    print("")
    print("Training-data licences (NOT a legal opinion - see "
          "DAY350_TRAINING_DATA_LICENCES.md):")
    nc, unknown, unrecorded = [], [], []
    for a in sorted(f for f in os.listdir(ASSETS) if f.endswith(".tflite")):
        rows = TRAINING_DATA.get(a)
        if rows is None:
            unrecorded.append(a)
            print("  %-42s ** NO PROVENANCE RECORDED **" % a)
            continue
        flags = set()
        for _, lic in rows:
            low = lic.lower()
            # Match 'nc' as a TOKEN. The first version of this tested
            # `startswith("nc ") or "-nc-" in low`, which missed
            # "CC BY-NC 3.0" entirely -- so UrbanSound8K (under gunshot AND
            # glass) and ESC-50 (under scream v5) were silently unflagged,
            # and scream v5 got described as the cleanest model when it is
            # not. A licence check that under-reports is worse than none.
            if re.search(r"(?<![a-z])nc(?![a-z])", low) or \
                    "non-commercial" in low:
                flags.add("NC")
            if "unknown" in low:
                flags.add("UNKNOWN")
        tag = ("   <- " + "/".join(sorted(flags))) if flags else ""
        print("  %-42s %s%s" % (a, ", ".join(c for c, _ in rows), tag))
        for corpus, lic in rows:
            print("  %-42s    %s: %s" % ("", corpus, lic))
        if "NC" in flags:
            nc.append(a)
        if "UNKNOWN" in flags:
            unknown.append(a)
    if nc:
        print("  -> Non-Commercial training data: %s" % ", ".join(nc))
    if unknown:
        print("  -> UNKNOWN terms: %s" % ", ".join(unknown))
    if unrecorded:
        print("  -> NO PROVENANCE RECORDED: %s" % ", ".join(unrecorded))
    print("  This gate does not fail on licence; it makes the question "
          "visible on every run.")


def fixture_for(input_details, name=None):
    """Real inputs matching this model's contract, or None if we have none.

    `name` matters for [1,38]: two shipped models share that shape with
    DIFFERENT feature definitions (librosa.pyin vs plain YIN pitch), so shape
    alone cannot pick the right fixture.
    """
    if len(input_details) != 1:
        return None                 # dual-input models need their own fixture
    shape = list(input_details[0]["shape"])
    if len(shape) == 2 and shape[1] == 60 and             input_details[0]["dtype"] == np.int32:
        # Day 391: the only TEXT model in the gate. Token ids, not floats --
        # standardising these would be meaningless and normalising them
        # catastrophic, so it returns early before any float path.
        return real_trac_tokens()
    if len(shape) == 4 and shape[1] == 128 and shape[2] == 131:
        # m1 scream family: labelled fixture, so this gets a real AUC.
        # FSD50K first (287 positives, CI ~+-0.018); the 45-positive
        # AudioSet fixture is only a fallback when that extraction is
        # absent, because its CI is wide enough to hide a real regression.
        got = real_scream_fsd50k() or real_scream_mel()
        if got is None:
            return None
        Xs, ys = got
        chan = int(shape[3])
        return (np.stack([Xs] * chan, axis=-1) if chan > 1 else Xs[..., None]), ys
    if len(shape) == 4 and shape[1] == shape[2] and shape[3] == 3:
        # Mel-image models (gunshot 128, glass 96). Prefer the LABELLED
        # FSD50K fixture so these report a real AUC: until Day 346 the gate's
        # own fixture here was 24 UNLABELLED UrbanSound8K clips, on which it
        # could say "the output moves" but never "the output is right".
        got = real_mel_images_fsd50k(int(shape[1]), name)
        if got is not None:
            return got
        X = real_mel_images(int(shape[1]))
        return None if X is None else (X, None)
    # Must precede the generic [1, T, C] IMU branch below: [1,16,576] is an
    # embedding sequence, not a sensor window, and the IMU fixture would
    # swallow it and return None (UniMiB has 3 channels, not 576).
    if len(shape) == 3 and int(shape[1]) == 16 and int(shape[2]) == 576:
        return real_violence_sequences()
    if len(shape) == 3:
        return real_imu(int(shape[1]), int(shape[2]))
    if len(shape) == 2 and int(shape[1]) == 38:
        # THREE shipped models now share [1,38] with TWO different feature
        # definitions, so this must route by filename and the list must be
        # kept current. Getting it wrong is not a soft failure: feeding a
        # yin_lite model the librosa.pyin fixture reports it DEAD at a
        # constant 1.0.
        #
        #   yin_lite (plain YIN, frame 512 / hop 256):
        #     m4_vocal_stress_en_38   (Day 333, superseded)
        #     m4_vocal_stress_v3_38   (Day 350, ships)
        #     m5_vocal_stress_v3_38   (Day 350, ships -- Mandarin)
        #   librosa.pyin (frame 2048 / hop 512):
        #     (none shipped -- h_aggressive_speech_v1 deleted Day 352)
        #   plain YIN (frame 2048 / hop 512):
        #     h_aggressive_v5_38   -> MELD test+dev fixture (Day 353)
        # Day 358: matches v4 OR v5 -- same feature space, only the training
        # recipe changed (class_weight in place of corpus_weights, plus a
        # regularised head). A prefix pinned to one version would silently
        # stop routing on the next rename and fall through to UNVERIFIED.
        if name and name.startswith("h_aggressive_v"):
            # Day 353: a fixture in v4's OWN space now exists -- MELD
            # test+dev featurised by featurise_yin2048.py, the same
            # extractor that trained it, and a split it never trains on.
            # Expect ~0.64, which is the natural-speech number from
            # DAY352_H_AGGRESSIVE_V4_WIRED.md rather than a fresh claim.
            #
            # This is the third distinct [1,38] feature definition in this
            # gate, which is why routing is by filename and never by shape.
            fx = _natural_eval("h_aggressive")
            if fx is not None:
                return fx
            # Day 352: v4 is plain YIN at frame 2048 / hop 512. Neither
            # existing fixture matches it -- real_prosodic_38_yin is
            # yin_lite at 512/256 and real_prosodic_38 is librosa.pyin at
            # 2048/512. Handing it either would report a confident wrong
            # number, which is precisely how m4 once read DEAD at a constant
            # 1.0. Returning None makes it report UNVERIFIED honestly.
            #
            # Its real numbers are in DAY352_H_AGGRESSIVE_V4_WIRED.md
            # (natural 0.6415, CI [0.6171, 0.6656]) and the Dart feature
            # path is pinned by test/day352_aggressive_speech_features_test
            # .dart against the extractor that trained it.
            return None
        if name and name.startswith("m5_vocal_stress"):
            # MANDARIN model -> Mandarin fixture. Using the English one
            # measures language transfer (0.4537, Day 343), not the model.
            # Day 353: and it must be NATURAL Mandarin, not ESD -- see
            # _natural_eval. Expect ~0.79.
            return _natural_eval("m5") or real_prosodic_38_yin_zh()
        if name and name.startswith("m4_vocal_stress"):
            # Day 353: natural English (MELD held-out speakers), not ESD.
            # Expect ~0.65. The ESD fixture is kept as the fallback only
            # for the superseded Day 333 asset.
            return _natural_eval("m4") or real_prosodic_38_yin()
        if name and name.startswith("m4_vocal_stress"):
            return real_prosodic_38_yin()
        X = real_prosodic_38()
        return None if X is None else (X, None)
    if len(shape) == 2 and int(shape[1]) == 28:
        # Labelled, so this yields a real AUC rather than a liveness check.
        return real_prosodic_28()
    return None


def evaluate(path):
    it, note = _load(path)
    ins, out = it.get_input_details(), it.get_output_details()[0]
    got = fixture_for(ins, name=os.path.basename(path))
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
    "scene": ("m3_violence_temporal_v1.tflite", 8),
    "fusion": ("dcs_fusion_v1.tflite", 3),
}

# Day 347 - slots whose shape mismatch is ROUTED AROUND in the live path.
#
# This block exists because the output above misled a reader into reporting
# the motion slot as a live defect that "neutralises the best detector". It
# is not. Day 327 added `motionResultOverride` and Day 335 added
# `sceneResultOverride`: the engine's own 6-float / 8-float slots are legacy
# fallbacks, and lib/domain/providers/inference_providers.dart passes the
# real windowed result past them on every pass.
#
# So a shape mismatch here means "the legacy fallback cannot load", which is
# expected and already handled -- NOT "this modality contributes nothing".
# The thing that would actually break the live path is the override arriving
# null, which no static check can see; it is a runtime condition (before the
# first 100-sample window, or a pipeline that failed to load).
#
# Values: (override parameter, the provider line that supplies it).
LIVE_OVERRIDES = {
    "motion": ("motionResultOverride",
               "inference_providers.dart -> motionPipeline?.latestResult"),
    "scene": ("sceneResultOverride",
              "inference_providers.dart -> burst?.latestResult (30 s bound)"),
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
            # Use _load(), not a bare Interpreter: scene_analyzer_v1 cannot
            # prepare under desktop XNNPACK, and calling it directly made
            # this check print "load fails" for a model the main table above
            # reports as ok. Two lines of the same report disagreeing about
            # the same file is worse than either verdict alone.
            it, _ = _load(path)
            actual = int(np.prod(it.get_input_details()[0]["shape"]))
            if actual == declared:
                verdict = "ok"
            elif slot in LIVE_OVERRIDES:
                verdict = "legacy-slot (live path overrides)"
            else:
                verdict = "STUBBED"
            rows.append((slot, fname, declared, actual, verdict))
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
        if name in FEATURE_EXTRACTORS:
            print("%-44s %7.1fKB  %-11s %s" % (
                name, kb, "ENCODER",
                "feature extractor, not a detector - an AUC on a 576-dim "
                "embedding is meaningless. Verified by parity against its "
                "Keras source (corr 0.999984) and end-to-end via "
                "tools/day334_m3_burst/"))
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
    # --- training-data provenance -------------------------------------
    licence_report()

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
    for slot, (param, src) in sorted(LIVE_OVERRIDES.items()):
        print("  -> %-8s legacy slot is bypassed at runtime via %s"
              % (slot, param))
        print("     %s" % src)
    print("     A mismatch above is therefore EXPECTED and handled. What it")
    print("     does NOT prove is that the override is non-null at runtime,")
    print("     which no static check can see -- see DAY347 notes.")
    if stubbed:
        print("  -> %s has no override and silently falls back to a "
              "CONSTANT-valued stub." % ", ".join(stubbed))
        print("     The fused DCS score drives SOS escalation, so escalation")
        print("     stops depending on that modality. See")
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
