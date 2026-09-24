"""Day 353 - final ESD-free m4 and m5, trained on natural speech only.

THE DECISION THIS IMPLEMENTS
============================
`work/m4_m5_v4_signflip/diagnose.py` measured whether the acted corpus and
the natural corpus even agree on which direction of each feature means
"stressed":

    m4   r = -0.07  CI [-0.33, +0.21]   unrelated
    m5   r = -0.56  CI [-0.76, -0.29]   OPPOSED

`ab_esd.py` then ran the paired A/B -- same seed, same split, same
architecture, ESD rows present or absent, scored on identical rows with a
bootstrap on the difference:

    m4  natural  -0.0054  CI [-0.0257, +0.0155]
    m4  independent (MELD test+dev, neither arm trains on it)
                 -0.0163  CI [-0.0329, +0.0008]
    m5  natural  -0.0044  CI [-0.0138, +0.0053]   (38 dims, as ships)

Every point estimate is negative and no CI excludes zero in ESD's favour.
ESD buys nothing in the deployment domain, and on the one genuinely
independent set it costs 0.016 with an upper bound that barely reaches zero.

So dropping ESD is not a trade of capability for legal safety, which is what
Day 352 concluded. It removes an NC corpus at no measurable cost to the
domain a phone actually hears.

WHAT STILL DROPS, HONESTLY
==========================
The acted held-out number collapses: m4 0.7797 -> 0.3055, m5 0.7978 ->
0.5126. That is not hidden, and 0.3055 is worth understanding rather than
explaining away -- it is an INVERTED model, not a broken one, which is
exactly what a -0.56 direction correlation predicts. A model that learned
stress from spontaneous speech ranks acted performances backwards.

That number is not a regression in anything a user experiences. It is the
measurement of a corpus this model is no longer trying to serve.

WHAT THIS DOES NOT FIX
======================
The training data is still not clean. MELD states no licence and is cut
from copyrighted broadcast; EmotionTalk ships with no card at all. Removing
the NC corpus removes the NC exposure specifically and nothing else. See
DAY350_TRAINING_DATA_LICENCES.md.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
SEED = 42

# Day 350 shipped (ESD-trained) numbers, for the printout only.
SHIPPED = {"m4": (0.7738, 0.6235), "m5": (0.7873, 0.7810)}
BAR_NATURAL = 0.60


def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, np.asarray(d["y"]).astype(int), (d["spk"] if "spk" in d.files
                                               else None)


def ci(y, p, n=4000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    b = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        b.append(roc_auc_score(y[i], p[i]))
    return float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))


def build(tag, nat_path, act_path, indep_path=None):
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    tf.keras.backend.clear_session()
    tf.random.set_seed(SEED)
    np.random.seed(SEED)

    Xn, yn, spkn = load(nat_path)
    print("\n" + "=" * 72)
    print("=== %s  (natural speech ONLY, no ESD) ===" % tag)
    print("  natural %s pos=%d (%.1f%%)" % (Xn.shape, yn.sum(),
                                            yn.mean() * 100))

    groups = np.unique(spkn)
    rng = np.random.RandomState(SEED)
    k = max(1, int(round(len(groups) * 0.25)))
    held = set(rng.permutation(groups)[:k].tolist())
    te = np.array([s in held for s in spkn])
    print("  speaker-disjoint: train %d / held-out %d (%d/%d speakers)"
          % (int((~te).sum()), int(te.sum()), len(held), len(groups)))

    mu, sd = Xn[~te].mean(0), Xn[~te].std(0) + 1e-8

    def Z(A):
        return ((A - mu) / sd).astype(np.float32)

    ytr = yn[~te]
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
    m = tf.keras.Sequential([
        tf.keras.Input(shape=(Xn.shape[1],), name="features"),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(1, activation="sigmoid", name="stress"),
    ], name=tag + "_v3_noesd")
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(Z(Xn[~te]), ytr, validation_data=(Z(Xn[te]), yn[te]),
          epochs=150, batch_size=128, verbose=0,
          class_weight={0: len(ytr) / (2.0 * max(nneg, 1)),
                        1: len(ytr) / (2.0 * max(npos, 1))},
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])

    pn = m.predict(Z(Xn[te]), verbose=0).ravel()
    a_nat = float(roc_auc_score(yn[te], pn))
    lo, hi = ci(yn[te], pn)
    out = {"natural_heldout": round(a_nat, 4),
           "natural_ci95": [round(lo, 4), round(hi, 4)],
           "n_train": int((~te).sum()), "dim": int(Xn.shape[1])}
    print("\n  natural held-out speakers %.4f  CI [%.4f, %.4f]"
          % (a_nat, lo, hi))

    if indep_path:
        Xi, yi, _ = load(indep_path)
        pi = m.predict(Z(Xi), verbose=0).ravel()
        a_i = float(roc_auc_score(yi, pi))
        ilo, ihi = ci(yi, pi)
        out["natural_independent"] = round(a_i, 4)
        out["natural_independent_ci95"] = [round(ilo, 4), round(ihi, 4)]
        print("  natural INDEPENDENT (%s) %.4f  CI [%.4f, %.4f]"
              % (os.path.basename(indep_path), a_i, ilo, ihi))

    # Acted, eval only, never trained on. Printed for continuity; it does
    # not gate, and diagnose.py is why.
    Xa, ya, _ = load(act_path)
    pa = m.predict(Z(Xa), verbose=0).ravel()
    a_act = float(roc_auc_score(ya, pa))
    out["acted_eval_only"] = round(a_act, 4)
    s_act, s_nat = SHIPPED[tag]
    print("  acted (eval only, does NOT gate) %.4f   shipped was %.4f"
          % (a_act, s_act))
    print("  shipped natural was %.4f" % s_nat)

    ship = bool(a_nat >= BAR_NATURAL and lo > 0.50)
    out["clears_natural_bar"] = ship
    print("  CLEARS natural>=%.2f and CI>0.50 -> %s" % (BAR_NATURAL, ship))
    if not ship:
        print("  NOT EXPORTED")
        return out

    conv = tf.lite.TFLiteConverter.from_keras_model(m)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.target_spec.supported_types = [tf.float16]
    blob = conv.convert()
    open(os.path.join(HERE, "%s_vocal_stress_v3_38.tflite" % tag),
         "wb").write(blob)
    json.dump({"mean": mu.tolist(), "std": sd.tolist()},
              open(os.path.join(HERE, "%s_vocal_stress_v3_38_norm.json"
                                % tag), "w"))
    out["float16_kb"] = round(len(blob) / 1024, 1)
    print("  exported %s_vocal_stress_v3_38.tflite (%s KB) + norm"
          % (tag, out["float16_kb"]))
    return out


def main():
    rep = {}
    rep["m4"] = build("m4",
                      os.path.join(WORK, "m4_m5_v2", "feat_meld_train.npz"),
                      os.path.join(WORK, "yin_lite", "yin_lite_feats.npz"),
                      indep_path=os.path.join(WORK, "m4_m5_crosscorpus",
                                              "feat_meld_yin.npz"))
    rep["m5"] = build("m5",
                      os.path.join(WORK, "m4_m5_v2", "feat_etalk.npz"),
                      os.path.join(WORK, "m5_mandarin", "features.npz"))
    json.dump(rep, open(os.path.join(HERE, "report.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
