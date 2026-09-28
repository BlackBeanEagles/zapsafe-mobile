"""Day 365 - motion_fall_v2 off-corpus. The last untested detector.

WHY THIS ONE MATTERS MOST NOW
=============================
`motion_fall_v2` reads **AUC 0.999** on the gate and is the strongest model
in the project. That fixture is held-out **UniMiB-SHAR** -- the corpus it
trained on. It is the only detector never measured on a second corpus, and
every other one that was measured dropped 0.11-0.18:

    m3_violence   0.908 -> 0.725   (-0.183)
    glass         0.815 -> 0.688   (-0.127)
    gunshot       0.810 -> 0.701   (-0.109)

Two things make it urgent rather than merely tidy:

  1. Day 364D dropped scream from the DCS gate, so motion is now one of only
     TWO inputs, carrying weight 0.52 of a 0.66 threshold.
  2. Day 364C/D's "false alert" scenario is "ambient audio + a SUSTAINED
     fall". If motion_fall is right, a fall happened and alerting is
     arguably correct -- so that number is only a false-alarm rate if THIS
     model false-fires. Its real-world false-positive rate has never been
     measured.

THE TEST CORPUS, AND WHY THE UNITS ARE SAFE
===========================================
MobiFall v2.0 (Apache-2.0, Kaggle `sha0401/mobifall-dataset-v2-0`):
24 subjects, 630 accelerometer trials, 288 falls / 342 ADLs.

Its Readme states the format outright:

    timestamp(ns),x,y,z(m/s^2)
    "Acceleration force along the x y z axes (including gravity)."

which is an exact match for `motion_fall_v2_norm.json`:

    "units": "m/s^2 including gravity (Android TYPE_ACCELEROMETER)"

Verified empirically as well, not just read: magnitude median **9.72 m/s^2**,
i.e. gravity. That check is the whole reason this corpus was chosen over the
SisFall copy already on disk, which turned out to be a preprocessed
derivative at ~+-0.2 scale with 6 unlabelled channels and no stated
normalisation -- feeding it would have reproduced the `i_vehicle_crash`
failure exactly (trained in g, fed m/s^2, 8x out of distribution, AUC 0.5000
with nothing thrown).

MobiFall is also **phone-collected** (Samsung Galaxy S3 in a trouser
pocket), which is what the app actually sees, where UniMiB-SHAR is a
research harness.

RESAMPLING: MobiFall runs at ~90 Hz, the model wants 50 Hz and a 100-sample
(2 s) window. Windows are linearly interpolated onto a 50 Hz grid -- NOT
`np.resize`, which tiles, and not decimation, which aliases.

SCORING: per-trial score is max-over-windows, because a fall is an event
inside a 10 s trial. That is also what the shipped rolling buffer does.
The per-window distribution is reported separately, because Day 364 showed
max-over-N and per-window are different questions and confusing them
produced a retraction.

The ADL set includes **JOG and JUM** (jogging, jumping). Those are the hard
negatives for a fall detector and are broken out individually.
"""
from __future__ import annotations

import glob
import json
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
ASSETS = os.path.join(ROOT, "assets", "models")
MODEL = os.path.join(ASSETS, "motion_fall_v2.tflite")
NORM = os.path.join(ASSETS, "motion_fall_v2_norm.json")
MF = os.path.join(HERE, "mobifall", "MobiFall_Dataset_v2.0")
SHIPPED_THRESHOLD = 0.5          # MotionDetectorV2.kDefaultThreshold
WIN, RATE = 100, 50.0
HOP = 25                          # 0.5 s at 50 Hz


def load_trial(path):
    """(t_seconds, xyz) from a MobiFall text trial. Handles the @DATA marker
    and the # comment header."""
    rows = []
    for line in open(path):
        s = line.strip()
        if not s or s.startswith("#") or s.upper().startswith("@"):
            continue
        if "," not in s:
            continue
        try:
            v = [float(x) for x in s.split(",")]
        except ValueError:
            continue
        if len(v) >= 4:
            rows.append(v[:4])
    if len(rows) < 8:
        return None, None
    a = np.asarray(rows)
    return a[:, 0] / 1e9, a[:, 1:4]


