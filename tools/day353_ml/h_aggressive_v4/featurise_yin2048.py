"""Day 352 - h_aggressive with plain YIN at librosa's FRAME SIZE.

THE CAVEAT THIS RESOLVES
========================
Day 351 retrained h_aggressive in the yin_lite feature space so Dart's
existing `compose38()` could serve it, and it lost too much:

    v2b  librosa.pyin  frame 2048 / hop 512   acted 0.8096  natural 0.6661
    v3   plain YIN     frame  512 / hop 256   acted 0.7063  natural 0.5918

and the write-up flagged its own limitation: **two things changed at once**
-- the pitch algorithm (pyin's HMM/Viterbi vs plain YIN) AND the analysis
frame, which also moves all 26 MFCC statistics. It concluded "the native
work is required" without isolating which change mattered.

There is direct evidence the HMM is NOT the culprit. m4's own report
records plain YIN vs librosa.pyin as **0.8336 vs 0.8445 -- the HMM is worth
0.011**. A 0.10 drop cannot come from a 0.011 component.

So this tests the other variable: **plain YIN at frame 2048 / hop 512**,
librosa's default framing, with the MFCCs also at 2048/512. If v4 recovers
toward v2b, the Dart change is a FRAME-SIZE PARAMETER in yin_pitch.dart --
`kFrameLength` 512 -> 2048, `kHopLength` 256 -> 512 -- and not a pyin
implementation. That turns Phase B from days of native work into a constant
and a re-verified golden fixture.

`yin_lite` hardcodes FRAME=512 / HOP=256 as module globals, so they are
rebound before use rather than the file being forked. tau_max is unaffected:
it derives from fmin (16000/65.41 = 245 samples), independent of frame
length -- 512 barely clears 2*tau_max=490, while 2048 is comfortable, which
is itself a reason the larger frame should give cleaner f0.

Corpora are Day 348's v2b set (ESD-free): CREMA-D, TESS, RAVDESS, SAVEE,
MELD. Labels are day90's: aggressive = angry/fearful/disgusted,
calm = neutral/calm/happy; sad and surprise dropped.
"""
from __future__ import annotations

import glob
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
VS = os.path.join(ROOT, r"ml_datasets\vocal_stress")
MELD = os.path.join(ROOT, r"ml_datasets\vocal_stress\DS_MELD\preprocessed_data")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
FRAME, HOP = 2048, 512          # librosa's defaults -- the variable under test
WORKERS = 6

RAV_POS, RAV_NEG = {"05", "06", "07"}, {"01", "02", "03"}
CRE_POS, CRE_NEG = {"ANG", "FEA", "DIS"}, {"NEU", "HAP"}
SAV_POS, SAV_NEG = {"a", "f", "d"}, {"n", "h"}
TES_POS, TES_NEG = {"angry", "fear", "disgust"}, {"neutral", "happy"}
MELD_POS = {"anger", "fear", "disgust"}
MELD_NEG = {"neutral", "joy"}


