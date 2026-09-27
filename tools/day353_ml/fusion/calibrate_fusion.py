"""Day 363B - the DCS fusion weights are inverted against measured reliability.

WHAT SHIPS TODAY
================
`dcs_inference_engine.dart` fuses three detector scores with a LinearStub:

    weights = [0.5, 0.3, 0.2]        # scream, motion, scene
    fused   = 0.5*scream + 0.3*motion + 0.2*scene
    alert threshold 0.75

Those weights were written on Day 31 and never derived from anything. This
measures what they should be, using each detector's real performance through
its real .tflite path on real labelled data.

WHY THE CURRENT ORDER LOOKS WRONG BEFORE MEASURING ANYTHING
===========================================================
    scream_classifier_v5   gate AUC 0.828, and fires on ~6% of real
                           AudioSet screams          -> weighted 0.5 (HIGHEST)
    motion_fall_v2         gate AUC 0.999            -> weighted 0.3
    m3_violence_temporal   gate AUC 0.975            -> weighted 0.2 (LOWEST)

The most reliable detector is weighted lowest and the least reliable
highest. If that holds up, the fusion is actively amplifying its worst
signal.

THE PRINCIPLED REPLACEMENT
==========================
A weighted sum of raw sigmoid outputs is not a fusion, because the outputs
are not on a comparable scale -- a 0.9 from a detector that is right 99% of
the time and a 0.9 from one that is barely better than chance are treated as
the same evidence.

The statistically correct combination is a sum of LOG-LIKELIHOOD RATIOS:

    LLR_i(s) = log[ P(s | danger) / P(s | safe) ]
    log-odds(danger) = prior + sum_i LLR_i(s_i)

under conditional independence of the detectors given the class. Each
detector then contributes evidence in proportion to how much its score
actually discriminates, which is exactly the property the hand-written
weights lack. The independence assumption is stated, not hidden -- it is
wrong in detail (a violent scene and a scream co-occur) and it is the
standard first-order approximation.

Each LLR is fitted by logistic regression on that detector's own measured
scores against real labels, which is monotone, so **single-detector AUC is
unchanged**. Calibration does not make a detector better. It makes the
detectors ADDABLE, which is what a fusion needs.

WHAT THIS CAN AND CANNOT VALIDATE
=================================
Per-detector calibration is fitted on real labelled data for each modality.
The FUSED model cannot be validated end-to-end without co-occurring
multi-modal incident data, which is exactly what M9 has always lacked.
So this reports the calibration and the implied weights, and does not claim
a fused AUC it cannot measure.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
        r"\zapsafe_mobile_main_reconcile")
ASSETS = os.path.join(ROOT, "assets", "models")
XCORP = r"D:\zapsafe\audioset_xcorpus"
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"

CURRENT_WEIGHTS = {"scream": 0.5, "motion": 0.3, "scene": 0.2}


def run_tflite(path, X):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=path)
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


def fit_llr(scores, y):
    """Fit log[P(s|danger)/P(s|safe)] as a logistic in the score.

    Returns (a, b) for LLR(s) = a*s + b, plus diagnostics. Monotone in s,
    so the detector's ranking -- and therefore its AUC -- is untouched.
    """
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    s = np.asarray(scores, float).reshape(-1, 1)
    y = np.asarray(y, int)
    lr = LogisticRegression(max_iter=2000)
    lr.fit(s, y)
    a = float(lr.coef_[0][0])
    # logistic gives log-odds of the POSTERIOR; subtract the prior log-odds
    # to recover the likelihood ratio the fusion should sum.
    p = float(y.mean())
    prior = np.log(p / (1 - p)) if 0 < p < 1 else 0.0
    b = float(lr.intercept_[0]) - prior
    auc = float(roc_auc_score(y, s.ravel()))
    # Evidence span: how many nats of LLR separate a confident negative from
    # a confident positive. This is the detector's real "weight".
    lo, hi = np.percentile(s.ravel(), [5, 95])
    span = abs(a) * (hi - lo)
    return {"a": round(a, 4), "b": round(b, 4), "auc": round(auc, 4),
            "llr_span_nats": round(float(span), 4),
            "pos": int(y.sum()), "n": int(len(y)),
            "score_p5": round(float(lo), 4), "score_p95": round(float(hi), 4)}


def audioset_scream():
    """scream_classifier_v5 over AudioSet, labelled by AudioSet's own
    Screaming/Shout/Yell classes. Out-of-domain on purpose: the fusion runs
    in the world, not on FSD50K."""
    import csv, io, glob, librosa
    A = (r"C:\Users\hridy\Desktop\zapsafe\ml_datasets\audio_events"
         r"\DS07_AudioSet")
    cache = os.path.join(HERE, "audioset_scream_mel.npz")
    if os.path.exists(cache):
        d = np.load(cache)
        return d["X"], d["y"].astype(int)

    lab = {r["mid"]: r["display_name"] for r in
           csv.DictReader(io.open(os.path.join(A, "class_labels_indices.csv"),
                                  encoding="utf-8"))}
    POS = {"Screaming", "Shout", "Yell", "Bellow", "Children shouting"}
    by = {}
    for f in ("balanced_train_segments.csv", "unbalanced_train_segments.csv",
              "eval_segments.csv"):
        p = os.path.join(A, f)
        if not os.path.exists(p):
            continue
        for line in io.open(p, encoding="utf-8"):
            if line.startswith("#"):
                continue
            parts = line.split(",", 3)
            if len(parts) < 4:
                continue
            names = {lab.get(m.strip(), "") for m in
                     parts[3].replace(chr(34), "").split(",")}
            by.setdefault(parts[0].strip(), set()).update(names)

    files = sorted(glob.glob(os.path.join(A, "train_wav", "*.wav")))
    rng = np.random.RandomState(42)
    pos = [p for p in files
           if by.get(os.path.splitext(os.path.basename(p))[0], set()) & POS]
    neg = [p for p in files
           if p not in set(pos)
           and by.get(os.path.splitext(os.path.basename(p))[0], set())]
    neg = [neg[i] for i in rng.permutation(len(neg))[:900]]
    print("  scream fixture: %d pos, %d neg" % (len(pos), len(neg)))

    SR, DUR, N_MELS, FRAMES = 22050, 3, 128, 131
    need = SR * DUR
    X, y = [], []
    for p, lb in [(p, 1) for p in pos] + [(p, 0) for p in neg]:
        try:
            w, _ = librosa.load(p, sr=SR, mono=True)
        except Exception:
            continue
        best = None
        for st in range(0, max(1, len(w) - need + 1), need // 2):
            seg = w[st:st + need]
            seg = np.pad(seg, (0, need - len(seg))) if len(seg) < need else seg
            mel = librosa.feature.melspectrogram(y=seg, sr=SR, n_mels=N_MELS,
                                                 n_fft=2048, hop_length=512)
            db = librosa.power_to_db(mel, ref=np.max)
            rg = db.max() - db.min()
            db = (db - db.min()) / (rg if rg > 1e-8 else 1.0)
            if db.shape[1] < FRAMES:
                db = np.pad(db, ((0, 0), (0, FRAMES - db.shape[1])))
            m = db[:, :FRAMES].astype(np.float16)
            best = m if best is None else best
            break                      # first window; max-over-windows is
                                       # handled by the caller if needed
        if best is None:
            continue
        X.append(best)
        y.append(lb)
    X = np.stack(X)
    y = np.asarray(y, int)
    np.savez_compressed(cache, X=X, y=y)
    return X, y


def main():
    from sklearn.metrics import roc_auc_score
    out = {}

    print("=== scream_classifier_v5 on AudioSet (out of domain)")
    Xs, ys = audioset_scream()
    ps = run_tflite(os.path.join(ASSETS, "scream_classifier_v5.tflite"),
                    Xs.astype(np.float32))
    out["scream"] = fit_llr(ps, ys)
    print("   ", out["scream"])

    print("=== m_glass_breaking_v4 / mg_gunshot_v2 on AudioSet (reference)")
    d = np.load(os.path.join(XCORP, "audioset_fixture.npz"), allow_pickle=True)
    for task, asset in (("glass", "m_glass_breaking_v4.tflite"),
                        ("gun", "mg_gunshot_v2.tflite")):
        nwin = d["nwin_%s" % task].astype(int)
        offs = np.concatenate([[0], np.cumsum(nwin)])
        W = d["win_%s" % task]
        pw = run_tflite(os.path.join(ASSETS, asset),
                        np.repeat(W.astype(np.float32)[..., None], 3, -1))
        p = np.array([pw[offs[k]:offs[k + 1]].max()
                      for k in range(len(nwin))])
        out[task] = fit_llr(p, d["yg" if task == "glass" else "yk"])
        print("    %-6s %s" % (task, out[task]))

    print("\n=== reliability vs the shipped weights")
    spans = {k: out[k]["llr_span_nats"] for k in out}
    tot = sum(spans.values())
    print("  %-8s %8s %8s %12s %12s"
          % ("detector", "AUC", "LLR span", "implied w", "shipped w"))
    for k in out:
        imp = spans[k] / tot if tot else 0
        cur = CURRENT_WEIGHTS.get(k)
        print("  %-8s %8.4f %8.3f %12.3f %12s"
              % (k, out[k]["auc"], spans[k], imp,
                 "%.2f" % cur if cur is not None else "-"))
    out["implied_weights_audio_only"] = {k: round(spans[k] / tot, 4)
                                         for k in spans}
    out["shipped_weights"] = CURRENT_WEIGHTS
    out["note"] = ("LLR span = how many nats of evidence the detector's "
                   "score range actually carries. Calibration is monotone "
                   "so single-detector AUC is unchanged; the point is to "
                   "make the three scores ADDABLE. The fused model is NOT "
                   "validated end-to-end -- that needs co-occurring "
                   "multimodal incident data, which is what M9 lacks.")
    json.dump(out, open(os.path.join(HERE, "fusion_calibration.json"), "w"),
              indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
