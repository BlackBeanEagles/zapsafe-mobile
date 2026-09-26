"""Day 361 - pick a threshold that survives BOTH corpora, or admit there
isn't one.

AudioSet says the two shipped thresholds are miscalibrated in opposite
directions:

    glass  @0.22   recall 0.847, fires on 56.6% of non-events
    gun    @0.70   recall 0.208, fires on  5.3% of non-events

The obvious move is to retune to AudioSet's best (glass 0.37, gun 0.45).
That would be the same mistake in a new corpus: the current numbers were
chosen on FSD50K and do not transfer, and a number chosen on 59 AudioSet
positives has no better claim. Day 359's glass threshold was already picked
once on 13 positives and had to be withdrawn.

So this sweeps the SAME thresholds on BOTH corpora and reports them side by
side. A threshold is only worth recommending if it is defensible on each.
Nothing is changed by this script -- it prints the evidence for a decision.

FSD50K eval is the gate's own fixture, the disjoint split both models were
scored on. AudioSet is the out-of-domain set built today. Preprocessing per
task comes from the training scripts: glass 2.0 s / 96 mels, gun 3.0 s /
128 mels.
"""
from __future__ import annotations

import io
import json
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
ASSETS = os.path.join(ROOT, "assets", "models")
SERVICES = os.path.join(ROOT, "lib", "data", "services")
EVALDIR = r"C:\Users\hridy\Desktop\zapsafe\work\fsd50k_eval"
SR, N_FFT, HOP, FMAX = 16000, 2048, 512, 8000

TASKS = {
    "glass": {"model": "m_glass_breaking_v4.tflite",
              "dart": "glass_break_detector.dart",
              "mels": 96, "dur": 2.0, "pos": "Glass", "y": "yg"},
    "gun": {"model": "mg_gunshot_v2.tflite",
            "dart": "gunshot_detector.dart",
            "mels": 128, "dur": 3.0, "pos": "Gunshot_and_gunfire",
            "y": "yk"},
}
GRID = [round(x, 2) for x in np.arange(0.05, 0.96, 0.05)]


def dart_threshold(fname):
    src = io.open(os.path.join(SERVICES, fname), encoding="utf-8").read()
    return float(re.search(r"kDefaultThreshold\s*=\s*([0-9.]+)", src).group(1))


def mel_img(y, size, need, librosa):
    y = np.pad(y, (0, need - len(y))) if len(y) < need else y[:need]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_mels=size,
                                         hop_length=HOP, n_fft=N_FFT,
                                         fmax=FMAX)
    db = librosa.power_to_db(mel, ref=np.max)
    rng = db.max() - db.min()
    nz = (db - db.min()) / (rng if rng > 1e-8 else 1.0)
    return np.resize(nz, (size, size)).astype(np.float32)


def load_fsd(task):
    """The gate's FSD50K eval fixture, at this task's own preprocessing."""
    import librosa
    cache = os.path.join(HERE, "fsd_%s.npz" % task)
    if os.path.exists(cache):
        d = np.load(cache)
        return d["X"].astype(np.float32), d["y"].astype(int)
    cfg = TASKS[task]
    need = int(SR * cfg["dur"])
    man = json.load(io.open(os.path.join(EVALDIR, "manifest.json"),
                            encoding="utf-8"))
    X, y = [], []
    for m in man:
        p = os.path.join(EVALDIR, "audio", m["fname"])
        if not os.path.exists(p) or os.path.getsize(p) == 0:
            continue
        try:
            w, _ = librosa.load(p, sr=SR, mono=True)
        except Exception:
            continue
        if len(w) < SR * 0.2:
            continue
        X.append(mel_img(w, cfg["mels"], need, librosa))
        y.append(1 if cfg["pos"] in m.get("labels", []) else 0)
    X = np.stack(X)
    y = np.asarray(y, np.int64)
    np.savez_compressed(cache, X=X.astype(np.float16), y=y)
    return X, y


