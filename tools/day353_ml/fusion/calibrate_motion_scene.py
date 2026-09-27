"""Day 363B part 2 - the other two fusion inputs, via the gate's own fixtures.

Part 1 measured `scream_classifier_v5` on AudioSet and REFUTED the
hypothesis it was testing. I expected the shipped weights [0.5, 0.3, 0.2]
to be inverted against reliability, with scream over-weighted because its
card is known to overstate it. Measured:

    scream on AudioSet   AUC 0.8600   LLR span 3.66 nats

Higher than its 0.828 gate figure, and the largest evidence span of the
three audio detectors. Its shipped weight of 0.50 against an implied 0.528
is very nearly right.

(The "~6% of real screams" finding is about RECALL AT THE SHIPPED THRESHOLD,
not ranking. A detector can rank well and still have a badly-placed
threshold. Those are different failures and conflating them was the error.)

But the fusion's three inputs are [scream, MOTION, SCENE], and part 1 only
measured audio detectors. The comparison table it printed was
scream/glass/gun -- not the fusion's actual inputs -- so it did not test the
claim at all for the two slots that matter.

This measures the remaining two through the gate's OWN fixture helpers, so
the inputs are exactly what the gate scores them on, and completes the
comparison honestly.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
ASSETS = os.path.join(ROOT, "assets", "models")
CURRENT = {"scream": 0.5, "motion": 0.3, "scene": 0.2}
SCREAM_PART1 = {"auc": 0.8600, "llr_span_nats": 3.6581}


def fit_llr(scores, y):
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    s = np.asarray(scores, float).reshape(-1, 1)
    y = np.asarray(y, int)
    lr = LogisticRegression(max_iter=2000).fit(s, y)
    a = float(lr.coef_[0][0])
    p = float(y.mean())
    prior = np.log(p / (1 - p)) if 0 < p < 1 else 0.0
    lo, hi = np.percentile(s.ravel(), [5, 95])
    return {"a": round(a, 4), "b": round(float(lr.intercept_[0]) - prior, 4),
            "auc": round(float(roc_auc_score(y, s.ravel())), 4),
            "llr_span_nats": round(float(abs(a) * (hi - lo)), 4),
            "pos": int(y.sum()), "n": int(len(y))}


def main():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import importlib
    gate = importlib.import_module("verify_shipped_models")
    import tensorflow as tf

    out = {"scream": dict(SCREAM_PART1, source="part 1, AudioSet")}

    for key, asset in (("motion", "motion_fall_v2.tflite"),
                       ("scene", "m3_violence_temporal_v1.tflite")):
        path = os.path.join(ASSETS, asset)
        it = tf.lite.Interpreter(model_path=path)
        it.allocate_tensors()
        det = it.get_input_details()
        got = gate.fixture_for(det, asset)
        if got is None:
            print("  %-8s NO FIXTURE from the gate -- cannot calibrate"
                  % key)
            out[key] = {"error": "no fixture"}
            continue
        X, y = got
        if y is None:
            print("  %-8s fixture has NO LABELS -- an AUC would be "
                  "meaningless, skipping" % key)
            out[key] = {"error": "unlabelled fixture"}
            continue

        # Apply the gate's normalisation if the model ships one.
        norm = os.path.join(ASSETS, asset.replace(".tflite", "_norm.json"))
        if os.path.exists(norm):
            nz = json.load(open(norm, encoding="utf-8"))
            mu = np.asarray(nz["mean"], np.float32)
            sd = np.asarray(nz["std"], np.float32) + 1e-8
            X = ((X - mu) / sd).astype(np.float32)

        i0, o0 = det[0], it.get_output_details()[0]
        shape = [int(v) for v in i0["shape"]]
        p = np.zeros(len(X))
        for k in range(len(X)):
            it.set_tensor(i0["index"],
                          X[k:k + 1].reshape(shape).astype(i0["dtype"]))
            it.invoke()
            v = it.get_tensor(o0["index"]).ravel()
            # multi-class heads: danger = 1 - P(the benign class)
            p[k] = float(v[-1]) if v.size > 1 else float(v[0])
        out[key] = fit_llr(p, np.asarray(y).astype(int))
        print("  %-8s %s" % (key, out[key]))

    print("\n=== the fusion's THREE actual inputs")
    print("  %-8s %8s %10s %12s %12s"
          % ("input", "AUC", "LLR span", "implied w", "shipped w"))
    spans = {k: v.get("llr_span_nats") for k, v in out.items()
             if isinstance(v, dict) and "llr_span_nats" in v}
    tot = sum(spans.values()) if spans else 0
    for k in ("scream", "motion", "scene"):
        v = out.get(k, {})
        if "llr_span_nats" not in v:
            print("  %-8s %8s %10s %12s %12.2f"
                  % (k, "-", "-", "UNMEASURED", CURRENT[k]))
            continue
        print("  %-8s %8.4f %10.3f %12.3f %12.2f"
              % (k, v["auc"], v["llr_span_nats"],
                 v["llr_span_nats"] / tot if tot else 0, CURRENT[k]))
    out["shipped_weights"] = CURRENT
    if len(spans) == 3:
        out["implied_weights"] = {k: round(spans[k] / tot, 4) for k in spans}
    json.dump(out, open(os.path.join(HERE, "fusion_three_inputs.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