def features38(y, librosa):
    """The day90/day95 38-vector, but plain YIN at FRAME/HOP = 2048/512."""
    import yin_lite
    yin_lite.FRAME, yin_lite.HOP = FRAME, HOP     # rebind, do not fork
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    pitch = yin_lite.pitch_features(y)
    rms = librosa.feature.rms(y=y, frame_length=FRAME, hop_length=HOP)[0]
    shimmer = float(np.mean(np.abs(np.diff(rms)))) if len(rms) > 1 else 0.0
    ac = np.correlate(y, y, mode="full")
    ac = ac[len(ac) // 2:]
    hnr = float(np.clip(
        float(np.max(ac[1:min(len(ac), int(SR * 0.02))]) / (ac[0] + 1e-8)),
        0, 1))
    mf = librosa.feature.mfcc(y=y, sr=SR, n_mfcc=13, n_fft=FRAME,
                              hop_length=HOP)
    out = np.concatenate([
        pitch, [shimmer, hnr], mf.mean(axis=1), mf.std(axis=1),
        [float(rms.mean()), float(rms.std()), float(rms.max()),
         float(librosa.feature.zero_crossing_rate(
             y, frame_length=FRAME, hop_length=HOP)[0].mean()),
         float(librosa.feature.spectral_centroid(
             y=y, sr=SR, n_fft=FRAME, hop_length=HOP)[0].mean() / (SR / 2))],
    ]).astype(np.float32)
    return np.nan_to_num(out, nan=0.0, posinf=0.0, neginf=0.0)


def _one(item):
    import librosa
    path, lab, spk = item
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
        if len(y) < int(SR * 0.3):
            return None
        return features38(y.astype(np.float64), librosa), lab, spk
    except Exception:
        return None


def _one_meld(path):
    import librosa
    import re
    import torch
    try:
        d = torch.load(path, map_location="cpu", weights_only=False)
        emo = str(d.get("emotion", "")).lower()
        lab = 1 if emo in MELD_POS else (0 if emo in MELD_NEG else None)
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
        return features38(w, librosa), lab, "meld_" + (m.group(1) if m else "u")
    except Exception:
        return None


def collect_ravdess():
    out = []
    for p in glob.glob(os.path.join(VS, "DS01_RAVDESS", "Ravdess", "**",
                                    "*.wav"), recursive=True):
        q = os.path.basename(p).split(".")[0].split("-")
        if len(q) < 7:
            continue
        lab = 1 if q[2] in RAV_POS else (0 if q[2] in RAV_NEG else None)
        if lab is not None:
            out.append((p, lab, f"rav_{q[6]}"))
    return out


def collect_crema():
    out = []
    for p in glob.glob(os.path.join(VS, "DS01_RAVDESS", "Crema", "**",
                                    "*.wav"), recursive=True):
        q = os.path.basename(p).split(".")[0].split("_")
        if len(q) < 3:
            continue
        lab = 1 if q[2] in CRE_POS else (0 if q[2] in CRE_NEG else None)
        if lab is not None:
            out.append((p, lab, f"cre_{q[0]}"))
    return out


def collect_savee():
    out = []
    for p in glob.glob(os.path.join(VS, "DS01_RAVDESS", "Savee", "**",
                                    "*.wav"), recursive=True):
        b = os.path.basename(p).split(".")[0]
        if "_" not in b:
            continue
        spk, code = b.split("_", 1)
        if code.startswith("sa") or code.startswith("su"):
            continue
        lab = 1 if code[0] in SAV_POS else (0 if code[0] in SAV_NEG else None)
        if lab is not None:
            out.append((p, lab, f"sav_{spk}"))
    return out


def collect_tess():
    out = []
    for p in glob.glob(os.path.join(VS, "DS01_RAVDESS", "Tess", "**",
                                    "*.wav"), recursive=True):
        b = os.path.basename(p).split(".")[0].lower()
        emo = b.split("_")[-1]
        if emo == "ps":
            continue
        lab = 1 if emo in TES_POS else (0 if emo in TES_NEG else None)
        if lab is not None:
            out.append((p, lab, "tes_" + b.split("_")[0]))
    return out


def run(tag, items, fn=_one):
    cache = os.path.join(HERE, f"feat_{tag}.npz")
    if os.path.exists(cache):
        print(f"[{tag}] cached")
        return
    t0, F, L, S = time.time(), [], [], []
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for i, r in enumerate(ex.map(fn, items, chunksize=8)):
            if r is not None:
                F.append(r[0]); L.append(r[1]); S.append(r[2])
            if (i + 1) % 1000 == 0:
                print(f"  [{tag}] {i+1}/{len(items)} "
                      f"{time.time()-t0:.0f}s", flush=True)
    X = np.stack(F); y = np.asarray(L, np.int32); spk = np.asarray(S)
    np.savez_compressed(cache, X=X, y=y, spk=spk)
    print(f"[{tag}] -> {X.shape} pos={int(y.sum())} "
          f"groups={len(set(S))}  {time.time()-t0:.0f}s", flush=True)


def main():
    print(f"plain YIN at FRAME={FRAME} HOP={HOP} (librosa defaults)")
    for tag, coll in (("ravdess", collect_ravdess), ("savee", collect_savee),
                      ("tess", collect_tess), ("crema", collect_crema)):
        items = coll()
        print(f"[{tag}] {len(items)} clips")
        run(tag, items)
    meld_tr = sorted(glob.glob(os.path.join(MELD, "train", "*.pt")))
    print(f"[meld_train] {len(meld_tr)} files")
    run("meld_train", meld_tr, _one_meld)
    meld_ev = (sorted(glob.glob(os.path.join(MELD, "test", "*.pt")))
               + sorted(glob.glob(os.path.join(MELD, "dev", "*.pt"))))
    print(f"[meld_eval] {len(meld_ev)} files")
    run("meld_eval", meld_ev, _one_meld)
    print("\ndone")


if __name__ == "__main__":
    main()
