"""Day 363D - does fusing help, on the first co-occurring multimodal data M9
has ever had?

INPUT
=====
`xd_fusion_rows.json` from `xd_extract.py`: per XD-Violence test video,
(scream_score, scene_score, violence_label), produced by running the real
shipped `.tflite` detectors over the real audio and frames.

FOUR THINGS ARE COMPARED, on identical rows
===========================================
    scream alone            does the audio detector transfer at all
    scene alone             does the video detector transfer at all
    shipped linear          0.5*scream + 0.2*scene, the weights in
                            dcs_inference_engine.dart with motion absent
    learned 2-input         logistic regression, 5-fold CV, out-of-fold

If the learned fusion does not beat the better single detector, **fusion is
not buying anything here** and that is the finding. A fused model is only
worth its complexity if combining beats the best part.

WHAT THE LABEL ACTUALLY MEANS -- read before believing any number
================================================================
XD-Violence's "violent" is **not** this app's "SOS-worthy". It covers fights,
shootings, riots, abuse, car accidents and explosions in **movies and web
video**. A violent movie scene often contains no scream, and a terrified
person in a real emergency is often silent. So these AUCs measure transfer
to a RELATED construct in a DIFFERENT domain -- they do not measure how the
detectors would do on real incidents.

Day 360B flagged this domain risk before any of it was downloaded, and six
speech corpora were rejected this week for exactly the same reason, with
corpus-ID AUC of 0.98-1.00 every time. A poor result here is therefore
expected and is not by itself evidence the detectors are broken.

Day 305 also trained M3 on XD-Violence and got 0.4950, BELOW its 0.5944
UCF-Crime baseline. So the prior on this helping is not high.

MOTION IS ABSENT. XD-Violence has no IMU, so only two of the fusion's three
inputs exist. No constant is substituted: a constant third input trains the
model to ignore motion while still looking like it uses it.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
# calibration fitted on each detector's OWN labelled data (Day 363B)
LLR = {"scream": (3.7674, -1.9535), "scene": (4.7161, -2.0735)}
SHIPPED = {"scream": 0.5, "scene": 0.2}
K = 5


def main():
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score

    rows = json.load(open(os.path.join(HERE, "xd_fusion_rows.json"),
                          encoding="utf-8"))
    y = np.array([r["y"] for r in rows], int)
    s = np.array([r["scream"] for r in rows], float)
    v = np.array([r["scene"] for r in rows], float)
    n = len(y)
    print("rows %d  violent %d (%.1f%%)" % (n, y.sum(), 100 * y.mean()))
    print("scream  median pos %.3f  neg %.3f" % (np.median(s[y == 1]),
                                                 np.median(s[y == 0])))
    print("scene   median pos %.3f  neg %.3f" % (np.median(v[y == 1]),
                                                 np.median(v[y == 0])))

    out = {"n": n, "positives": int(y.sum())}
    a_s = float(roc_auc_score(y, s))
    a_v = float(roc_auc_score(y, v))
    lin = SHIPPED["scream"] * s + SHIPPED["scene"] * v
    a_lin = float(roc_auc_score(y, lin))
    llr = (LLR["scream"][0] * s + LLR["scream"][1]
           + LLR["scene"][0] * v + LLR["scene"][1])
    a_llr = float(roc_auc_score(y, llr))

    # learned fusion, out-of-fold so it is not scored on its own training
    rng = np.random.RandomState(42)
    fold = rng.permutation(n) % K
    oof = np.zeros(n)
    X = np.column_stack([s, v])
    for f in range(K):
        te = fold == f
        tr = ~te
        if len(set(y[tr].tolist())) < 2:
            continue
        m = LogisticRegression(max_iter=2000, class_weight="balanced")
        m.fit(X[tr], y[tr])
        oof[te] = m.predict_proba(X[te])[:, 1]
    a_fit = float(roc_auc_score(y, oof))

    print("\n  %-26s %8s" % ("model", "AUC"))
    for name, a in (("scream alone", a_s), ("scene alone", a_v),
                    ("shipped linear 0.5/0.2", a_lin),
                    ("calibrated LLR sum", a_llr),
                    ("learned 2-input (OOF)", a_fit)):
        print("  %-26s %8.4f" % (name, a))

    best_single = max(a_s, a_v)
    gain = a_fit - best_single
    print("\n  best single %.4f | learned fusion %.4f | gain %+.4f"
          % (best_single, a_fit, gain))

    # paired bootstrap: is the learned fusion actually better than the best
    # single detector, on the same resamples?
    single = s if a_s >= a_v else v
    rs = np.random.RandomState(7)
    dv = []
    for _ in range(2000):
        i = rs.randint(0, n, n)
        if y[i].min() == y[i].max():
            continue
        dv.append(roc_auc_score(y[i], oof[i]) - roc_auc_score(y[i], single[i]))
    dv = np.asarray(dv)
    lo, hi = np.percentile(dv, [2.5, 97.5])
    p = float((dv <= 0).mean())
    print("  paired delta %+.4f  [%+.4f, %+.4f]  P(fusion<=best single) %.3f"
          % (dv.mean(), lo, hi, p))

    helps = bool(p < 0.05)
    print("\n  -> %s" % (
        "FUSION HELPS on this data" if helps else
        "fusion does NOT beat the best single detector here"))
    if max(a_s, a_v) < 0.60:
        print("  -> NOTE: both detectors are near chance on XD-Violence, so "
              "this measures DOMAIN TRANSFER FAILURE, not fusion quality. "
              "A fusion of two uninformative inputs cannot be informative.")

    out.update({"scream_alone": round(a_s, 4), "scene_alone": round(a_v, 4),
                "shipped_linear": round(a_lin, 4),
                "calibrated_llr": round(a_llr, 4),
                "learned_oof": round(a_fit, 4),
                "best_single": round(best_single, 4),
                "gain_vs_best_single": round(float(dv.mean()), 4),
                "ci95": [round(float(lo), 4), round(float(hi), 4)],
                "p_fusion_not_better": round(p, 4),
                "fusion_helps": helps,
                "motion_input": "ABSENT - XD-Violence has no IMU",
                "caveat": ("XD-Violence 'violent' (movie/web fights, riots, "
                           "explosions) is not this app's 'SOS-worthy'. "
                           "These AUCs measure transfer to a related "
                           "construct in a different domain.")})
    json.dump(out, open(os.path.join(HERE, "xd_fusion_eval.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
