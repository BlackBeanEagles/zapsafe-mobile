"""Day 353 - LEGOv2 (CMU Let's Go): real angry English from real callers.

WHY THIS CORPUS
===============
m4 (0.648) and h_aggressive v4 (0.641) are both weak for the same reason:
their only natural English speech is MELD, ~6k rows of TV dialogue. Day 353
established that adding ACTED English is not a safe fix -- ESD's per-feature
direction agreement with natural speech is r = -0.07 (English) and -0.56
(Mandarin), so acted corpora can actively teach the wrong relationship.

LEGOv2 is the CMU Let's Go bus-information corpus: real members of the
public phoning a spoken dialogue system, annotated by Ulm University for
emotional state. Nobody in it is performing.

    neutral        3305
    slightlyAngry   693
    angry           137
    veryAngry       104
    friendly          4
    garbage         588   <- dropped, it is an annotation category for
                             unusable audio, not an emotion

THE CATCH, STATED UP FRONT
==========================
**It is 8 kHz telephone audio.** Resampling to 16 kHz does not put the
4-8 kHz band back; it interpolates. Spectral centroid and the upper MFCCs
will sit in a different place than they do for MELD or for a phone mic, and
`spectral_centroid_over_nyquist` in particular is computed against a nyquist
the source never had.

That is exactly the kind of difference that produced the ESD inversion, so
this script only BUILDS the features. Whether LEGOv2 may be used is decided
by `diagnose_lego.py` (direction agreement) and then by a paired A/B against
unchanged MELD test+dev rows -- not by the fact that the data exists.

LICENCE: CMU, "individual, education research purposes only", plus a Ulm
University licence on the annotations. Research-only, i.e. no better than
MELD and no worse. It does NOT improve the licence position; it is being
considered for capability alone.

BOTH FEATURE SPACES
===================
    yin2048  frame 2048 / hop 512  -> h_aggressive v4
    yin512   frame  512 / hop 256  -> m4 / m5 (yin_lite)
Built in one pass so the two can never drift apart on this corpus.

Parallelised over a process pool: yin_lite's YIN is a Python loop and the
upstream h_aggressive run measured ~2.6 s/clip single-threaded, so 4,243
clips in two feature spaces is ~6 hours serially. Each worker opens its own
handle on the zip rather than the archive being extracted to disk.

IMPORTANT: yin_lite.FRAME/HOP are MODULE GLOBALS that features38() rebinds.
In a pool that is safe only because each worker is a separate process and
each call sets them immediately before use. Do not switch this to threads.
"""
from __future__ import annotations

import csv
import io
import os
import sys
import wave
import time
import zipfile
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
sys.path.insert(0, os.path.join(ROOT, "work", "yin_lite"))
ZIP = r"D:\zapsafe\LEGOv2.zip"

SR, CLIP = 16000, 3.0
NEED = int(SR * CLIP)
COL_AUDIO, COL_EMO = 54, 55
COL_CALL = 0
WORKERS = 16

POS = {"angry", "veryAngry"}
POS_WIDE = {"angry", "veryAngry", "slightlyAngry"}
NEG = {"neutral", "friendly"}


def features38(y, librosa, fl, hl):
    """The same 38-dim layout both models use; only fl/hl differ.

    Verbatim in structure from work/m5_zh_38/featurise_zh.py and
    work/h_aggressive_v4/featurise_yin2048.py, which are themselves the
    same function at two frame sizes.
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
    cen = librosa.feature.spectral_centroid(y=y, sr=SR, n_fft=fl,
                                            hop_length=hl)[0]
    zcr = librosa.feature.zero_crossing_rate(y, frame_length=fl,
                                             hop_length=hl)[0]
    out = np.concatenate([
        pitch, [shimmer, hnr], mf.mean(axis=1), mf.std(axis=1),
        [float(rms.mean()), float(rms.std()), float(rms.max()),
         float(zcr.mean()), float(cen.mean()) / (SR / 2.0)],
    ]).astype(np.float32)
    # the two upstream extractors both end with this; omitting it would
    # make LEGO rows differ from MELD rows for reasons unrelated to speech
    return np.nan_to_num(out, nan=0.0, posinf=0.0, neginf=0.0)


_Z = None


def _zip():
    """One zipfile handle per worker process, opened lazily."""
    global _Z
    if _Z is None:
        _Z = zipfile.ZipFile(ZIP)
    return _Z


def _one(item):
    """(zip_path, emo, call) -> (X2048, X512, emo, call) or None."""
    import librosa
    path, emo, call = item
    try:
        z = _zip()
        w = wave.open(io.BytesIO(z.read(path)))
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
        sr0 = w.getframerate()
        sig = pcm.astype(np.float32) / 32768.0
        if sr0 != SR:
            sig = librosa.resample(sig, orig_sr=sr0, target_sr=SR)
        if len(sig) < SR * 0.3:
            return None
        return (features38(sig, librosa, 2048, 512),
                features38(sig, librosa, 512, 256), emo, call)
    except Exception:
        return None


def main():
    z = zipfile.ZipFile(ZIP)
    names = set(z.namelist())
    raw = z.read("LEGOv2/corpus/csv/interactions.csv").decode("utf-8",
                                                              "replace")
    rows = [r for r in csv.reader(io.StringIO(raw), delimiter=";",
                                  quotechar='"') if len(r) == 60]
    keep = [r for r in rows
            if r[COL_EMO] in (POS_WIDE | NEG) and r[COL_AUDIO].strip()]
    print("labelled rows with an audio path: %d" % len(keep))

    items = []
    for r in keep:
        p = "LEGOv2/audio/" + r[COL_AUDIO].strip()
        if p in names:
            items.append((p, r[COL_EMO], "lego_" + r[COL_CALL].strip()))
    print("resolvable audio paths: %d" % len(items), flush=True)

    X2048, X512, yn, yw, call, emo = [], [], [], [], [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, res in enumerate(ex.map(_one, items, chunksize=8)):
            if res is None:
                bad += 1
                continue
            a, b, e, c = res
            X2048.append(a)
            X512.append(b)
            emo.append(e)
            yn.append(1 if e in POS else 0)
            yw.append(1 if e in POS_WIDE else 0)
            call.append(c)
            if (k + 1) % 500 == 0:
                print("  %d/%d  %ds" % (k + 1, len(items),
                                        int(time.time() - t0)), flush=True)

    X2048 = np.vstack(X2048)
    X512 = np.vstack(X512)
    yn = np.array(yn, np.int64)
    yw = np.array(yw, np.int64)
    call = np.array(call)
    emo = np.array(emo)
    print("built %s  skipped %d" % (X2048.shape, bad))
    print("  strict positives (angry+veryAngry) %d" % int(yn.sum()))
    print("  wide  positives (+slightlyAngry)   %d" % int(yw.sum()))
    print("  calls (speaker proxy) %d" % len(set(call.tolist())))

    np.savez_compressed(os.path.join(HERE, "lego_yin2048.npz"),
                        X=X2048, y=yw, y_strict=yn, spk=call, emo=emo)
    np.savez_compressed(os.path.join(HERE, "lego_yin512.npz"),
                        X=X512, y=yw, y_strict=yn, spk=call, emo=emo)
    print("written lego_yin2048.npz and lego_yin512.npz")


if __name__ == "__main__":
    main()
