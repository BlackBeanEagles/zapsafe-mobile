"""Day 353 - is LEGOv2 usable, or is it ESD again with a different accent?

Today's lesson was that a corpus can be spontaneous, correctly labelled, in
the right feature space, and still teach a relationship that is BACKWARDS in
the deployment domain. ESD passed every structural check and had a
per-feature direction correlation of -0.56 against natural Mandarin.

So LEGOv2 gets the same three tests before a single model is trained on it.

TEST 1 - DIRECTION AGREEMENT
    Per-feature signed AUC on LEGO vs on MELD, correlated. Negative or
    zero-spanning means the two corpora disagree about what anger looks
    like, and pooling them would teach the average of two opposite things.

TEST 2 - CORPUS SEPARABILITY
    Can a classifier tell LEGO rows from MELD rows? LEGO is 8 kHz
    telephone audio upsampled to 16 kHz, so this is expected to be high.
    It matters because a trivially separable corpus lets a pooled model
    PARTITION rather than generalise -- it learns "if telephone, use rule
    A; else rule B" and the LEGO rows then contribute nothing to MELD
    performance. This project has hit that before at corpus-ID AUC 1.0000.
    A high number here is not automatically fatal, but it means TEST 3 is
    the only thing that counts.

TEST 3 is the paired A/B in ab_lego.py, and it is the one with authority.

BOTH LABEL DEFINITIONS are checked, because the choice is not obvious:
    strict  angry + veryAngry           241 positives
    wide    + slightlyAngry             934 positives
"slightlyAngry" triples the positive count, and if it also flips the
direction agreement then it is annotation noise rather than signal.
"""
from __future__ import annotations

import json
import os

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import cross_val_score

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)


def load(p, ykey="y"):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d[ykey]).astype(int)


def feat_auc(X, y):
    return np.array([roc_auc_score(y, X[:, j]) for j in range(X.shape[1])])


def boot_corr(a, b, n=4000):
    rng = np.random.RandomState(0)
    out = []
    for _ in range(n):
        i = rng.randint(0, len(a), len(a))
        if np.std(a[i]) < 1e-12 or np.std(b[i]) < 1e-12:
            continue
        out.append(float(np.corrcoef(a[i], b[i])[0, 1]))
    return float(np.percentile(out, 2.5)), float(np.percentile(out, 97.5))


def transfer(Xtr, ytr, Xte, yte):
    mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
    m = LogisticRegression(max_iter=4000, class_weight="balanced")
    m.fit((Xtr - mu) / sd, ytr)
    return float(roc_auc_score(yte, m.predict_proba((Xte - mu) / sd)[:, 1]))


def corpus_id(Xa, Xb):
    """AUC for 'which corpus is this row from'. 1.0 = trivially separable."""
    X = np.vstack([Xa, Xb])
    y = np.concatenate([np.zeros(len(Xa)), np.ones(len(Xb))])
    mu, sd = X.mean(0), X.std(0) + 1e-8
    m = LogisticRegression(max_iter=4000, class_weight="balanced")
    s = cross_val_score(m, (X - mu) / sd, y, cv=3, scoring="roc_auc")
    return float(np.mean(s))


def run(tag, lego_path, meld_path, ykey):
    Xl, yl = load(lego_path, ykey)
    Xm, ym = load(meld_path)
    print("\n" + "=" * 72)
    print("=== %s  (LEGO label set: %s) ===" % (tag, ykey))
    print("  LEGO %s pos=%d (%.1f%%)" % (Xl.shape, yl.sum(),
                                         yl.mean() * 100))
    print("  MELD %s pos=%d (%.1f%%)" % (Xm.shape, ym.sum(),
                                         ym.mean() * 100))

    al, am = feat_auc(Xl, yl), feat_auc(Xm, ym)
    r = float(np.corrcoef(al - 0.5, am - 0.5)[0, 1])
    lo, hi = boot_corr(al - 0.5, am - 0.5)
    agree = int(np.sum(np.sign(al - 0.5) == np.sign(am - 0.5)))
    print("\n  TEST 1  direction correlation r = %+.4f [%+.4f, %+.4f]"
          % (r, lo, hi))
    print("          features agreeing on direction: %d/%d"
          % (agree, len(al)))

    cid = corpus_id(Xl, Xm)
    print("  TEST 2  corpus-ID AUC = %.4f %s"
          % (cid, "(trivially separable -- see docstring)" if cid > 0.95
             else ""))

    l2m = transfer(Xl, yl, Xm, ym)
    m2l = transfer(Xm, ym, Xl, yl)
    print("  linear LEGO -> MELD : %.4f" % l2m)
    print("  linear MELD -> LEGO : %.4f" % m2l)

    verdict = ("OPPOSED - do not pool" if hi < 0 else
               "UNRELATED - pooling unlikely to help, A/B decides"
               if lo < 0 < hi else
               "AGREES - pooling is worth the A/B")
    print("  -> %s" % verdict)
    return {"dir_corr": round(r, 4), "dir_corr_ci95": [round(lo, 4),
            round(hi, 4)], "agree": agree, "n_feat": int(len(al)),
            "corpus_id_auc": round(cid, 4),
            "linear_lego_to_meld": round(l2m, 4),
            "linear_meld_to_lego": round(m2l, 4), "verdict": verdict}


def main():
    rep = {}
    for ykey in ("y", "y_strict"):
        rep["h_aggressive_2048_" + ykey] = run(
            "h_aggressive space (2048/512)",
            os.path.join(HERE, "lego_yin2048.npz"),
            os.path.join(WORK, "h_aggressive_v4", "feat_meld_train.npz"),
            ykey)
        rep["m4_512_" + ykey] = run(
            "m4 space (512/256)",
            os.path.join(HERE, "lego_yin512.npz"),
            os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"),
            ykey)
    json.dump(rep, open(os.path.join(HERE, "diagnose_report.json"), "w"),
              indent=2)
    print("\ndiagnose_report written")


if __name__ == "__main__":
    main()
