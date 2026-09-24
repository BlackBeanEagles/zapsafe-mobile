"""Day 350 - featurise the NATURAL-speech halves for m4 and m5 v2.

Day 349 measured both shipped models at chance on natural speech (m4 0.4813
on MELD, m5 0.4865 on EmotionTalk, against in-corpus 0.8321 and 0.7988).
Day 348 established the fix on h_aggressive: adding natural speech moved it
from 0.4780 to 0.6661. This collects the data to do the same here.

WHAT IS COLLECTED, AND WHAT IS DELIBERATELY NOT
===============================================
* **MELD train** for m4. Its test+dev were the Day 349 evaluation and are
  already cached in `m4_m5_crosscorpus/feat_meld_yin.npz`; they are NOT
  touched here, so the v1-vs-v2 comparison stays on identical rows.
* **EmotionTalk with speaker ids** for m5. The Day 349 run cached 4,000
  clips but `run_pool` saved only X and y, so speaker is unrecoverable from
  it. Without speaker there is no way to build a speaker-disjoint split, and
  a random split over EmotionTalk would leak: it is conversational, so
  utterances from one dialogue share voice, room and mic. So it is
  re-collected rather than reused -- 14,000 clips this time, with the group
  id carried through.

FEATURES
========
`features38()` is the yin_lite vector from
`work/m5_zh_38/featurise_zh.py::work()` -- plain YIN pitch, frame 512 /
hop 256. This is NOT h_aggressive's 38-dim vector (librosa.pyin, 2048/512);
feeding m4 that variant reports it dead at a constant 1.0. m5 later takes
`AVAIL = range(7,33) + [36,37]`, the 28 features Dart can compute.

LABELS, unchanged from what the models were trained on:
    stressed (1)  angry, sad
    calm     (0)  neutral, happy
Everything else is dropped -- these models were never trained to place
fear, disgust or surprise.
"""
from __future__ import annotations

import collections
import glob
import io
import json
import os
import sys
import tarfile
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
MELD = os.path.join(ROOT, r"ml_datasets\vocal_stress\DS_MELD\preprocessed_data")
ETALK = r"D:\zapsafe\EmotionTalk\Audio.tar"

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
WORKERS = 6
ETALK_LIMIT = 14000

POS = {"angry", "anger", "sad", "sadness"}
NEG = {"neutral", "happy", "happiness", "joy"}


def features38(y, librosa):
    """Verbatim from work/m5_zh_38/featurise_zh.py::work()."""
    import yin_lite
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


def _meld_one(path):
    import librosa
    import re
    import torch
    try:
        d = torch.load(path, map_location="cpu", weights_only=False)
        emo = str(d.get("emotion", "")).lower()
        lab = 1 if emo in POS else (0 if emo in NEG else None)
        if lab is None:
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
        return features38(w, librosa), lab, "meld_" + (m.group(1) if m
                                                       else "unk")
    except Exception:
        return None


def _etalk_one(item):
    import librosa
    import soundfile as sf
    raw, lab, spk = item
    try:
        y, sr = sf.read(io.BytesIO(raw), dtype="float64")
        if y.ndim > 1:
            y = y.mean(axis=1)
        if sr != SR:
            y = librosa.resample(y, orig_sr=sr, target_sr=SR)
        if len(y) < int(SR * 0.3):
            return None
        return features38(y, librosa), lab, spk
    except Exception:
        return None


def collect_etalk():
    """Majority of five annotators; no-majority clips dropped, not forced."""
    labels = {}
    with tarfile.open(ETALK, "r:") as t:
        for m in t:
            if not m.isfile() or not m.name.endswith(".json"):
                continue
            try:
                d = json.loads(t.extractfile(m).read()
                               .decode("utf-8", "replace"))
            except Exception:
                continue
            votes = [str(v.get("emotion", "")).lower()
                     for v in (d.get("data") or {}).values()]
            votes = [v for v in votes if v]
            if not votes:
                continue
            c = collections.Counter(votes).most_common()
            if len(c) > 1 and c[0][1] == c[1][1]:
                continue
            lab = 1 if c[0][0] in POS else (0 if c[0][0] in NEG else None)
            if lab is not None:
                labels[os.path.basename(m.name)[:-5]] = lab
    print(f"  majority-labelled clips: {len(labels)}", flush=True)

    items = []
    with tarfile.open(ETALK, "r:") as t:
        for m in t:
            if not m.isfile() or not m.name.endswith(".wav"):
                continue
            if len(items) >= ETALK_LIMIT:
                break
            key = os.path.basename(m.name)[:-4]
            if key not in labels:
                continue
            items.append((t.extractfile(m).read(), labels[key],
                          "et_" + key.split("_")[0]))
    return items


def run_pool(items, fn, tag):
    cache = os.path.join(HERE, f"feat_{tag}.npz")
    if os.path.exists(cache):
        d = np.load(cache, allow_pickle=True)
        print(f"[{tag}] cached {d['X'].shape} pos={int(d['y'].sum())} "
              f"groups={len(set(d['spk'].tolist()))}")
        return
    t0, feats, labs, spks = time.time(), [], [], []
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for i, r in enumerate(ex.map(fn, items, chunksize=8)):
            if r is not None:
                feats.append(r[0]); labs.append(r[1]); spks.append(r[2])
            if (i + 1) % 1000 == 0:
                print(f"  [{tag}] {i+1}/{len(items)} "
                      f"{time.time()-t0:.0f}s", flush=True)
    X = np.stack(feats)
    y = np.asarray(labs, np.int32)
    spk = np.asarray(spks)
    np.savez_compressed(cache, X=X, y=y, spk=spk)
    print(f"[{tag}] -> {X.shape} pos={int(y.sum())} neg={int((1-y).sum())} "
          f"groups={len(set(spks))}  {time.time()-t0:.0f}s", flush=True)


def main():
    which = sys.argv[1:] or ["meld_train", "etalk"]
    if "meld_train" in which:
        files = sorted(glob.glob(os.path.join(MELD, "train", "*.pt")))
        print(f"[meld_train] {len(files)} files (test+dev untouched)")
        run_pool(files, _meld_one, "meld_train")
    if "etalk" in which:
        cache = os.path.join(HERE, "feat_etalk.npz")
        if os.path.exists(cache):
            run_pool([], _etalk_one, "etalk")
        else:
            print("[etalk] streaming the 14.8 GB tar ...", flush=True)
            items = collect_etalk()
            print(f"[etalk] {len(items)} clips collected", flush=True)
            run_pool(items, _etalk_one, "etalk")
    print("\ndone")


if __name__ == "__main__":
    main()
