"""Day 364B - m3_violence off-corpus: the project's largest unexamined gap.

WHY THIS ONE MATTERS
====================
`m3_violence_temporal_v1` reads **AUC 0.908** on the gate and is marked
"ok". That fixture is held-out **RWF-2000** -- the corpus it trained on.
Running it over XD-Violence for the fusion work gave **0.725**, a drop of
0.183, the largest in the project. It was found as a side effect and has
never been measured deliberately.

This is a fairer cross-corpus test than the audio ones. RWF-2000 and
XD-Violence both carry *violence* labels, so the construct matches; what
changes is the domain (RWF is real-world fight footage, XD-Violence is
movies, CCTV and web video). Glass/gunshot's AudioSet check had to worry
about weak labels meaning something slightly different.

WHAT IS MEASURED
================
  1. AUC on each corpus with a bootstrap CI, so "0.908 vs 0.725" gets an
     interval instead of two bare numbers.
  2. The shipped operating point. `ViolenceBurstDetector.kDefaultThreshold`
     is 0.80, chosen on RWF. Day 361 found both audio thresholds were
     miscalibrated off-corpus in opposite directions; this asks the same
     question of the scene detector.
  3. A threshold swept on BOTH corpora, scored by the WORSE of the two
     Youden J values -- the rule fixed before looking that produced the
     glass and gunshot recalibrations.

The two corpora are scored independently and never pooled: pooling would
let the larger one set the operating point for both.

NOTHING IS RETRAINED. This measures the shipped asset.
"""
from __future__ import annotations

import io
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
ASSETS = os.path.join(ROOT, "assets", "models")
MODEL = os.path.join(ASSETS, "m3_violence_temporal_v1.tflite")
SERVICES = os.path.join(ROOT, "lib", "data", "services")
B = 2000
GRID = [round(x, 2) for x in np.arange(0.05, 0.96, 0.05)]


def dart_threshold():
    p = os.path.join(SERVICES, "violence_burst_detector.dart")
    src = io.open(p, encoding="utf-8").read()
    m = re.search(r"kDefaultThreshold\s*=\s*([0-9.]+)", src)
    return float(m.group(1)) if m else None


def boot(y, p, idx):
    from sklearn.metrics import roc_auc_score
    v = []
    for i in idx:
        if y[i].min() == y[i].max():
            continue
        v.append(roc_auc_score(y[i], p[i]))
    v = np.asarray(v)
    return float(np.percentile(v, 2.5)), float(np.percentile(v, 97.5))


def stats(y, p, t):
    f = p >= t
    tp = int((f & (y == 1)).sum())
    fp = int((f & (y == 0)).sum())
    rec = tp / max(int(y.sum()), 1)
    fpr = fp / max(int((y == 0).sum()), 1)
    return rec, tp / max(tp + fp, 1), fpr, rec - fpr


