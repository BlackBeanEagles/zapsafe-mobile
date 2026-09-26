"""Day 361 - what do the SHIPPED thresholds actually do on a corpus the
models have never seen?

AUC is a ranking measure. It says nothing about whether the constant baked
into the Dart detector fires. That distinction has already cost this project
twice:

  * `scream_classifier_v5` records 0.95 recall on its card and fires on ~6%
    of real AudioSet screams.
  * `h_aggressive` v5 kept v4's 0.45 threshold through a recipe change and
    its recall collapsed 0.664 -> 0.057. Caught only because it was
    re-measured rather than assumed.

So the cross-corpus AUCs (glass 0.671, gunshot 0.701) are not the deployment
question. This is: at the number the app actually ships, on real AudioSet
events, what fraction of true events fire, and how often does it fire on
something else?

Thresholds are read from the Dart source rather than retyped, so this cannot
silently drift from what the app ships.
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

TASKS = {
    "glass": {"model": os.path.join(ASSETS, "m_glass_breaking_v4.tflite"),
              "dart": "glass_break_detector.dart", "y": "yg"},
    "gun": {"model": os.path.join(ASSETS, "mg_gunshot_v2.tflite"),
            "dart": "gunshot_detector.dart", "y": "yk"},
}


def dart_threshold(fname):
    """Pull kDefaultThreshold out of the shipped Dart detector."""
    p = os.path.join(SERVICES, fname)
    if not os.path.exists(p):
        return None, "%s not found" % fname
    src = io.open(p, encoding="utf-8").read()
    m = re.search(r"kDefaultThreshold\s*=\s*([0-9.]+)", src)
    if not m:
        return None, "kDefaultThreshold not found in %s" % fname
    return float(m.group(1)), p


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


def main():
    import tensorflow as tf
    d = np.load(os.path.join(HERE, "audioset_fixture.npz"), allow_pickle=True)
    n = len(d["yg"])
    report = {}

    for task, cfg in TASKS.items():
        thr, where = dart_threshold(cfg["dart"])
        it = tf.lite.Interpreter(model_path=cfg["model"])
        it.allocate_tensors()
        size = int(it.get_input_details()[0]["shape"][1])
        assert size == int(d["mels_%s" % task]), (
            "%s declares %d mels; fixture built %d"
            % (task, size, int(d["mels_%s" % task])))
        nwin = d["nwin_%s" % task].astype(int)
        off = np.concatenate([[0], np.cumsum(nwin)])
        y = d[cfg["y"]].astype(int)
        pw = run(cfg["model"], d["win_%s" % task])
        p = np.array([pw[off[k]:off[k + 1]].max() for k in range(n)])

        print("\n=== %s  (%s, %d mels, %.1fs, %d positives of %d)"
              % (task, os.path.basename(cfg["model"]), size,
                 float(d["dur_%s" % task]), y.sum(), n))
        if thr is None:
            print("  !! could not read threshold: %s" % where)
            continue
        print("  shipped threshold %.2f  (from %s)"
              % (thr, os.path.basename(where)))

        fired = p >= thr
        tp = int((fired & (y == 1)).sum())
        fp = int((fired & (y == 0)).sum())
        rec = tp / max(int(y.sum()), 1)
        prec = tp / max(tp + fp, 1)
        fpr = fp / max(int((y == 0).sum()), 1)
        print("  AT THE SHIPPED THRESHOLD:")
        print("    recall     %.3f  (%d of %d real events fire)"
              % (rec, tp, int(y.sum())))
        print("    precision  %.3f  (%d of %d firings are real)"
              % (prec, tp, tp + fp))
        print("    fires on   %.3f of non-events (%d of %d)"
              % (fpr, fp, int((y == 0).sum())))

        print("  score distribution: pos median %.3f | neg median %.3f | "
              "neg p99 %.3f"
              % (np.median(p[y == 1]), np.median(p[y == 0]),
                 np.percentile(p[y == 0], 99)))

        print("  what other thresholds would give:")
        rows = []
        for t in (0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90):
            f = p >= t
            a = int((f & (y == 1)).sum())
            b = int((f & (y == 0)).sum())
            rows.append({"t": t, "recall": round(a / max(int(y.sum()), 1), 3),
                         "precision": round(a / max(a + b, 1), 3),
                         "fires_pct": round(100 * f.mean(), 1)})
            print("    t=%.2f  recall %.3f  precision %.3f  fires on %.1f%% "
                  "of all clips" % (t, rows[-1]["recall"],
                                    rows[-1]["precision"],
                                    rows[-1]["fires_pct"]))
        report[task] = {"threshold": thr, "mels": size,
                        "recall": round(rec, 4), "precision": round(prec, 4),
                        "fpr": round(fpr, 4), "positives": int(y.sum()),
                        "curve": rows}

    json.dump(report, open(os.path.join(HERE, "operating_point.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
