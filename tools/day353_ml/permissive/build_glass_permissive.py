"""Day 359 - permissive glass detector: fixes the licence AND the data.

TWO PROBLEMS, ONE FIX
=====================
`m_glass_breaking_v3` carries UrbanSound8K (CC BY-NC 3.0), so the model
cannot ship commercially. Its own training report also says:

    train_pos 92   train_neg 1709   eval_real_pos 13   val_auc 0.9747
    chosen_threshold 0.8754   (picked on those 13 positives)
    gate, on real labelled data: AUC 0.782

Ninety-two positive examples, and a threshold chosen on thirteen. The
permissive FSD50K subset has **872 glass positives** -- nearly ten times as
many -- all CC0 or CC BY.

So this is not a licence-for-accuracy trade. It is more data and a cleaner
licence at the same time, which is why it is worth doing before the NC
models that have no permissive replacement.

FEATURES ARE COPIED EXACTLY from work/glass_retrain/train_glass.py:
16 kHz, 2.0 s, 96 mels, n_fft 2048, hop 512, fmax 8000, power_to_db(ref=max),
per-clip min-max, then **np.resize to 96x96**.

np.resize is NOT an image resize -- it flattens row-major and TILES when the
source runs out. That is a bug in spirit, but it is the bug the shipped model
and the Dart path were built around, so reproducing it is mandatory. Changing
it here would produce a model whose inputs the app cannot generate.
See assets/models/ and test/fixtures/np_resize_wrap_golden.json.

LICENCE OBLIGATION: CC BY requires attribution. A CC-BY-trained model obliges
the app to credit FSD50K contributors somewhere reachable. That is a real
product task, and it is the price of clearing NC -- which forbids commercial
use outright rather than merely requiring a credit line.
"""
from __future__ import annotations

import io
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
F = r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events\DS08_FSD50K"
DEV_AUDIO = os.path.join(F, "FSD50K.dev_audio")
EVAL_AUDIO = os.path.join(F, "FSD50K.eval_audio")

SR, DUR, N_MELS, N_FFT, HOP, FMAX, IMG = 16000, 2.0, 96, 2048, 512, 8000, 96
NEED = int(SR * DUR)
WORKERS = 6


def mel_img(y, librosa):
    """Verbatim from work/glass_retrain/train_glass.py::mel_img."""
    y = np.pad(y, (0, NEED - len(y))) if len(y) < NEED else y[:NEED]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=N_MELS,
                                         hop_length=HOP, n_fft=N_FFT,
                                         fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    nz = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    img = np.resize(nz, (IMG, IMG))      # WRAPS -- matches the shipped path
    return np.stack([img] * 3, axis=-1).astype(np.float16)


def _one(item):
    import librosa
    path, lab = item
    try:
        y, _ = librosa.load(path, sr=SR, mono=True)
        if len(y) < SR * 0.2:
            return None
        return mel_img(y, librosa), lab
    except Exception:
        return None


def read_list(p):
    with io.open(p, encoding="utf-8") as fh:
        return [x.strip() for x in fh if x.strip()]


def build(split, audio_dir):
    pos = read_list(os.path.join(HERE, "glass_%s_pos.txt" % split))
    neg = read_list(os.path.join(HERE, "glass_%s_neg.txt" % split))
    rng = np.random.RandomState(42)
    # cap negatives at 3x positives -- the shipped model used 1709 negatives
    # against 92 positives (18:1), which is part of why its threshold had to
    # sit at 0.8754 to control false positives
    neg = list(rng.permutation(neg)[:min(len(neg), 3 * len(pos))])
    items = ([(os.path.join(audio_dir, "%s.wav" % f), 1) for f in pos] +
             [(os.path.join(audio_dir, "%s.wav" % f), 0) for f in neg])
    items = [(p, l) for p, l in items if os.path.exists(p)]
    print("[%s] %d clips (%d pos, %d neg)"
          % (split, len(items), sum(l for _, l in items),
             sum(1 - l for _, l in items)), flush=True)
    X, y = [], []
    bad = 0
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        for k, r in enumerate(ex.map(_one, items, chunksize=8)):
            if r is None:
                bad += 1
                continue
            X.append(r[0])
            y.append(r[1])
            if (k + 1) % 500 == 0:
                print("  %d/%d  %ds" % (k + 1, len(items),
                                        int(time.time() - t0)), flush=True)
    X = np.stack(X)
    y = np.asarray(y, np.int64)
    print("[%s] built %s pos=%d dropped=%d" % (split, X.shape, y.sum(), bad))
    np.savez_compressed(os.path.join(HERE, "glass_%s_mel.npz" % split),
                        X=X, y=y)
    return X.shape


def main():
    if not os.path.isdir(DEV_AUDIO):
        print("dev audio missing at %s" % DEV_AUDIO)
        return
    build("dev", DEV_AUDIO)
    if os.path.isdir(EVAL_AUDIO):
        build("eval", EVAL_AUDIO)
    else:
        print("eval audio not extracted; dev split will be used for both "
              "train and held-out, split by clip")


if __name__ == "__main__":
    main()