def main():
    from sklearn.metrics import roc_auc_score
    import tensorflow as tf

    # ---- corpus A: the gate's own RWF fixture (in-corpus)
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import importlib
    gate = importlib.import_module("verify_shipped_models")
    it = tf.lite.Interpreter(model_path=MODEL)
    it.allocate_tensors()
    det = it.get_input_details()
    got = gate.fixture_for(det, "m3_violence_temporal_v1.tflite")
    if got is None or got[1] is None:
        raise SystemExit("no labelled RWF fixture from the gate")
    Xr, yr = got[0], np.asarray(got[1]).astype(int)
    i0, o0 = det[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    pr = np.zeros(len(Xr))
    for k in range(len(Xr)):
        it.set_tensor(i0["index"], Xr[k:k + 1].reshape(shape).astype(
            i0["dtype"]))
        it.invoke()
        v = it.get_tensor(o0["index"]).ravel()
        pr[k] = float(v[-1] if v.size > 1 else v[0])

    # ---- corpus B: XD-Violence, already scored during the fusion work
    rows = json.load(open(os.path.join(HERE, "xd_fusion_rows.json"),
                          encoding="utf-8"))
    px = np.array([r["scene"] for r in rows], float)
    yx = np.array([r["y"] for r in rows], int)

    rng = np.random.RandomState(42)
    ir = [rng.randint(0, len(yr), len(yr)) for _ in range(B)]
    ix = [rng.randint(0, len(yx), len(yx)) for _ in range(B)]
    a_r, a_x = roc_auc_score(yr, pr), roc_auc_score(yx, px)
    lo_r, hi_r = boot(yr, pr, ir)
    lo_x, hi_x = boot(yx, px, ix)

    print("m3_violence_temporal_v1")
    print("  RWF-2000  (IN-corpus, the gate's fixture) n=%-4d pos=%-4d "
          "AUC %.4f [%.3f, %.3f]" % (len(yr), yr.sum(), a_r, lo_r, hi_r))
    print("  XD-Violence (OUT of corpus)               n=%-4d pos=%-4d "
          "AUC %.4f [%.3f, %.3f]" % (len(yx), yx.sum(), a_x, lo_x, hi_x))
    print("  drop %.4f   intervals overlap: %s"
          % (a_r - a_x, "YES" if hi_x >= lo_r else "NO"))

    thr = dart_threshold()
    print("\n  shipped threshold: %s" % thr)
    print("       %-26s | %-26s" % ("RWF-2000 (in-corpus)",
                                    "XD-Violence (out)"))
    print("   t    rec   prec    FPR      J | rec   prec    FPR      J")
    grid = []
    for t in GRID:
        a = stats(yr, pr, t)
        b = stats(yx, px, t)
        mark = "  <- SHIPPED" if thr and abs(t - thr) < 0.026 else ""
        print("  %.2f  %.3f %.3f  %.3f  %+.3f | %.3f %.3f  %.3f  %+.3f%s"
              % (t, a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3], mark))
        grid.append({"t": t,
                     "rwf": {"recall": round(a[0], 3),
                             "precision": round(a[1], 3),
                             "fpr": round(a[2], 3), "J": round(a[3], 3)},
                     "xd": {"recall": round(b[0], 3),
                            "precision": round(b[1], 3),
                            "fpr": round(b[2], 3), "J": round(b[3], 3)}})

    best = max(grid, key=lambda r: min(r["rwf"]["J"], r["xd"]["J"]))
    cur = next((r for r in grid if thr and abs(r["t"] - thr) < 0.026), None)
    print("\n  best WORST-CASE J: t=%.2f  (RWF %+.3f, XD %+.3f)"
          % (best["t"], best["rwf"]["J"], best["xd"]["J"]))
    if cur:
        print("  shipped t=%.2f      (RWF %+.3f, XD %+.3f)"
              % (cur["t"], cur["rwf"]["J"], cur["xd"]["J"]))
        better = (min(best["rwf"]["J"], best["xd"]["J"]) >
                  min(cur["rwf"]["J"], cur["xd"]["J"]))
        print("  -> %s" % ("a better threshold exists on BOTH corpora"
                           if better else
                           "the shipped threshold is already best worst-case"))

    json.dump({"rwf": {"n": int(len(yr)), "pos": int(yr.sum()),
                       "auc": round(float(a_r), 4),
                       "ci95": [round(lo_r, 4), round(hi_r, 4)]},
               "xd": {"n": int(len(yx)), "pos": int(yx.sum()),
                      "auc": round(float(a_x), 4),
                      "ci95": [round(lo_x, 4), round(hi_x, 4)]},
               "drop": round(float(a_r - a_x), 4),
               "intervals_overlap": bool(hi_x >= lo_r),
               "shipped_threshold": thr,
               "best_worst_case": best, "shipped_row": cur,
               "grid": grid,
               "note": ("RWF is the corpus m3 trained on; the gate scores it "
                        "there. Both corpora carry violence labels, so the "
                        "construct matches and only the domain differs. "
                        "Nothing retrained.")},
              open(os.path.join(HERE, "m3_crosscorpus.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