def run(path, X):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=path)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    out = np.zeros(len(X))
    for k in range(len(X)):
        img = np.repeat(X[k].astype(np.float32)[..., None], 3, axis=-1)
        it.set_tensor(i0["index"], img[None].astype(i0["dtype"]))
        it.invoke()
        v = it.get_tensor(o0["index"]).ravel()
        out[k] = float(v[-1]) if v.size > 1 else float(v[0])
    return out


def stats(y, p, t):
    f = p >= t
    tp = int((f & (y == 1)).sum())
    fp = int((f & (y == 0)).sum())
    rec = tp / max(int(y.sum()), 1)
    fpr = fp / max(int((y == 0).sum()), 1)
    return rec, tp / max(tp + fp, 1), fpr, rec - fpr


def main():
    from sklearn.metrics import roc_auc_score
    d = np.load(os.path.join(HERE, "audioset_fixture.npz"), allow_pickle=True)
    report = {}

    for task, cfg in TASKS.items():
        model = os.path.join(ASSETS, cfg["model"])
        thr = dart_threshold(cfg["dart"])

        ya = d[cfg["y"]].astype(int)
        nwin = d["nwin_%s" % task].astype(int)
        off = np.concatenate([[0], np.cumsum(nwin)])
        pwin = run(model, d["win_%s" % task])
        pa = np.array([pwin[off[k]:off[k + 1]].max()
                       for k in range(len(ya))])

        Xf, yf = load_fsd(task)
        pf = run(model, Xf)

        print("\n=== %s  (%s)" % (task, cfg["model"]))
        print("  FSD50K eval  n=%d pos=%d  AUC %.4f"
              % (len(yf), int(yf.sum()), roc_auc_score(yf, pf)))
        print("  AudioSet     n=%d pos=%d  AUC %.4f"
              % (len(ya), int(ya.sum()), roc_auc_score(ya, pa)))
        print("  shipped threshold %.2f" % thr)
        print("       %-26s | %-26s" % ("FSD50K eval", "AudioSet"))
        print("   t    rec   prec    FPR      J | rec   prec    FPR      J")
        rows = []
        for t in GRID:
            a = stats(yf, pf, t)
            b = stats(ya, pa, t)
            mark = "  <- SHIPPED" if abs(t - thr) < 0.026 else ""
            print("  %.2f  %.3f %.3f  %.3f  %+.3f | %.3f %.3f  %.3f  %+.3f%s"
                  % (t, a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3], mark))
            rows.append({"t": t,
                         "fsd": {"recall": round(a[0], 3),
                                 "precision": round(a[1], 3),
                                 "fpr": round(a[2], 3), "J": round(a[3], 3)},
                         "audioset": {"recall": round(b[0], 3),
                                      "precision": round(b[1], 3),
                                      "fpr": round(b[2], 3),
                                      "J": round(b[3], 3)}})

        # A threshold worth recommending maximises the WORSE of the two
        # Youden J values -- it has to hold up on both corpora, not average
        # out. Averaging would let a strong in-domain number hide an
        # out-of-domain failure, which is the whole problem being measured.
        best = max(rows, key=lambda r: min(r["fsd"]["J"],
                                           r["audioset"]["J"]))
        cur = min(x for x in
                  (r for r in rows if abs(r["t"] - thr) < 0.026)) \
            if any(abs(r["t"] - thr) < 0.026 for r in rows) else None
        print("  best worst-case J: t=%.2f  (FSD J %+.3f, AudioSet J %+.3f)"
              % (best["t"], best["fsd"]["J"], best["audioset"]["J"]))
        report[task] = {"shipped_threshold": thr, "grid": rows,
                        "best_worst_case": best}
        if cur:
            print("  shipped t=%.2f    (FSD J %+.3f, AudioSet J %+.3f)"
                  % (thr, cur["fsd"]["J"], cur["audioset"]["J"]))

    json.dump(report,
              open(os.path.join(HERE, "threshold_both_corpora.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