def to_50hz(t, xyz):
    """Linear interpolation onto a uniform 50 Hz grid. np.resize would TILE
    and decimation would alias; both have bitten this project."""
    t = t - t[0]
    n = int(np.floor(t[-1] * RATE)) + 1
    if n < WIN:
        return None
    grid = np.arange(n) / RATE
    return np.stack([np.interp(grid, t, xyz[:, i]) for i in range(3)], axis=1)


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    nz = json.load(open(NORM, encoding="utf-8"))
    mu = np.asarray(nz["mean"], np.float32)
    sd = np.asarray(nz["std"], np.float32) + 1e-8
    assert int(nz["window"]) == WIN and abs(float(nz["rate_hz"]) - RATE) < 1e-6
    print("norm: units=%s  order=%s" % (nz["units"], nz["channel_order"]))

    it = tf.lite.Interpreter(model_path=MODEL)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    print("model input %s" % shape)

    files = sorted(glob.glob(os.path.join(MF, "sub*", "**", "*_acc_*.txt"),
                             recursive=True))
    print("acc trials found: %d" % len(files))

    rows, allwin = [], []
    mags = []
    for p in files:
        up = p.replace("\\", "/")
        is_fall = "/FALLS/" in up.upper()
        kind = up.split("/")[-2]
        subj = re.search(r"sub(\d+)", up).group(1)
        t, xyz = load_trial(p)
        if t is None:
            continue
        mags.append(float(np.median(np.linalg.norm(xyz, axis=1))))
        g = to_50hz(t, xyz)
        if g is None:
            continue
        scores = []
        for st in range(0, len(g) - WIN + 1, HOP):
            w = ((g[st:st + WIN] - mu) / sd).astype(np.float32)
            it.set_tensor(i0["index"], w.reshape(shape).astype(i0["dtype"]))
            it.invoke()
            v = it.get_tensor(o0["index"]).ravel()
            scores.append(float(v[-1] if v.size > 1 else v[0]))
        if not scores:
            continue
        rows.append({"file": os.path.basename(p), "subject": subj,
                     "kind": kind, "y": int(is_fall),
                     "max": max(scores), "mean": float(np.mean(scores)),
                     "nwin": len(scores)})
        allwin.extend([(s, int(is_fall)) for s in scores])

    print("\nUNITS SANITY: median |acc| across trials = %.2f m/s^2 "
          "(gravity ~9.81)" % float(np.median(mags)))

    y = np.array([r["y"] for r in rows])
    mx = np.array([r["max"] for r in rows])
    print("trials scored %d  falls %d  ADL %d  windows %d"
          % (len(rows), y.sum(), (1 - y).sum(), len(allwin)))

    auc_trial = float(roc_auc_score(y, mx))
    ws = np.array([a for a, _ in allwin])
    wy = np.array([b for _, b in allwin])
    auc_win = float(roc_auc_score(wy, ws))
    print("\n  AUC, per trial (max over windows) : %.4f" % auc_trial)
    print("  AUC, per window                   : %.4f" % auc_win)
    print("  gate figure on UniMiB-SHAR        : 0.999")
    print("  -> off-corpus drop (trial-level)  : %+.4f" % (auc_trial - 0.999))

    print("\n  score by activity (max over windows, median):")
    for k in sorted({r["kind"] for r in rows}):
        sub = [r for r in rows if r["kind"] == k]
        lab = "FALL" if sub[0]["y"] else "adl "
        fired = np.mean([r["max"] >= SHIPPED_THRESHOLD for r in sub])
        print("    %s %-4s n=%-3d median %.3f   fires@0.5 %5.1f%%"
              % (lab, k, len(sub),
                 np.median([r["max"] for r in sub]), 100 * fired))

    print("\n  at the shipped threshold %.2f (per trial, max over windows):"
          % SHIPPED_THRESHOLD)
    f = mx >= SHIPPED_THRESHOLD
    tp = int((f & (y == 1)).sum())
    fp = int((f & (y == 0)).sum())
    rec = tp / max(int(y.sum()), 1)
    fpr = fp / max(int((1 - y).sum()), 1)
    print("    recall %.3f   precision %.3f   FPR on ADLs %.3f"
          % (rec, tp / max(tp + fp, 1), fpr))

    print("\n  per-window FPR on ADLs (what the DCS gate sees each window):")
    adlw = ws[wy == 0]
    for t in (0.5, 0.7, 0.9):
        print("    >= %.1f : %5.2f%% of ADL windows" % (t, 100 * (adlw >= t).mean()))

    json.dump({"corpus": "MobiFall v2.0 (Apache-2.0), phone accelerometer",
               "units_median_mag": round(float(np.median(mags)), 3),
               "trials": len(rows), "falls": int(y.sum()),
               "auc_trial_maxwin": round(auc_trial, 4),
               "auc_per_window": round(auc_win, 4),
               "gate_auc_unimib": 0.999,
               "drop_trial": round(auc_trial - 0.999, 4),
               "shipped_threshold": SHIPPED_THRESHOLD,
               "recall": round(rec, 4), "fpr_adl_trial": round(fpr, 4),
               "per_window_adl_fpr": {
                   str(t): round(float((adlw >= t).mean()), 4)
                   for t in (0.5, 0.7, 0.9)},
               "by_activity": {
                   k: {"n": len([r for r in rows if r["kind"] == k]),
                       "is_fall": int([r for r in rows
                                       if r["kind"] == k][0]["y"]),
                       "median_max": round(float(np.median(
                           [r["max"] for r in rows if r["kind"] == k])), 4)}
                   for k in sorted({r["kind"] for r in rows})},
               "rows": rows},
              open(os.path.join(HERE, "motion_fall_xcorpus.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
