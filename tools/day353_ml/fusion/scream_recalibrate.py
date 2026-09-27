"""Day 364 - give the scream detector back its dynamic range.

THE PROBLEM, from Day 363D
==========================
`scream_classifier_v5` on 200 NON-violent movie/web clips:

    > 0.50 : 89.0%      median 0.898      p90 0.987

It is not discriminating on ambient media audio; it is nearly always on. In
the DCS fusion that matters more than it sounds, because the fusion consumes
the RAW SCORE in a weighted sum:

    ambient media audio   0.898  ->  0.5 * 0.898 = 0.449 of a 0.75 threshold
    violent clip          0.961  ->  0.5 * 0.961 = 0.481

A 0.032 difference in contribution between "a television is on" and "a
violent incident". The detector's evidence is real but compressed into the
top 10% of its output range, where the fusion cannot use it.

WHAT RECALIBRATION CAN AND CANNOT DO -- stated before running
=============================================================
A monotone map **cannot improve separation**. AUC is invariant under it, and
this script ASSERTS that rather than hoping. If ambient and screams
genuinely overlap, no calibration fixes it and the honest answer is that the
detector is unusable in that domain.

What it CAN do is put the decision region where the data actually lives.
0.898 and 0.961 are far apart in rank terms and adjacent in score terms.
Isotonic regression re-spaces the output so that distance becomes usable.

FITTED ON TWO CORPORA, CHECKED ACROSS THEM
==========================================
    FSD50K eval   the gate's own fixture, in-domain
    AudioSet      out-of-domain, real-world recordings

Fitted on the pool, and ALSO fitted on each alone and tested on the other,
because a calibration that only works on the corpus it was fitted to is the
same in-domain trap as every model number this week.

XD-Violence non-violent clips are used ONLY as an ambient reference, never
fitted on. They have no scream labels -- a non-violent film scene usually
but not certainly lacks a scream -- so treating them as labelled negatives
would be inventing data. They answer one question: where does ordinary media
audio land, before and after.

SHIP RULE, fixed before running:
  1. AUC preserved within 0.001 on BOTH corpora (monotonicity check)
  2. cross-corpus: fit on A, test on B, AUC still preserved
  3. ambient median falls to <= 0.5 (it is 0.898 today)
  4. separation between ambient and TRUE screams widens in calibrated space
Anything less and this is reported, not shipped.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
MODEL = os.path.join(ASSETS, "scream_classifier_v5.tflite")


def run(X):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=MODEL)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    out = np.zeros(len(X))
    for k in range(len(X)):
        it.set_tensor(i0["index"],
                      X[k:k + 1].reshape(shape).astype(i0["dtype"]))
        it.invoke()
        v = it.get_tensor(o0["index"]).ravel()
        out[k] = float(v[-1]) if v.size > 1 else float(v[0])
    return out


def main():
    from sklearn.isotonic import IsotonicRegression
    from sklearn.metrics import roc_auc_score

    # --- corpus 1: the gate's FSD50K eval fixture
    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    p_fsd = run(d["Xf"].astype(np.float32))
    y_fsd = np.asarray(d["yf"]).astype(int)

    # --- corpus 2: AudioSet (built Day 363B)
    a = np.load(os.path.join(HERE, "audioset_scream_mel.npz"))
    p_as = run(a["X"].astype(np.float32))
    y_as = a["y"].astype(int)

    # --- ambient reference: XD-Violence non-violent media audio, UNFITTED
    rows = json.load(open(os.path.join(HERE, "xd_fusion_rows.json"),
                          encoding="utf-8"))
    amb = np.array([r["scream"] for r in rows if r["y"] == 0], float)

    print("FSD50K eval  n=%-5d pos=%-4d AUC %.4f" % (len(y_fsd), y_fsd.sum(),
                                                     roc_auc_score(y_fsd,
                                                                   p_fsd)))
    print("AudioSet     n=%-5d pos=%-4d AUC %.4f" % (len(y_as), y_as.sum(),
                                                     roc_auc_score(y_as,
                                                                   p_as)))
    print("ambient (XD non-violent) n=%d  median %.4f  p90 %.4f"
          % (len(amb), np.median(amb), np.percentile(amb, 90)))

    def fit(ps, ys):
        ir = IsotonicRegression(y_min=0.0, y_max=1.0, out_of_bounds="clip")
        ir.fit(np.concatenate(ps), np.concatenate(ys))
        return ir

    print("\n=== cross-corpus check (fit on one, test on the other)")
    ok_cross = True
    for name, tr, te in (("fit FSD50K -> test AudioSet",
                          ([p_fsd], [y_fsd]), (p_as, y_as)),
                         ("fit AudioSet -> test FSD50K",
                          ([p_as], [y_as]), (p_fsd, y_fsd))):
        ir = fit(*tr)
        raw = roc_auc_score(te[1], te[0])
        cal = roc_auc_score(te[1], ir.predict(te[0]))
        delta = abs(cal - raw)
        ok = delta <= 0.001
        ok_cross &= ok
        print("  %-30s raw %.4f -> cal %.4f  |delta| %.5f  %s"
              % (name, raw, cal, delta, "OK" if ok else "FAIL"))

    print("\n=== pooled calibration")
    ir = fit([p_fsd, p_as], [y_fsd, y_as])
    c_fsd, c_as, c_amb = (ir.predict(p_fsd), ir.predict(p_as),
                          ir.predict(amb))

    a1 = roc_auc_score(y_fsd, p_fsd), roc_auc_score(y_fsd, c_fsd)
    a2 = roc_auc_score(y_as, p_as), roc_auc_score(y_as, c_as)
    print("  FSD50K  AUC raw %.4f -> cal %.4f  |delta| %.5f"
          % (a1[0], a1[1], abs(a1[1] - a1[0])))
    print("  AudioSet AUC raw %.4f -> cal %.4f  |delta| %.5f"
          % (a2[0], a2[1], abs(a2[1] - a2[0])))
    mono_ok = abs(a1[1] - a1[0]) <= 0.001 and abs(a2[1] - a2[0]) <= 0.001

    print("\n=== where the mass moves")
    print("  %-34s %10s %10s" % ("", "raw", "calibrated"))
    print("  %-34s %10.4f %10.4f" % ("ambient media audio, median",
                                     np.median(amb), np.median(c_amb)))
    print("  %-34s %10.4f %10.4f" % ("ambient media audio, p90",
                                     np.percentile(amb, 90),
                                     np.percentile(c_amb, 90)))
    print("  %-34s %10.4f %10.4f" % ("true screams (AudioSet), median",
                                     np.median(p_as[y_as == 1]),
                                     np.median(c_as[y_as == 1])))
    sep_raw = float(np.median(p_as[y_as == 1]) - np.median(amb))
    sep_cal = float(np.median(c_as[y_as == 1]) - np.median(c_amb))
    print("  %-34s %10.4f %10.4f" % ("separation (screams - ambient)",
                                     sep_raw, sep_cal))

    print("\n=== effect on the DCS fusion contribution (weight 0.5)")
    for lbl, rawv, calv in (("ambient media audio", np.median(amb),
                             np.median(c_amb)),
                            ("true scream", np.median(p_as[y_as == 1]),
                             np.median(c_as[y_as == 1]))):
        print("  %-22s raw %.3f -> %.3f of threshold | cal %.3f -> %.3f"
              % (lbl, rawv, 0.5 * rawv, calv, 0.5 * calv))
    fall = 0.30
    print("  fall(0.30) + ambient:  raw %.3f %s | cal %.3f %s"
          % (0.5 * np.median(amb) + fall,
             "ALERT" if 0.5 * np.median(amb) + fall >= 0.75 else "--",
             0.5 * np.median(c_amb) + fall,
             "ALERT" if 0.5 * np.median(c_amb) + fall >= 0.75 else "--"))

    amb_ok = float(np.median(c_amb)) <= 0.5
    sep_ok = sep_cal > sep_raw
    ships = bool(mono_ok and ok_cross and amb_ok and sep_ok)
    print("\n  ship rule: AUC preserved both corpora=%s, cross-corpus=%s, "
          "ambient median<=0.5=%s, separation widened=%s -> %s"
          % (mono_ok, ok_cross, amb_ok, sep_ok,
             "SHIPS" if ships else "DOES NOT SHIP"))

    # Export as a lookup table the Dart side can apply with no new model.
    xs = np.linspace(0.0, 1.0, 257)
    ys = ir.predict(xs)
    out = {"kind": "isotonic lookup, 257 points, linear interp between",
           "x": [round(float(v), 6) for v in xs],
           "y": [round(float(v), 6) for v in ys],
           "fitted_on": "FSD50K eval + AudioSet scream labels",
           "auc_preserved": {"fsd50k": round(abs(a1[1] - a1[0]), 5),
                             "audioset": round(abs(a2[1] - a2[0]), 5)},
           "ambient_median_raw": round(float(np.median(amb)), 4),
           "ambient_median_calibrated": round(float(np.median(c_amb)), 4),
           "separation_raw": round(sep_raw, 4),
           "separation_calibrated": round(sep_cal, 4),
           "ships": ships,
           "note": ("Monotone: AUC is unchanged by construction and is "
                    "asserted. This does NOT make the detector better, it "
                    "makes its output usable by a weighted-sum fusion. "
                    "Ambient reference is XD-Violence non-violent audio, "
                    "used for reporting only, never fitted on.")}
    json.dump(out, open(os.path.join(HERE, "scream_calibration.json"), "w"),
              indent=2)
    print("  wrote scream_calibration.json (%d-point lookup)" % len(xs))


if __name__ == "__main__":
    main()
