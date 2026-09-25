"""Day 356 - is EQ4You's +0.0142 on h_aggressive stable, or an init?

ab_eq4you.py measured the paired delta on unchanged MELD eval rows at
+0.0142, CI [-0.0047, +0.0334]. The CI includes zero, so by the standing
rule this does NOT clear the bar. But it is the first corpus all week with
a positive point estimate on h_aggressive, and its lower bound is only
-0.0047 from zero, so the question worth answering is whether the effect is
REAL AND SMALL (in which case more data should push it clear) or NOISE (in
which case the remaining 876 tars are worthless).

Seed replication separates those. The seed moves weight init, dropout masks
and batch order -- everything except the data. A real small effect keeps its
sign; an init artefact scatters.

This is the exact step that killed LEGOv2 after its screening run produced
+0.0410 with a CI that DID exclude zero. LEGOv2 then replicated at
+0.0267 / -0.0041 / -0.0185 / +0.0074, mean +0.0029, and was rejected. So a
positive point estimate here means nothing on its own.

READING, fixed before running:
    sign positive in 4/4   effect is real; scaling the corpus up is
                           justified and the remaining tars are worth pulling
    3/4                    weak but plausible; decide on the 4-tar A/B
    <= 2/4                 noise, exactly like LEGOv2; stop here
"""
from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
HA = os.path.join(WORK, "h_aggressive_v4")
EQ = r"D:\zapsafe\eq4you\eq4you_tar4only_yin2048.npz"

import ab_eq4you as A


def main():
    from sklearn.metrics import roc_auc_score

    base = []
    for f in sorted(glob.glob(os.path.join(HA, "feat_*.npz"))):
        t = os.path.basename(f)[5:-4]
        if t == "meld_eval":
            continue
        X, y, _ = A.load(f)
        base.append((X, y, t))
    Xb = np.vstack([s[0] for s in base])
    yb = np.concatenate([s[1] for s in base])
    cb = np.concatenate([np.full(len(s[1]), s[2]) for s in base])
    Xe, ye, _ = A.load(os.path.join(HA, "feat_meld_eval.npz"))
    Xl, yl, _ = A.load(EQ)

    print("base %s pos=%d | EQ4You %s pos=%d | eval %s pos=%d"
          % (Xb.shape, yb.sum(), Xl.shape, yl.sum(), Xe.shape, ye.sum()))

    out = []
    for seed in (7, 123, 2024, 31337):
        A.SEED = seed
        res = {}
        for arm in ("WITHOUT", "WITH"):
            if arm == "WITH":
                Xtr = np.vstack([Xb, Xl])
                ytr = np.concatenate([yb, yl])
                ctr = np.concatenate([cb, np.full(len(yl), "eq4you")])
            else:
                Xtr, ytr, ctr = Xb, yb, cb
            mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8

            def Z(M, mu=mu, sd=sd):
                return ((M - mu) / sd).astype(np.float32)

            m = A.fit(Z(Xtr), ytr, A.balanced_w(ytr, ctr), Z(Xe), ye, 38,
                      (64, 32))
            res[arm] = float(roc_auc_score(
                ye, m.predict(Z(Xe), verbose=0).ravel()))
        d = res["WITH"] - res["WITHOUT"]
        out.append(d)
        print("  seed %-6d WITHOUT %.4f  WITH %.4f  delta %+.4f"
              % (seed, res["WITHOUT"], res["WITH"], d), flush=True)

    arr = np.array(out)
    npos = int((arr > 0).sum())
    print("\n  seeds %d  mean %+.4f  min %+.4f  max %+.4f  positive %d/%d"
          % (len(arr), arr.mean(), arr.min(), arr.max(), npos, len(arr)))
    if npos == len(arr):
        v = ("CONFIRMED - sign stable at every seed; the effect is real and "
             "small, so scaling the corpus up is justified")
    elif npos >= 3:
        v = ("WEAK - plausible but not stable; let the 4-tar A/B decide")
    else:
        v = ("NOISE - does not replicate, exactly like LEGOv2; stop here")
    print("  -> %s" % v)
    json.dump({"deltas": [round(float(x), 4) for x in arr],
               "mean": round(float(arr.mean()), 4),
               "positive_seeds": npos, "n_seeds": len(arr),
               "screening_delta": 0.0142,
               "screening_ci95": [-0.0047, 0.0334],
               "verdict": v},
              open(os.path.join(HERE, "confirm_report.json"), "w"), indent=2)


if __name__ == "__main__":
    main()
