"""Day 353 - is h_aggressive's +0.0410 real, or the one win in four tries?

ab_lego.py ran four configurations (two models x two label definitions) and
exactly one cleared its 95% CI. At four independent tests the chance of at
least one false positive at that bar is ~19%, and this project's standing
rule is that a small delta found by screening must be confirmed by
retraining rather than acted on directly.

So the winning configuration is re-run at four fresh seeds. The seed moves
the weight init, the dropout masks and the batch order -- everything except
the data. If the effect is real the sign should be stable across all of
them; if it was a lucky init it will scatter around zero.

Reported: per-seed paired delta on the SAME unchanged MELD eval rows, plus
the mean. No CI on the mean of four points -- four is enough to see a sign,
not enough to put an interval on.
"""
import json, os, numpy as np, ab_lego as A

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
import glob
ha = os.path.join(WORK, "h_aggressive_v4")
base = []
for f in sorted(glob.glob(os.path.join(ha, "feat_*.npz"))):
    t = os.path.basename(f)[5:-4]
    if t == "meld_eval": continue
    X, y, _ = A.load(f); base.append((X, y, t))
Xe, ye, _ = A.load(os.path.join(ha, "feat_meld_eval.npz"))
Xl, yl, _ = A.load(os.path.join(HERE, "lego_yin2048.npz"), "y")
Xb = np.vstack([s[0] for s in base]); yb = np.concatenate([s[1] for s in base])
cb = np.concatenate([np.full(len(s[1]), s[2]) for s in base])

from sklearn.metrics import roc_auc_score
out = []
for seed in (7, 123, 2024, 31337):
    A.SEED = seed
    res = {}
    for arm in ("WITHOUT", "WITH"):
        if arm == "WITH":
            Xtr = np.vstack([Xb, Xl]); ytr = np.concatenate([yb, yl])
            ctr = np.concatenate([cb, np.full(len(yl), "lego")])
        else:
            Xtr, ytr, ctr = Xb, yb, cb
        mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
        Z = lambda M: ((M - mu) / sd).astype(np.float32)
        m = A.fit(Z(Xtr), ytr, A.balanced_w(ytr, ctr), Z(Xe), ye, 38, (64, 32))
        res[arm] = float(roc_auc_score(ye, m.predict(Z(Xe), verbose=0).ravel()))
    d = res["WITH"] - res["WITHOUT"]
    out.append(d)
    print("  seed %-6d WITHOUT %.4f  WITH %.4f  delta %+.4f"
          % (seed, res["WITHOUT"], res["WITH"], d), flush=True)

arr = np.array(out)
print("\n  seeds %d   mean delta %+.4f   min %+.4f   max %+.4f"
      % (len(arr), arr.mean(), arr.min(), arr.max()))
print("  positive in %d/%d seeds" % (int((arr > 0).sum()), len(arr)))
ok = bool((arr > 0).all())
print("  -> %s" % ("CONFIRMED - sign stable across every seed"
                   if ok else "NOT CONFIRMED - the screening hit does not replicate"))
json.dump({"deltas": [round(float(x),4) for x in arr],
           "mean": round(float(arr.mean()),4),
           "positive_seeds": int((arr>0).sum()), "n_seeds": len(arr),
           "confirmed": ok, "screening_delta": 0.0410},
          open(os.path.join(HERE, "confirm_report.json"), "w"), indent=2)
