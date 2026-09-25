"""Day 356 - NaturalVoices -> 38-dim features. The last untested candidate.

WHAT THIS CORPUS ACTUALLY IS, STATED PLAINLY
============================================
Every row's `Document` is `MSP-PODCAST_*`. NaturalVoices is MSP-Podcast
audio, redistributed by the JHU/MSP-Lab collaboration. MSP-Podcast itself
requires a signed academic agreement with UT Dallas; this redistribution
declares NO licence. That is a worse position than the NC corpora already
in the gate, because it is unclear the redistribution was authorised.
Anything learned here is research-only until that is checked.

THE LABELS ARE MACHINE-GENERATED. The four emotion columns sum to ~1.0 per
row -- they are softmax outputs, and `Emotion` is their argmax. This is a
teacher model's predictions, not human annotation. EQ4You was also
pseudo-labelled and was rejected (seed replication 2/4 at full volume), so
this is being tested rather than assumed.

WHY IT IS STILL WORTH A TEST
============================
    298,227 rows, balanced   Neutral 78,155  Angry 76,503
                             Happy   74,825  Sad   68,744
    1,220 speakers, 4,666 episodes

It is the closest domain to a phone microphone of anything found: real
podcast conversation, 1,220 speakers, and the underlying audio is the
corpus every SER paper treats as the natural-speech gold standard.

SUBSAMPLED ON PURPOSE. EQ4You's volume sweep showed more data did not help
and the effect never left the noise band, so this takes a speaker-disjoint
sample rather than all 298k. If a 30k sample shows nothing, 298k will not
either, and the sample costs hours instead of days.

CONFIDENCE FILTER: only rows whose winning probability clears MIN_CONF are
kept. The labels are predictions, so the low-confidence ones are the
teacher's own uncertainty and adding them would train on its coin-flips.
"""
from __future__ import annotations

import csv
import io
import os
import sys
import time
import zipfile
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
ZIP = os.path.join(HERE, "Emotion_Balanced.zip")
CSVNAME = "selected_emotion_data_with_local_global_speaker.csv"
CLIPDIR = os.path.join(HERE, "clips")

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
WORKERS = 8
MIN_CONF = 0.50           # the teacher must actually be sure
PER_CLASS = 8000          # speaker-disjoint cap per emotion
SEED = 42

POS_HA = {"Angry"}                      # h_aggressive: anger vs calm
POS_M4 = {"Angry", "Sad"}               # m4: anger+sad vs calm
NEG = {"Neutral", "Happy"}


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
    path, emo, spk = item
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
        if len(y) < SR * 0.5:
            return None
        return (features38(y, librosa, 2048, 512),
                features38(y, librosa, 512, 256), emo, spk)
    except Exception:
        return None


def select():
    """Pick a confident, speaker-disjoint, class-capped sample."""
    z = zipfile.ZipFile(ZIP)
    raw = z.read(CSVNAME).decode("utf-8", "replace")
    rows = list(csv.DictReader(io.StringIO(raw)))
    print("  csv rows: %d" % len(rows))

    names = set(z.namelist())
    by_class = {k: [] for k in ("Angry", "Sad", "Neutral", "Happy")}
    dropped_conf = 0
    for r in rows:
        emo = r.get("Emotion")
        if emo not in by_class:
            continue
        try:
            conf = float(r.get(emo) or 0.0)
        except ValueError:
            continue
        if conf < MIN_CONF:
            dropped_conf += 1
            continue
        by_class[emo].append(r)
    print("  dropped for confidence < %.2f: %d" % (MIN_CONF, dropped_conf))
    for k, v in by_class.items():
        print("     %-8s confident: %d" % (k, len(v)))

    rng = np.random.RandomState(SEED)
    chosen = []
    for k, v in by_class.items():
        idx = rng.permutation(len(v))[:PER_CLASS]
        chosen += [v[i] for i in idx]
    print("  selected %d rows" % len(chosen))
    return z, names, chosen


def main():
    z, names, chosen = select()
    os.makedirs(CLIPDIR, exist_ok=True)

    # the flac path is not in the csv; build it from Document/Part Number
    items, missing = [], 0
    lookup = {}
    for n in names:
        if n.lower().endswith(".flac"):
            lookup[os.path.basename(n)] = n
    for r in chosen:
        base = "%s_%s.flac" % (r["Document"], r["Part Number"])
        inner = lookup.get(base)
        if inner is None:
            missing += 1
            continue
        p = os.path.join(CLIPDIR, base)
        if not os.path.exists(p):
            try:
                with open(p, "wb") as fh:
                    fh.write(z.read(inner))
            except Exception:
                missing += 1
                continue
        items.append((p, r["Emotion"], "nv_" + str(r["global_speakers"])))
    print("  extracted %d clips, missing %d" % (len(items), missing),
          flush=True)
    if not items:
        print("  NOTHING EXTRACTED -- the flac naming does not match "
              "Document_PartNumber; inspect the archive before rerunning.")
        return

    X2048, X512, emo, spk = [], [], [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, items, chunksize=8)):
            if r is None:
                bad += 1
                continue
            a, b, e, s = r
            X2048.append(a)
            X512.append(b)
            emo.append(e)
            spk.append(s)
            if (k + 1) % 2000 == 0:
                print("  %d/%d  %ds" % (k + 1, len(items),
                                        int(time.time() - t0)), flush=True)

    X2048 = np.vstack(X2048)
    X512 = np.vstack(X512)
    emo = np.array(emo)
    spk = np.array(spk)
    import collections
    print("\nbuilt %s  dropped %d" % (X2048.shape, bad))
    print("  labels:", dict(collections.Counter(emo.tolist())))
    print("  speakers:", len(set(spk.tolist())))

    keep_ha = np.array([e in (POS_HA | NEG) for e in emo])
    y_ha = np.array([1 if e in POS_HA else 0 for e in emo], np.int64)
    y_m4 = np.array([1 if e in POS_M4 else 0 for e in emo], np.int64)
    np.savez_compressed(os.path.join(HERE, "nv_yin2048.npz"),
                        X=X2048[keep_ha], y=y_ha[keep_ha],
                        spk=spk[keep_ha], emo=emo[keep_ha])
    np.savez_compressed(os.path.join(HERE, "nv_yin512.npz"),
                        X=X512, y=y_m4, spk=spk, emo=emo)
    print("written nv_yin2048.npz (h_aggressive) and nv_yin512.npz (m4)")


if __name__ == "__main__":
    main()
