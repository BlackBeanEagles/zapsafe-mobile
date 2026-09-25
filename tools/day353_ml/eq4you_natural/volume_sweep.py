"""Day 356 - does EQ4You help at SOME volume, or not at all?

THE OBSERVATION THAT PROMPTED THIS
==================================
    tar4 only   5,325 anger (EQ4You ~1:1 with base)  +0.0142 [-0.0047, +0.0334]
    4 tars     21,629 anger (EQ4You ~4:1 with base)  +0.0066 [-0.0123, +0.0252]

Four times the data made the effect SMALLER and the CI WIDER. A real effect
does the opposite. But there are two different explanations and they imply
opposite actions:

  A) the data carries no usable signal, and the tar4 number was noise
     -> stop; the remaining 872 tars are worthless

  B) the signal is real but EQ4You DOMINATES at 4:1 and drags the model
     toward its own distribution (corpus-ID AUC is 0.9994, so the model can
     tell the corpora apart trivially and can partition rather than
     generalise)
     -> the fix is a mixing RATIO, not more data, and more tars still buy
        nothing

Note both explanations say stop downloading. This sweep decides which is
true, because it changes what to do with the 40 GB already on disk.

THE SWEEP
=========
One WITHOUT arm, then WITH arms at increasing EQ4You volume, every arm
scored on the identical untouched MELD eval rows. Subsamples are drawn
SPEAKER-DISJOINTLY from the pooled 4-tar set with a fixed seed, so a
smaller arm is a random slice of the same corpus rather than one tar.

READING, fixed before running:
    delta rises with volume        -> more data helps; revisit downloading
    delta peaks low then falls     -> explanation B, use a capped ratio
    delta flat/negative throughout -> explanation A, drop EQ4You entirely
"""
from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
HA = os.path.join(WORK, "h_aggressive_v4")
EQ = r"D:\zapsafe\eq4you\eq4you_yin2048.npz"
SEED = 42

import ab_eq4you as A


def subsample(X, y, spk, n, seed):
    """Speaker-disjoint slice: whole recordings, never split mid-speaker."""
    rng = np.random.RandomState(seed)
    groups = np.unique(spk)
    rng.shuffle(groups)
    keep, total = [], 0
    for g in groups:
        idx = np.where(spk == g)[0]
        keep.append(idx)
        total += len(idx)
        if total >= n:
            break
    sel = np.concatenate(keep)
    return X[sel], y[sel], spk[sel]


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
    Xq, yq, sq = A.load(EQ)

    print("base %s pos=%d | EQ4You pool %s pos=%d | eval %s pos=%d"
          % (Xb.shape, yb.sum(), Xq.shape, yq.sum(), Xe.shape, ye.sum()))

    # WITHOUT arm, once
    mu, sd = Xb.mean(0), Xb.std(0) + 1e-8
    Z0 = lambda M: ((M - mu) / sd).astype(np.float32)
    A.SEED = SEED
    m0 = A.fit(Z0(Xb), yb, A.balanced_w(yb, cb), Z0(Xe), ye, 38, (64, 32))
    p0 = m0.predict(Z0(Xe), verbose=0).ravel()
    auc0 = float(roc_auc_score(ye, p0))
    print("\n  WITHOUT  %.4f  (n_train=%d)\n" % (auc0, len(yb)))

    rows = []
    for n in (4000, 8000, 17000, 34000, len(yq)):
        Xs, ys, _ = subsample(Xq, yq, sq, n, SEED)
        Xtr = np.vstack([Xb, Xs])
        ytr = np.concatenate([yb, ys])
        ctr = np.concatenate([cb, np.full(len(ys), "eq4you")])
        mu2, sd2 = Xtr.mean(0), Xtr.std(0) + 1e-8
        Z = lambda M: ((M - mu2) / sd2).astype(np.float32)
        A.SEED = SEED
        m = A.fit(Z(Xtr), ytr, A.balanced_w(ytr, ctr), Z(Xe), ye, 38,
                  (64, 32))
        p = m.predict(Z(Xe), verbose=0).ravel()
        auc = float(roc_auc_score(ye, p))
        lo, hi, mean = A.paired_ci(ye, p, p0)
        ratio = len(ys) / float(len(yb))
        print("  EQ4You n=%-6d (%.2f:1)  WITH %.4f  delta %+.4f "
              "CI [%+.4f, %+.4f]" % (len(ys), ratio, auc, mean, lo, hi),
              flush=True)
        rows.append({"n": int(len(ys)), "ratio": round(ratio, 2),
                     "with": round(auc, 4), "delta": round(mean, 4),
                     "ci95": [round(lo, 4), round(hi, 4)],
                     "clears": bool(lo > 0)})

    best = max(rows, key=lambda r: r["delta"])
    print("\n  best delta %+.4f at n=%d (%.2f:1), CI [%+.4f, %+.4f] -> %s"
          % (best["delta"], best["n"], best["ratio"], best["ci95"][0],
             best["ci95"][1],
             "CLEARS ZERO" if best["clears"] else "still includes zero"))
    trend = rows[-1]["delta"] - rows[0]["delta"]
    print("  trend across volume: %+.4f (last minus first)" % trend)
    if not any(r["clears"] for r in rows):
        print("  -> no volume clears zero. EQ4You does not help h_aggressive")
        print("     at any mixing ratio tested; downloading more tars is")
        print("     contraindicated, not merely unproven.")
    json.dump({"without": round(auc0, 4), "rows": rows,
               "trend_last_minus_first": round(trend, 4)},
              open(os.path.join(HERE, "volume_report.json"), "w"), indent=2)


if __name__ == "__main__":
    main()
