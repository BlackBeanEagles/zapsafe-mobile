"""Day 361 - is glass firing on 97.5% of non-events the MODEL or the
AGGREGATION?

`operating_point.py` scored each clip as max() over up to 6 sliding 3 s
windows, because that is what the shipped Dart rolling buffer does. But max
over 6 windows gives six independent chances to cross the threshold, so a
high false-positive rate is partly a property of the aggregation, not only
of the model. Reporting "fires on 97.5% of non-events" without separating
those two would overstate the case against the model -- and the point of
this whole exercise is to stop overstating things.

Three readings per model, same clips, same threshold:

    single   one 3 s window (the first)      -- the model alone
    mean     average score over windows      -- a calmer aggregator
    max      max over windows                -- what ships today

If `single` is also near-saturated, the model genuinely scores almost
everything high and the detector is broken. If `single` is sane and only
`max` saturates, the fix is the aggregation rule, which is cheap.

Also prints the score separation directly (positive vs negative medians),
because a model whose negatives sit at 0.79 has no threshold that works,
independent of how windows are combined.
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
    "glass": (os.path.join(ASSETS, "m_glass_breaking_v4.tflite"),
              "glass_break_detector.dart", "yg"),
    "gun": (os.path.join(ASSETS, "mg_gunshot_v2.tflite"),
            "gunshot_detector.dart", "yk"),
}


def dart_threshold(fname):
    src = io.open(os.path.join(SERVICES, fname), encoding="utf-8").read()
    return float(re.search(r"kDefaultThreshold\s*=\s*([0-9.]+)", src).group(1))


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
    from sklearn.metrics import roc_auc_score
    d = np.load(os.path.join(HERE, "audioset_fixture.npz"), allow_pickle=True)
    n = len(d["yg"])
    report = {}

    for task, (model, dart, ykey) in TASKS.items():
        thr = dart_threshold(dart)
        it = tf.lite.Interpreter(model_path=model)
        it.allocate_tensors()
        size = int(it.get_input_details()[0]["shape"][1])
        assert size == int(d["mels_%s" % task]), (
            "%s declares %d mels; fixture built %d"
            % (task, size, int(d["mels_%s" % task])))
        nwin = d["nwin_%s" % task].astype(int)
        off = np.concatenate([[0], np.cumsum(nwin)])
        y = d[ykey].astype(int)
        pw = run(model, d["win_%s" % task])
        agg = {
            "single": run(model, d["first_%s" % task]),
            "mean": np.array([pw[off[k]:off[k + 1]].mean()
                              for k in range(n)]),
            "max (SHIPPED path)": np.array([pw[off[k]:off[k + 1]].max()
                                            for k in range(n)]),
        }
        print("\n=== %s   threshold %.2f   %d mels %.1fs   %d positives of %d"
              % (task, thr, size, float(d["dur_%s" % task]), y.sum(), n))
        print("  %-20s %6s %6s %8s %8s %8s %8s"
              % ("aggregation", "AUC", "recall", "prec", "FPR",
                 "posMed", "negMed"))
        rows = {}
        for name, p in agg.items():
            f = p >= thr
            tp = int((f & (y == 1)).sum())
            fp = int((f & (y == 0)).sum())
            rows[name] = {
                "auc": round(float(roc_auc_score(y, p)), 4),
                "recall": round(tp / max(int(y.sum()), 1), 3),
                "precision": round(tp / max(tp + fp, 1), 3),
                "fpr": round(fp / max(int((y == 0).sum()), 1), 3),
                "pos_median": round(float(np.median(p[y == 1])), 3),
                "neg_median": round(float(np.median(p[y == 0])), 3)}
            r = rows[name]
            print("  %-20s %6.4f %6.3f %8.3f %8.3f %8.3f %8.3f"
                  % (name, r["auc"], r["recall"], r["precision"], r["fpr"],
                     r["pos_median"], r["neg_median"]))

        # Separation is the thing a threshold cannot fix.
        p = agg["max (SHIPPED path)"]
        sep = float(np.median(p[y == 1]) - np.median(p[y == 0]))
        best = max(
            ((t, (p >= t)) for t in np.arange(0.01, 1.0, 0.01)),
            key=lambda kv: (
                ((kv[1] & (y == 1)).sum() / max(int(y.sum()), 1))
                + (1 - (kv[1] & (y == 0)).sum()
                   / max(int((y == 0).sum()), 1)) - 1))
        bt, bf = best
        youden = ((bf & (y == 1)).sum() / max(int(y.sum()), 1)
                  + 1 - (bf & (y == 0)).sum() / max(int((y == 0).sum()), 1)
                  - 1)
        print("  median separation (pos - neg): %+.3f" % sep)
        print("  BEST achievable threshold on this corpus: %.2f  "
              "(Youden J = %.3f, recall %.3f, FPR %.3f)"
              % (bt, youden,
                 (bf & (y == 1)).sum() / max(int(y.sum()), 1),
                 (bf & (y == 0)).sum() / max(int((y == 0).sum()), 1)))
        report[task] = {"threshold": thr, "aggregations": rows,
                        "median_separation": round(sep, 4),
                        "best_threshold": round(float(bt), 2),
                        "best_youden_j": round(float(youden), 4)}

    json.dump(report,
              open(os.path.join(HERE, "aggregation_control.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
