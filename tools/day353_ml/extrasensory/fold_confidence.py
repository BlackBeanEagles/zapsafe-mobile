"""Day 362B - are the three failing folds real, or are they small-n noise?

The all-60 run gives LOPO median 0.8442 over 19 participants but three folds
below 0.65, one of them 0.4282 -- below chance. The ship rule says that
fails, and the rule was fixed before the run, so it fails.

What the rule does not say is WHY, and that matters for what to do next.
Two very different worlds produce a 0.428 fold:

  (a) the model is genuinely anti-predictive for that person -- it has
      learned something that inverts on them, which is a real safety
      problem and no amount of extra data fixes it by itself;
  (b) that fold has ~68 positives and the AUC is simply unstable, in which
      case the number is noise and the honest statement is "unknown for
      this participant", not "fails for this participant".

This distinguishes them with a per-fold bootstrap over the held-out rows.
If the 95% interval comfortably contains 0.5, the fold is uninformative
rather than damning.

This does NOT change the verdict. The ship rule is pre-registered and it
failed; moving the bar after seeing results is exactly the move this project
keeps refusing to make. This only says what the failure is made of.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "enclosure_all60.npz")
POS = ("label:PHONE_IN_POCKET", "label:PHONE_IN_BAG")
SEED = 42
B = 1000


def main():
    from sklearn.ensemble import HistGradientBoostingClassifier
    from sklearn.metrics import roc_auc_score

    d = np.load(CACHE, allow_pickle=True)
    X, y, uu = d["X"], d["y"].astype(int), d["uuid"]
    both = [u for u in np.unique(uu) if 0 < float(y[uu == u].mean()) < 1]
    m = np.array([u in set(both) for u in uu])
    X, y, uu = X[m], y[m], uu[m]

    rng = np.random.RandomState(SEED)
    rows = []
    for held in both:
        te = uu == held
        tr = ~te
        mu = np.nan_to_num(np.nanmean(X[tr], axis=0))
        sd = np.nanstd(X[tr], axis=0) + 1e-8
        clf = HistGradientBoostingClassifier(max_iter=200, learning_rate=0.1,
                                             max_depth=6, random_state=SEED)
        clf.fit((X[tr] - mu) / sd, y[tr])
        p = clf.predict_proba((X[te] - mu) / sd)[:, 1]
        yt = y[te]
        auc = float(roc_auc_score(yt, p))

        n = len(yt)
        vals = []
        for _ in range(B):
            i = rng.randint(0, n, n)
            if yt[i].min() == yt[i].max():
                continue
            vals.append(roc_auc_score(yt[i], p[i]))
        v = np.asarray(vals)
        lo, hi = np.percentile(v, [2.5, 97.5])
        covers_chance = bool(lo <= 0.5 <= hi)
        rows.append({"user": held[:8], "n": int(n), "pos": int(yt.sum()),
                     "auc": round(auc, 4),
                     "ci95": [round(float(lo), 4), round(float(hi), 4)],
                     "covers_chance": covers_chance})
        print("  %-9s n=%-6d pos=%-5d AUC %.4f  [%.3f, %.3f]%s"
              % (held[:8], n, int(yt.sum()), auc, lo, hi,
                 "   <- interval covers chance" if covers_chance else ""),
              flush=True)

    bad = [r for r in rows if r["auc"] < 0.65]
    print("\n  folds below 0.65: %d" % len(bad))
    for r in bad:
        verdict = ("UNINFORMATIVE - interval covers 0.5"
                   if r["covers_chance"] else
                   "REAL - interval excludes 0.5, the model is genuinely "
                   "wrong for this participant")
        print("    %-9s AUC %.4f  [%.3f, %.3f]  pos=%d  -> %s"
              % (r["user"], r["auc"], r["ci95"][0], r["ci95"][1],
                 r["pos"], verdict))

    real_bad = [r for r in bad if not r["covers_chance"]]
    print("\n  genuinely failing participants: %d of %d"
          % (len(real_bad), len(rows)))
    print("  (folds where the model is measurably worse than guessing, "
          "not merely unmeasured)")
    json.dump({"folds": rows, "below_065": len(bad),
               "genuinely_failing": len(real_bad),
               "note": ("diagnostic only; the pre-registered ship rule "
                        "already failed and is not revised here")},
              open(os.path.join(HERE, "fold_confidence.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
