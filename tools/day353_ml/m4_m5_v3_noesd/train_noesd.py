"""Day 352 - can m4/m5 drop ESD entirely and still clear the bars?

THE QUESTION
============
Day 350 flagged that `ESD_Dataset` declares cc-by-nc-4.0 (and its official
NUS/SUTD page states no licence at all, only a citation request), and it is
the acted half of both shipped vocal-stress models. No permissive
replacement exists on any drive: ai4ser is 3,500 clips but Italian, huma is
cc-by-4.0 but sixteen files.

That leaves a decision nobody can make from a licence table alone. But part
of it IS decidable by measurement: **how much does ESD actually buy?** If
natural speech alone clears the Day 350 bars, the NC exposure can be
removed by deleting a corpus rather than by acquiring one.

    m4  MELD train 8,106 natural  (drop ESD English 3,400)
    m5  EmotionTalk 14,000 natural (drop ESD Mandarin 3,400)

WHAT THIS DOES AND DOES NOT RESOLVE
===================================
It removes the *NC* exposure specifically. It does **not** make the training
data clean: MELD states no licence and is extracted from copyrighted
broadcast, and EmotionTalk ships with no card at all. Those are separate
questions and are not answered here.

THE BARS ARE THE DAY 350 ONES, UNCHANGED
========================================
    natural >= 0.60 with a bootstrap CI excluding 0.50
    acted   >= 0.70 on held-out ESD speakers

Note the second bar still uses ESD as an EVALUATION set even when ESD is
dropped from training. Measuring against it is not the same as training on
it, and it is the only acted benchmark that makes the v1/v2 comparison
meaningful. If the licence position is that ESD cannot be touched at all,
that number simply goes away -- the natural one is unaffected.

A natural-only model that fails the acted bar has not solved the licence
problem, it has traded a legal risk for a capability loss, and that is a
different decision. Both numbers are reported either way.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
ROOT = r"C:\Users\hridy\Desktop\zapsafe"
MODELS = os.path.join(ROOT, r"letsstartbuilding\zapsafe_mobile_main_reconcile"
                            r"\assets\models")
SEED = 42
AVAIL = list(range(7, 33)) + [36, 37]
M4_HELD = {"0012", "0016", "0019"}

# Day 350 shipped numbers, for reference in the printout.
SHIPPED = {"m4": (0.7738, 0.6235), "m5": (0.7873, 0.7810)}   # acted, natural


def load(p):
    d = np.load(p, allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, d["y"], (d["spk"] if "spk" in d.files else None)


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


def arm(tag, Xn, yn, spkn, Xa, ya, spka, held_acted, dim, sel):
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    tf.random.set_seed(SEED)
    np.random.seed(SEED)
    if sel is not None:
        Xn, Xa = Xn[:, sel], Xa[:, sel]

    # natural split by speaker/group; acted is EVAL ONLY, never trained on
    groups = np.unique(spkn)
    rng = np.random.RandomState(SEED)
    k = max(1, int(round(len(groups) * 0.25)))
    held = set(rng.permutation(groups)[:k].tolist())
    te = np.array([s in held for s in spkn])
    a_te = np.array([str(s) in held_acted for s in spka])

    print(f"\n{'='*64}\n=== {tag} (natural speech ONLY, no ESD) ===")
    print(f"  natural train {int((~te).sum())} / held-out {int(te.sum())} "
          f"({len(held)} of {len(groups)} speakers/groups)")
    print(f"  acted is EVAL ONLY: {int(a_te.sum())} clips, never trained on")

    mean, std = Xn[~te].mean(axis=0), Xn[~te].std(axis=0) + 1e-8
    Z = lambda A: ((A - mean) / std).astype(np.float32)
    ytr = yn[~te]
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())

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
    pa = m.predict(Z(Xa[a_te]), verbose=0).ravel()
    a_nat = float(roc_auc_score(yn[te], pn))
    a_act = float(roc_auc_score(ya[a_te], pa))
    lo, hi = ci(yn[te], pn)
    s_act, s_nat = SHIPPED[tag]

    print(f"\n  no-ESD   acted {a_act:.4f}   natural {a_nat:.4f}")
    print(f"           natural 95% CI [{lo:.4f}, {hi:.4f}]")
    print(f"  shipped  acted {s_act:.4f}   natural {s_nat:.4f}")
    print(f"  delta    acted {a_act-s_act:+.4f}   natural {a_nat-s_nat:+.4f}")

    ship = bool(a_nat >= 0.60 and lo > 0.50 and a_act >= 0.70)
    print(f"  CLEARS BARS (natural>=0.60 & CI>0.50 & acted>=0.70) -> {ship}")
    if not ship:
        print("  -> dropping ESD costs capability; this is a trade, not a fix")

    out = {"noesd_acted": round(a_act, 4), "noesd_natural": round(a_nat, 4),
           "noesd_natural_ci95": [round(lo, 4), round(hi, 4)],
           "shipped_acted": s_act, "shipped_natural": s_nat,
           "delta_acted": round(a_act - s_act, 4),
           "delta_natural": round(a_nat - s_nat, 4),
           "n_natural_train": int((~te).sum()), "clears_bars": ship}
    if ship:
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, f"{tag}_noesd_float16.tflite"),
             "wb").write(blob)
        json.dump({"mean": mean.tolist(), "std": std.tolist()},
                  open(os.path.join(HERE, f"{tag}_noesd_norm.json"), "w"))
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print(f"  exported ({out['float16_kb']} KB)")
    return out


def main():
    rep = {}
    Xa4, ya4, spka4 = load(os.path.join(WORK, "yin_lite",
                                        "yin_lite_feats.npz"))
    Xn4, yn4, spkn4 = load(os.path.join(WORK, "m4_m5_v2",
                                        "feat_meld_train.npz"))
    rep["m4"] = arm("m4", Xn4, yn4, spkn4, Xa4, ya4, spka4, M4_HELD, 38, None)

    Xa5, ya5, spka5 = load(os.path.join(WORK, "m5_mandarin", "features.npz"))
    held5 = set(sorted(np.unique(spka5).tolist())[:3])
    Xn5, yn5, spkn5 = load(os.path.join(WORK, "m4_m5_v2", "feat_etalk.npz"))
    rep["m5"] = arm("m5", Xn5, yn5, spkn5, Xa5, ya5, spka5, held5, 28, AVAIL)

    json.dump(rep, open(os.path.join(HERE, "report.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
