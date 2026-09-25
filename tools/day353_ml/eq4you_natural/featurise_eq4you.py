"""Day 355 - EQ4You tar -> 38-dim features in both model spaces.

Streams a webdataset-style tar. Each sample is TWO entries sharing a name:
a large one (the mp3) and a ~160-byte one (the caption, also suffixed .mp3
by a packaging quirk). They arrive adjacently, so they are paired by name.

LABELS come from scan_captions.py's strict mapping -- core anger words only,
and a clip is dropped unless exactly one affect family is present. The
captions are machine-generated, so a loose mapping on top would compound
noise that is already there.

BALANCED ON PURPOSE: the negative class outnumbers anger ~12:1 in this
corpus. Feeding that in raw would let a model score well by never firing.
Negatives are subsampled to a fixed ratio of the positives, chosen with a
fixed seed so the set is reproducible.

Builds BOTH feature spaces in one pass so they can never drift apart:
    yin2048  frame 2048 / hop 512  -> h_aggressive v4
    yin512   frame  512 / hop 256  -> m4

SPEAKER GROUPING: the file prefix (AUD0000000882 / POD0000009365) is the
source recording id. Segments from one recording share a speaker, so the id
is carried through as the group key -- a random split over segments would
leak the same voice across train and test.

LICENCE: Apache-2.0. The only permissively-licensed audio corpus found in
this entire search; everything shipped today is NC or research-only.
"""
from __future__ import annotations

import io
import os
import re
import sys
import tarfile
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
WAVDIR = os.path.join(HERE, "clips")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
WORKERS = 8
NEG_RATIO = 1.5          # negatives kept per positive
SEED = 42


def boundary(words):
    return re.compile("(?<![a-z])(" + "|".join(words) + ")(?![a-z])")


ANGER = boundary(["angry", "anger", "furious", "fury", "irate", "enraged",
                  "rage", "raging", "outraged", "indignant", "hostile",
                  "aggressive", "seething", "livid", "wrathful"])
SAD = boundary(["sad", "sadness", "sorrow", "sorrowful", "grief", "despair",
                "despairing", "melancholy", "dejected", "depressed",
                "miserable", "unhappy", "anguish", "heartbroken", "mournful"])
CALM = boundary(["calm", "calmness", "serene", "serenity", "relaxed",
                 "tranquil", "peaceful", "composed", "poised", "content",
                 "contentment", "neutral", "determined", "determination",
                 "focused", "concentration"])
HAPPY = boundary(["happy", "happiness", "joy", "joyful", "cheerful",
                  "delighted", "pleased", "excited", "excitement",
                  "enthusiastic", "enthusiasm", "amused", "amusement",
                  "satisfied", "satisfaction", "elated", "upbeat"])


def label_of(txt):
    t = txt.lower()
    a, s = bool(ANGER.search(t)), bool(SAD.search(t))
    c, h = bool(CALM.search(t)), bool(HAPPY.search(t))
    if a and not (c or h or s):
        return "anger"
    if s and not (c or h or a):
        return "sad"
    if (c or h) and not (a or s):
        return "calm"
    return None


def features38(y, librosa, fl, hl):
    import yin_lite
    yin_lite.FRAME, yin_lite.HOP = fl, hl
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
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


def _one(item):
    import librosa
    path, lab, grp = item
    try:
        y, sr0 = librosa.load(path, sr=SR, mono=True)
        if len(y) < SR * 0.5:
            return None
        return (features38(y, librosa, 2048, 512),
                features38(y, librosa, 512, 256), lab, grp)
    except Exception:
        return None


def harvest(tar_path):
    """Pair audio with caption, label, write the kept clips to disk."""
    os.makedirs(WAVDIR, exist_ok=True)
    t = tarfile.open(tar_path, "r|")
    pending = {}
    buckets = {"anger": [], "sad": [], "calm": []}
    for m in t:
        if not m.isfile():
            continue
        data = t.extractfile(m).read()
        if m.size < 2000:                      # caption
            lab = label_of(data.decode("utf-8", "replace"))
            audio = pending.pop(m.name, None)
            if lab and audio:
                buckets[lab].append((m.name, audio))
            continue
        pending[m.name] = data                 # audio, caption follows
        if len(pending) > 64:                  # bounded, order is adjacent
            pending.pop(next(iter(pending)))
    t.close()

    rng = np.random.RandomState(SEED)
    pos = buckets["anger"] + buckets["sad"]
    keep_neg = min(len(buckets["calm"]),
                   int(len(pos) * NEG_RATIO))
    idx = rng.permutation(len(buckets["calm"]))[:keep_neg]
    chosen = ([(n, b, "anger") for n, b in buckets["anger"]]
              + [(n, b, "sad") for n, b in buckets["sad"]]
              + [(buckets["calm"][i][0], buckets["calm"][i][1], "calm")
                 for i in idx])
    print("  harvested anger=%d sad=%d calm(kept)=%d of %d"
          % (len(buckets["anger"]), len(buckets["sad"]), keep_neg,
             len(buckets["calm"])), flush=True)

    items = []
    for name, blob, lab in chosen:
        p = os.path.join(WAVDIR, name)
        if not os.path.exists(p):
            with open(p, "wb") as fh:
                fh.write(blob)
        grp = name.split("_")[0]              # source recording id
        items.append((p, lab, grp))
    return items


def main():
    tars = sys.argv[1:]
    items = []
    for tp in tars:
        print("harvesting %s" % os.path.basename(tp), flush=True)
        items += harvest(tp)
    print("total clips to featurise: %d" % len(items), flush=True)

    X2048, X512, labs, grps = [], [], [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, items, chunksize=8)):
            if r is None:
                bad += 1
                continue
            a, b, lab, g = r
            X2048.append(a)
            X512.append(b)
            labs.append(lab)
            grps.append(g)
            if (k + 1) % 1000 == 0:
                print("  %d/%d  %ds" % (k + 1, len(items),
                                        int(time.time() - t0)), flush=True)

    X2048 = np.vstack(X2048)
    X512 = np.vstack(X512)
    labs = np.array(labs)
    grps = np.array(grps)
    import collections
    print("\nbuilt %s  dropped %d" % (X2048.shape, bad))
    print("  labels:", dict(collections.Counter(labs.tolist())))
    print("  groups (source recordings):", len(set(grps.tolist())))

    y_ha = np.array([1 if l == "anger" else 0 for l in labs], np.int64)
    keep_ha = labs != "sad"                    # h_aggressive: anger vs calm
    y_m4 = np.array([1 if l in ("anger", "sad") else 0 for l in labs],
                    np.int64)
    np.savez_compressed(os.path.join(HERE, "eq4you_yin2048.npz"),
                        X=X2048[keep_ha], y=y_ha[keep_ha],
                        spk=grps[keep_ha], emo=labs[keep_ha])
    np.savez_compressed(os.path.join(HERE, "eq4you_yin512.npz"),
                        X=X512, y=y_m4, spk=grps, emo=labs)
    print("written eq4you_yin2048.npz (h_aggressive) and "
          "eq4you_yin512.npz (m4)")


if __name__ == "__main__":
    main()
