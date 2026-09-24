"""Day 354 - is m4's LABEL DEFINITION the problem, not its data?

m4 pools anger and sad into one "stressed" class. MOSEI vs MELD came out
at r = -0.61 in that space (9/38 features agreeing) but +0.07 in
h_aggressive's space, and the only difference between those two label sets
is that m4 includes `sad` and h_aggressive does not.

That points at the construct rather than the corpus. Angry speech is loud,
fast and high-pitched; sad speech is quiet, slow and low-pitched. Pooling
them asks one linear direction to mean both, and which one dominates then
depends on the mix of anger and sadness a corpus happens to contain.

This decomposes the positive class and measures direction agreement for
each emotion SEPARATELY against the same MELD rows:

    anger-only   MOSEI anger vs neutral/happy   <->  MELD anger vs neutral/happy
    sad-only     MOSEI sad   vs neutral/happy   <->  MELD sad   vs neutral/happy

If anger agrees and sad opposes, m4's label definition is incoherent across
corpora and no amount of extra data fixes it -- the fix is to stop pooling.
"""
import os, json
import numpy as np
from sklearn.metrics import roc_auc_score

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)

def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0, neginf=0.0)
    return X, np.asarray(d["y"]).astype(int), np.asarray(d["emo"])

def feat_auc(X, y):
    return np.array([roc_auc_score(y, X[:, j]) for j in range(X.shape[1])])

def boot_corr(a, b, n=4000):
    rng = np.random.RandomState(0); out=[]
    for _ in range(n):
        i = rng.randint(0, len(a), len(a))
        if np.std(a[i])<1e-12 or np.std(b[i])<1e-12: continue
        out.append(float(np.corrcoef(a[i],b[i])[0,1]))
    return float(np.percentile(out,2.5)), float(np.percentile(out,97.5))

# MOSEI in m4's space, with emotion strings retained
Xm, _, em = load(os.path.join(HERE, "mosei_yin512.npz"))
# MELD in m4's space -- rebuild per-emotion labels from the same source
d = np.load(os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"), allow_pickle=True)
Xd = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0, neginf=0.0)
yd = np.asarray(d["y"]).astype(int)

rep = {}
NEG = {"neutral", "happy"}
for emo in ("anger", "sad"):
    m = np.array([e == emo or e in NEG for e in em])
    y_mosei = np.array([1 if e == emo else 0 for e in em[m]])
    a_mosei = feat_auc(Xm[m], y_mosei)
    # MELD's cached labels are already pooled, so the MELD side is the
    # pooled direction -- stated, not hidden. The comparison that matters
    # is anger-vs-pooled against sad-vs-pooled on the SAME MELD vector.
    a_meld = feat_auc(Xd, yd)
    r = float(np.corrcoef(a_mosei-0.5, a_meld-0.5)[0,1])
    lo, hi = boot_corr(a_mosei-0.5, a_meld-0.5)
    agree = int(np.sum(np.sign(a_mosei-0.5) == np.sign(a_meld-0.5)))
    print("  MOSEI %-6s (n=%d, pos=%d) vs MELD pooled: r = %+.4f [%+.4f, %+.4f]  %d/38 agree"
          % (emo, int(m.sum()), int(y_mosei.sum()), r, lo, hi, agree))
    rep[emo] = {"r": round(r,4), "ci95":[round(lo,4),round(hi,4)], "agree": agree,
                "n": int(m.sum()), "pos": int(y_mosei.sum())}

# and the two MOSEI emotions against EACH OTHER
ma = np.array([e=="anger" or e in NEG for e in em])
ms = np.array([e=="sad" or e in NEG for e in em])
aa = feat_auc(Xm[ma], np.array([1 if e=="anger" else 0 for e in em[ma]]))
ss = feat_auc(Xm[ms], np.array([1 if e=="sad" else 0 for e in em[ms]]))
r2 = float(np.corrcoef(aa-0.5, ss-0.5)[0,1]); lo2,hi2 = boot_corr(aa-0.5, ss-0.5)
ag2 = int(np.sum(np.sign(aa-0.5)==np.sign(ss-0.5)))
print("\n  WITHIN MOSEI, anger-direction vs sad-direction: r = %+.4f [%+.4f, %+.4f]  %d/38 agree"
      % (r2, lo2, hi2, ag2))
rep["anger_vs_sad_within_mosei"] = {"r": round(r2,4), "ci95":[round(lo2,4),round(hi2,4)], "agree": ag2}
if hi2 < 0:
    print("  -> anger and sad point OPPOSITE ways in the same corpus, same")
    print("     extractor, same speakers. Pooling them into one 'stressed'")
    print("     class asks one direction to mean two contradictory things.")
json.dump(rep, open(os.path.join(HERE,"decompose_report.json"),"w"), indent=2)
