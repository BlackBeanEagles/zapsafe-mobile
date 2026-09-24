"""Day 354 - CMU-MOSEI: natural English, the gap m4 and h_aggressive have.

WHY THIS CORPUS
===============
Both weak models are weak for one reason: their only natural English is
MELD, ~6-8k rows of scripted TV dialogue. Day 353 established that adding
ACTED English is not merely useless but can be harmful -- ESD's per-feature
direction agreement with conversational speech is r = -0.07 (English) and
-0.56 (Mandarin).

CMU-MOSEI is 23,453 segments of YouTube monologues from 1,000+ speakers,
annotated by humans for the six Ekman emotions at intensity 0-3. Nobody is
performing to a script: these are people talking to a camera about whatever
they came to talk about.

This is the `cairocode/cmu_mosei_wav_2` mirror, which is the subset that
ships ACTUAL AUDIO. The official CMU release distributes COVAREP features
instead, which are useless here -- the whole point is to run the same
yin_lite extractor the models were trained with.

    5,245 segments   median 5.28 s   92% >= 2 s
    anger 838   sad 1097   fear 416   disgust 562   happy 3055   neutral 991

LICENCE: the mirror declares none. Upstream CMU-MOSEI is distributed by the
CMU MultiComp Lab for research, and the audio is YouTube-sourced -- the same
posture as MELD and AudioSet, both already in the gate's provenance table.
It does NOT improve the licence position and is not claimed to.

LABELS: SINGLE, BY DOMINANCE
============================
MOSEI is multi-label with intensities, while every corpus these models were
trained on is single-label. Rather than invent a multi-label scheme, each
clip takes its ARGMAX emotion, and clips with all six at zero are neutral.
That mirrors MELD's exclusivity instead of quietly changing the task.

    m4 (vocal stress)    positive  anger, sad
                         negative  neutral, happy
    h_aggressive         positive  anger, fear, disgust
                         negative  neutral, happy
    (surprise dropped from both -- neither model was trained to place it)

GROUPING: by `video`, the YouTube id. MOSEI monologues are one speaker per
video, so this is a speaker proxy and the split must respect it.

WHETHER IT IS USED IS NOT DECIDED HERE. This script only builds features.
diagnose_mosei.py checks direction agreement, ab_mosei.py runs the paired
A/B against unchanged MELD rows, and confirm_seeds re-runs any hit at fresh
seeds -- which is what killed LEGOv2 after it looked significant.
"""
from __future__ import annotations

import io
import os
import sys
import time
import wave
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
RAW = os.path.join(HERE, "raw")
WAVDIR = os.path.join(HERE, "wav")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
# 16 broke the pool on this machine -- each worker JITs numba and
# allocates a soxr resampler, and MOSEI clips are 22 kHz and long.
WORKERS = 8
MIN_SEC = 1.5          # below this the 3 s pad dominates the features

EMO = ["happy", "sad", "anger", "surprise", "disgust", "fear"]
M4_POS = {"anger", "sad"}
M4_NEG = {"neutral", "happy"}
HA_POS = {"anger", "fear", "disgust"}
HA_NEG = {"neutral", "happy"}


def features38(y, librosa, fl, hl):
    """Identical in structure to featurise_yin2048.py and featurise_zh.py.

    yin_lite.FRAME/HOP are module globals and are rebound per call, which is
    safe only because each worker is a separate PROCESS. Do not use threads.
    """
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
    path, emo, vid = item
    try:
        w = wave.open(path)
        sr0, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
        sig = np.frombuffer(w.readframes(n), dtype=np.int16)
        w.close()
        if ch > 1:
            sig = sig.reshape(-1, ch).mean(axis=1)
        sig = sig.astype(np.float32) / 32768.0
        if sr0 != SR:
            sig = librosa.resample(sig, orig_sr=sr0, target_sr=SR)
        if len(sig) < SR * MIN_SEC:
            return None
        return (features38(sig, librosa, 2048, 512),
                features38(sig, librosa, 512, 256), emo, vid)
    except Exception:
        return None


def extract():
    """Parquet -> wav files on disk, so the pool pickles paths not blobs."""
    import pyarrow.parquet as pq
    os.makedirs(WAVDIR, exist_ok=True)
    items, skipped = [], 0
    for shard in sorted(os.listdir(RAW)):
        if not shard.endswith(".parquet"):
            continue
        f = pq.ParquetFile(os.path.join(RAW, shard))
        for rg in range(f.metadata.num_row_groups):
            t = f.read_row_group(rg, columns=["audio", "video"] + EMO)
            for d in t.to_pylist():
                vals = [float(d[e] or 0.0) for e in EMO]
                emo = "neutral" if max(vals) <= 0 else EMO[int(
                    np.argmax(vals))]
                if emo == "surprise":
                    skipped += 1
                    continue
                b = d["audio"]["bytes"]
                name = os.path.basename(d["audio"]["path"] or "")
                if not b or not name:
                    skipped += 1
                    continue
                p = os.path.join(WAVDIR, name)
                if not os.path.exists(p):
                    with open(p, "wb") as fh:
                        fh.write(b)
                items.append((p, emo, "mosei_%s" % d["video"]))
        print("  extracted through %s -> %d" % (shard, len(items)),
              flush=True)
    print("  skipped (surprise / unusable): %d" % skipped)
    return items


def main():
    items = extract()
    print("clips to featurise: %d" % len(items), flush=True)

    X2048, X512, emo, vid = [], [], [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, res in enumerate(ex.map(_one, items, chunksize=8)):
            if res is None:
                bad += 1
                continue
            a, b, e, v = res
            X2048.append(a)
            X512.append(b)
            emo.append(e)
            vid.append(v)
            if (k + 1) % 500 == 0:
                print("  %d/%d  %ds" % (k + 1, len(items),
                                        int(time.time() - t0)), flush=True)

    X2048 = np.vstack(X2048)
    X512 = np.vstack(X512)
    emo = np.array(emo)
    vid = np.array(vid)
    y_m4 = np.array([1 if e in M4_POS else 0 for e in emo], np.int64)
    y_ha = np.array([1 if e in HA_POS else 0 for e in emo], np.int64)
    keep_m4 = np.array([e in (M4_POS | M4_NEG) for e in emo])
    keep_ha = np.array([e in (HA_POS | HA_NEG) for e in emo])

    print("\nbuilt %s   dropped (too short / unreadable) %d"
          % (X2048.shape, bad))
    import collections
    print("  emotions:", dict(collections.Counter(emo.tolist())))
    print("  m4 rows %d  pos %d" % (int(keep_m4.sum()),
                                    int(y_m4[keep_m4].sum())))
    print("  ha rows %d  pos %d" % (int(keep_ha.sum()),
                                    int(y_ha[keep_ha].sum())))
    print("  speakers (videos): %d" % len(set(vid.tolist())))

    np.savez_compressed(os.path.join(HERE, "mosei_yin2048.npz"),
                        X=X2048[keep_ha], y=y_ha[keep_ha],
                        spk=vid[keep_ha], emo=emo[keep_ha])
    np.savez_compressed(os.path.join(HERE, "mosei_yin512.npz"),
                        X=X512[keep_m4], y=y_m4[keep_m4],
                        spk=vid[keep_m4], emo=emo[keep_m4])
    print("written mosei_yin2048.npz (h_aggressive) and "
          "mosei_yin512.npz (m4)")


if __name__ == "__main__":
    main()
