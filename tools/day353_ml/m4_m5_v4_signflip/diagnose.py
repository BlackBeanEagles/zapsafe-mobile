"""Day 353 - why does a natural-only m4 score 0.318 on acted ESD?

An AUC of 0.318 is not a weak model. It is an INVERTED one: flip the sign
and it reads 0.682. Something is systematically backwards, and before the
ESD licence question can be answered the direction has to be explained.

Three candidate causes, and this separates them without training anything
expensive:

  A) feature-space mismatch -- ruled out already by reading the code: both
     sides are yin_lite features38(), frame 512 / hop 256.
  B) label-definition mismatch -- both sides use POS={angry,sad},
     NEG={neutral,happy}, so the mapping is nominally identical. But
     nominal identity is not behavioural identity: acted "sad" is
     performed, and a performance of sadness may sit on the opposite side
     of an energy axis from spontaneous sadness.
  C) genuine domain inversion -- the prosodic correlates of stress point
     one way in spontaneous speech and the other way in acted speech.

THE TEST
========
For every one of the 38 features, measure single-feature AUC on each
corpus. That gives, per corpus, a signed vector of "which direction of this
feature means stressed". Then correlate the two vectors.

    corr ~ +1  the corpora agree; the inversion is the classifier's
    corr ~  0  they are unrelated; no transfer either way, as measured
    corr ~ -1  they DISAGREE PER FEATURE -- cause (B)/(C), and the shipped
               model's acted score is bought by ESD teaching it a
               relationship that is false on natural speech

Plus both transfer directions under a plain logistic regression, which has
no capacity to memorise and so isolates the geometry from the architecture.

Nothing here is trained for export. This is a diagnosis.
"""
from __future__ import annotations

import json
import os

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
SEED = 42
AVAIL = list(range(7, 33)) + [36, 37]


def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d["y"]).astype(int), d["spk"]


def feat_auc(X, y):
    """Signed single-feature AUC, one per column."""
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


def logit_transfer(Xtr, ytr, Xte, yte):
    mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
    m = LogisticRegression(max_iter=4000, C=1.0, class_weight="balanced")
    m.fit((Xtr - mu) / sd, ytr)
    return float(roc_auc_score(yte, m.predict_proba((Xte - mu) / sd)[:, 1]))


def run(tag, nat_path, act_path, sel):
    Xn, yn, _ = load(nat_path)
    Xa, ya, _ = load(act_path)
    if sel is not None:
        Xn, Xa = Xn[:, sel], Xa[:, sel]

    print(f"\n{'='*70}\n=== {tag} ===")
    print(f"  natural {Xn.shape} pos={yn.sum()} ({yn.mean()*100:.1f}%)")
    print(f"  acted   {Xa.shape} pos={ya.sum()} ({ya.mean()*100:.1f}%)")

    an, aa = feat_auc(Xn, yn), feat_auc(Xa, ya)
    r = float(np.corrcoef(an - 0.5, aa - 0.5)[0, 1])
    lo, hi = boot_corr(an - 0.5, aa - 0.5)
    agree = int(np.sum(np.sign(an - 0.5) == np.sign(aa - 0.5)))
    print(f"\n  per-feature direction correlation r = {r:+.4f} "
          f"[{lo:+.4f}, {hi:+.4f}]")
    print(f"  features agreeing on direction: {agree}/{len(an)}")

    # the features each corpus leans on hardest, and what the other says
    order = np.argsort(-np.abs(aa - 0.5))[:8]
    print("\n  strongest ACTED features, and the same feature on NATURAL:")
    for j in order:
        flag = "  <-- OPPOSITE" if np.sign(aa[j]-.5) != np.sign(an[j]-.5) else ""
        print(f"    f{sel[j] if sel else j:<3d} acted {aa[j]:.3f}   "
              f"natural {an[j]:.3f}{flag}")

    n2a = logit_transfer(Xn, yn, Xa, ya)
    a2n = logit_transfer(Xa, ya, Xn, yn)
    print(f"\n  logistic natural -> acted : {n2a:.4f}")
    print(f"  logistic acted -> natural : {a2n:.4f}")
    print("  (both below 0.5 = the two corpora define stress oppositely)")

    return {"dir_corr": round(r, 4), "dir_corr_ci95": [round(lo, 4),
            round(hi, 4)], "agree": agree, "n_feat": int(len(an)),
            "logit_nat_to_acted": round(n2a, 4),
            "logit_acted_to_nat": round(a2n, 4),
            "acted_feat_auc": [round(v, 4) for v in aa],
            "natural_feat_auc": [round(v, 4) for v in an]}


def main():
    rep = {}
    rep["m4"] = run("m4  English  (MELD natural vs ESD-en acted)",
                    os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"),
                    os.path.join(WORK, "yin_lite", "yin_lite_feats.npz"),
                    None)
    rep["m5"] = run("m5  Mandarin (EmotionTalk natural vs ESD-zh acted)",
                    os.path.join(WORK, "m4_m5_v2", "feat_etalk.npz"),
                    os.path.join(WORK, "m5_mandarin", "features.npz"),
                    AVAIL)
    json.dump(rep, open(os.path.join(HERE, "report.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
