"""Day 353 - the ESD A/B, paired, with the rule fixed before the numbers.

WHY DAY 352's ANSWER DOES NOT STAND
===================================
Day 352 reported "no-ESD m4 natural 0.6458 vs shipped 0.6235, +0.0223".
Those two numbers were measured on DIFFERENT EVALUATION SETS -- 0.6458 on
held-out speakers of MELD *train*, 0.6235 on MELD test+dev. A delta across
two different sets is not a delta. It was also unpaired, so it carried no CI
on the difference, which is the decision rule this project uses everywhere
else.

WHAT THIS RUN DOES INSTEAD
==========================
Two arms, identical in every respect except the presence of ESD rows:

    WITH     natural train + ESD train speakers
    WITHOUT  natural train only

Same seed, same architecture, same split, same corpus-balanced weighting
(which in WITHOUT degenerates to plain class weights, as it should).
Both arms are then scored on IDENTICAL rows, and the difference is
bootstrapped with the SAME resample indices for both arms, so the CI is on
the paired difference rather than on each arm separately.

m4 additionally gets a genuinely independent natural set: MELD test+dev,
which neither arm trains on. Caveat stated once: MELD splits by dialogue,
not by speaker, and its speakers are recurring actors, so this is held-out
dialogue, not held-out speaker. It is still the best independent set
available and it is identical for both arms.

m5 has no independent natural set -- the 4,000-clip Day 349 cache is drawn
from the same EmotionTalk pool as the 14,000 used here, so scoring on it
would be leakage. m5's comparison is therefore the paired held-out-speaker
one only, and is labelled as such.

THE RULE, FIXED NOW
===================
ESD is dropped unless the paired difference in NATURAL AUC (WITH minus
WITHOUT) has a 95% CI that excludes zero in WITH's favour -- i.e. unless
ESD can be shown to help in the deployment domain.

The acted bar is deliberately NOT part of this rule, and that is the
substantive change from Day 352. diagnose.py measured the per-feature
direction agreement between each acted corpus and its natural counterpart:

    m4   r = -0.07  CI [-0.33, +0.21]   unrelated
    m5   r = -0.56  CI [-0.76, -0.29]   OPPOSED

For m5 the eight features the acted corpus leans on hardest all point the
other way on natural speech, and a linear probe trained on acted reads
0.4004 on natural -- below chance. An acted benchmark that is uncorrelated
(m4) or anti-correlated (m5) with the deployment domain cannot be used to
veto a deployment-domain decision. A phone hears natural speech. The acted
number is still printed, because it is the v1/v2 continuity figure and
hiding it would be worse, but it does not gate.

This is not the acted bar being lowered to let something through. It is the
bar being shown to measure the wrong thing, which is a different claim and
is falsifiable: had the direction correlation come out positive, the bar
would still gate.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
SEED = 42
AVAIL = list(range(7, 33)) + [36, 37]
M4_HELD = {"0012", "0016", "0019"}


def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    spk = d["spk"] if "spk" in d.files else None
    return X, np.asarray(d["y"]).astype(int), spk


def balanced_w(y, corpus):
    w = np.ones(len(y), np.float64)
    n = len(np.unique(corpus))
    for c in np.unique(corpus):
        m = corpus == c
        w[m] *= len(y) / (n * max(int(m.sum()), 1))
        for lab in (0, 1):
            ml = m & (y == lab)
            if ml.sum():
                w[ml] *= m.sum() / (2.0 * max(int(ml.sum()), 1))
    return w


def fit(Xtr, ytr, wtr, Xva, yva, dim):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(SEED)
    np.random.seed(SEED)
    m = tf.keras.Sequential([
        tf.keras.Input(shape=(dim,), name="features"),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(1, activation="sigmoid", name="stress"),
    ])
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=150, batch_size=128,
          verbose=0, sample_weight=wtr,
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])
    return m


def paired_ci(y, pa, pb, n=4000):
    """CI on AUC(pa) - AUC(pb) using the SAME resample for both arms."""
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    d = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        d.append(roc_auc_score(y[i], pa[i]) - roc_auc_score(y[i], pb[i]))
    return (float(np.percentile(d, 2.5)), float(np.percentile(d, 97.5)),
            float(np.mean(d)))


def run(tag, nat_path, act_path, sel, held_acted, indep_path=None):
    from sklearn.metrics import roc_auc_score
    Xn, yn, spkn = load(nat_path)
    Xa, ya, spka = load(act_path)
    dim = len(sel) if sel else Xn.shape[1]
    if sel is not None:
        Xn, Xa = Xn[:, sel], Xa[:, sel]

    print("\n" + "=" * 72)
    print("=== " + tag + " ===")
    groups = np.unique(spkn)
    rng = np.random.RandomState(SEED)
    k = max(1, int(round(len(groups) * 0.25)))
    held = set(rng.permutation(groups)[:k].tolist())
    nte = np.array([s in held for s in spkn])
    ate = np.array([str(s) in held_acted for s in spka])
    print("  natural train %d / held-out %d  (%d/%d speakers)"
          % (int((~nte).sum()), int(nte.sum()), len(held), len(groups)))
    print("  acted   train %d / held-out %d"
          % (int((~ate).sum()), int(ate.sum())))

    Xi = yi = None
    if indep_path:
        Xi, yi, _ = load(indep_path)
        if sel is not None:
            Xi = Xi[:, sel]
        print("  independent natural set %s pos=%d" % (Xi.shape, yi.sum()))

    res, preds = {}, {}
    for arm in ("WITH", "WITHOUT"):
        if arm == "WITH":
            Xtr = np.vstack([Xn[~nte], Xa[~ate]])
            ytr = np.concatenate([yn[~nte], ya[~ate]])
            csrc = np.array(["nat"] * int((~nte).sum())
                            + ["act"] * int((~ate).sum()))
        else:
            Xtr, ytr = Xn[~nte], yn[~nte]
            csrc = np.array(["nat"] * len(ytr))
        mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8

        def Z(A):
            return ((A - mu) / sd).astype(np.float32)

        m = fit(Z(Xtr), ytr, balanced_w(ytr, csrc), Z(Xn[nte]), yn[nte], dim)
        p_nat = m.predict(Z(Xn[nte]), verbose=0).ravel()
        p_act = m.predict(Z(Xa[ate]), verbose=0).ravel()
        preds[arm] = {"nat": p_nat, "act": p_act}
        res[arm] = {
            "natural_heldout": round(float(roc_auc_score(yn[nte], p_nat)), 4),
            "acted_heldout": round(float(roc_auc_score(ya[ate], p_act)), 4),
            "n_train": int(len(ytr)),
        }
        line = ("  %-8s natural %.4f   acted %.4f"
                % (arm, res[arm]["natural_heldout"],
                   res[arm]["acted_heldout"]))
        if Xi is not None:
            p_i = m.predict(Z(Xi), verbose=0).ravel()
            preds[arm]["indep"] = p_i
            res[arm]["natural_independent"] = round(
                float(roc_auc_score(yi, p_i)), 4)
            line += "   independent %.4f" % res[arm]["natural_independent"]
        print(line)

    lo, hi, mean = paired_ci(yn[nte], preds["WITH"]["nat"],
                             preds["WITHOUT"]["nat"])
    print("\n  PAIRED natural delta (WITH - WITHOUT) %+.4f 95%% CI "
          "[%+.4f, %+.4f]" % (mean, lo, hi))
    out = {"arms": res, "paired_natural_delta": round(mean, 4),
           "paired_natural_ci95": [round(lo, 4), round(hi, 4)]}

    helps = lo > 0.0
    if Xi is not None:
        ilo, ihi, imean = paired_ci(yi, preds["WITH"]["indep"],
                                    preds["WITHOUT"]["indep"])
        print("  PAIRED independent delta              %+.4f 95%% CI "
              "[%+.4f, %+.4f]" % (imean, ilo, ihi))
        out["paired_independent_delta"] = round(imean, 4)
        out["paired_independent_ci95"] = [round(ilo, 4), round(ihi, 4)]
        helps = helps or ilo > 0.0

    out["esd_helps_natural"] = bool(helps)
    out["decision"] = ("KEEP ESD -- it measurably helps the deployment domain"
                       if helps else
                       "DROP ESD -- no measurable natural-domain benefit")
    print("  -> " + out["decision"])
    return out


def main():
    rep = {"rule": "drop ESD unless the paired natural delta CI excludes 0 "
                   "in WITH's favour; acted does not gate (see diagnose.py)"}
    rep["m4"] = run("m4 English  MELD natural + ESD-en acted",
                    os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"),
                    os.path.join(WORK, "yin_lite", "yin_lite_feats.npz"),
                    None, M4_HELD,
                    indep_path=os.path.join(WORK, "m4_m5_crosscorpus",
                                            "feat_meld_yin.npz"))
    _, _, spka5 = load(os.path.join(WORK, "m5_mandarin", "features.npz"))
    held5 = set(sorted(np.unique(spka5).tolist())[:3])
    rep["m5"] = run("m5 Mandarin EmotionTalk natural + ESD-zh acted",
                    os.path.join(WORK, "m4_m5_v2", "feat_etalk.npz"),
                    os.path.join(WORK, "m5_mandarin", "features.npz"),
                    AVAIL, held5)
    json.dump(rep, open(os.path.join(HERE, "ab_report.json"), "w"), indent=2)
    print("\nab_report written")


if __name__ == "__main__":
    main()
