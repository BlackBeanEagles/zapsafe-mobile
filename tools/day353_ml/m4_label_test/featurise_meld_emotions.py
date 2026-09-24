"""Day 355 - re-featurise MELD keeping the EMOTION, not just the pooled label.

WHY
===
Day 354 decomposed m4's positive class against CMU-MOSEI and found the
pooling is the problem:

    MOSEI anger vs MELD   r = +0.061  CI [-0.257, +0.370]
    MOSEI sad   vs MELD   r = -0.669  CI [-0.794, -0.512]

m4 calls "stressed" = anger OR sad. Angry speech is loud, fast and
high-pitched; sad speech is quiet, slow and low-pitched. One direction in
feature space is being asked to mean both, and whichever emotion a corpus
contains more of decides the sign.

That predicts m4 would be BETTER at anger alone than at anger+sad. It could
not be tested on Day 354 because every cached MELD fixture stores only the
pooled `y` -- the emotion string was thrown away at featurisation time.

This rebuilds MELD train AND test+dev in m4's 512/256 space, carrying the
emotion through, so the three candidate definitions can be compared on
identical rows:

    anger+sad   what m4 ships today
    anger-only  the narrower construct
    sad-only    the other half, as a control

LABEL SETS are otherwise untouched: negatives stay neutral + happy, and
fear/disgust/surprise stay dropped, exactly as m4 was trained.

This script only builds features. ab_label.py decides, and it is scored on
MELD test+dev -- rows neither arm trains on.

NOTE ON THE CONTROL: if anger-only beats anger+sad it is NOT automatically
the right answer. It would be a narrower model, and for a personal-safety
app a distressed user's sadness may be the signal worth keeping. The
measurement informs that product decision; it does not make it.
"""
from __future__ import annotations

import glob
import os
import re
import sys
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
MELD = os.path.join(ROOT, r"ml_datasets\vocal_stress\DS_MELD\preprocessed_data")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
WORKERS = 8

KEEP = {"angry", "anger", "sad", "sadness", "neutral", "happy", "happiness",
        "joy"}
CANON = {"angry": "anger", "anger": "anger", "sad": "sad", "sadness": "sad",
         "neutral": "neutral", "happy": "happy", "happiness": "happy",
         "joy": "happy"}


def features38(y, librosa):
    """Verbatim from work/m4_m5_v2/featurise_natural.py -- 512/256."""
    import yin_lite
    yin_lite.FRAME, yin_lite.HOP = 512, 256
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    fl, hl = 512, 256
    pitch = yin_lite.pitch_features(y)
    rms = librosa.feature.rms(y=y, frame_length=fl, hop_length=hl)[0]
    shimmer = float(np.mean(np.abs(np.diff(rms)))) if len(rms) > 1 else 0.0
    ac = np.correlate(y, y, mode="full")
    ac = ac[len(ac) // 2:]
    hnr = float(np.clip(
        float(np.max(ac[1:min(len(ac), int(SR * 0.02))]) / (ac[0] + 1e-8)),
        0, 1))
    mf = librosa.feature.mfcc(y=y, sr=SR, n_mfcc=13, n_fft=fl, hop_length=hl)
    out = np.concatenate([
        pitch, [shimmer, hnr], mf.mean(axis=1), mf.std(axis=1),
        [float(rms.mean()), float(rms.std()), float(rms.max()),
         float(librosa.feature.zero_crossing_rate(
             y, frame_length=fl, hop_length=hl)[0].mean()),
         float(librosa.feature.spectral_centroid(
             y=y, sr=SR, n_fft=fl, hop_length=hl)[0].mean() / (SR / 2))],
    ]).astype(np.float32)
    return np.nan_to_num(out, nan=0.0, posinf=0.0, neginf=0.0)


def _one(path):
    import librosa
    import torch
    try:
        d = torch.load(path, map_location="cpu", weights_only=False)
        emo = str(d.get("emotion", "")).lower()
        if emo not in KEEP:
            return None
        sr = int(d.get("audio_sample_rate", SR))
        w = d["audio"]
        w = w.numpy() if hasattr(w, "numpy") else np.asarray(w)
        w = w.reshape(-1).astype(np.float64)
        if sr != SR:
            w = librosa.resample(w, orig_sr=sr, target_sr=SR)
        if len(w) < int(SR * 0.3):
            return None
        m = re.match(r"(dia\d+)", os.path.basename(path))
        return (features38(w, librosa), CANON[emo],
                "meld_" + (m.group(1) if m else "unk"))
    except Exception:
        return None


def build(split_dirs, tag):
    files = []
    for s in split_dirs:
        files += sorted(glob.glob(os.path.join(MELD, s, "*.pt")))
    print("[%s] %d files" % (tag, len(files)), flush=True)
    X, emo, spk = [], [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, files, chunksize=8)):
            if r is None:
                bad += 1
                continue
            a, e, s = r
            X.append(a)
            emo.append(e)
            spk.append(s)
            if (k + 1) % 1000 == 0:
                print("  [%s] %d/%d %ds" % (tag, k + 1, len(files),
                                            int(time.time() - t0)),
                      flush=True)
    X = np.vstack(X)
    emo = np.array(emo)
    spk = np.array(spk)
    import collections
    print("[%s] -> %s  dropped %d  %s"
          % (tag, X.shape, bad, dict(collections.Counter(emo.tolist()))))
    np.savez_compressed(os.path.join(HERE, "meld_%s_emo.npz" % tag),
                        X=X, emo=emo, spk=spk)
    return X.shape


def main():
    build(["train"], "train")
    build(["test", "dev"], "eval")
    print("done")


if __name__ == "__main__":
    main()
