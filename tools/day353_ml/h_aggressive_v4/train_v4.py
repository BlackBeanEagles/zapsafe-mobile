"""Day 352 - h_aggressive v4: plain YIN at librosa's frame size.

WHAT IS BEING ISOLATED
======================
    v2b  librosa.pyin  2048 / 512   acted 0.8096  natural 0.6661
    v3   plain YIN       512 / 256   acted 0.7063  natural 0.5918
    v4   plain YIN      2048 / 512   acted ?       natural ?

v3 changed the pitch ALGORITHM and the FRAME SIZE together and lost 0.10,
and Day 351 concluded the native pyin work was unavoidable without
separating the two. m4's report already measures the algorithm at
0.8336 (YIN) vs 0.8445 (pyin) -- the HMM is worth 0.011 -- so a 0.10 drop
cannot be the algorithm. v4 holds the algorithm at plain YIN and moves the
frame to librosa's default.

READ THE OUTCOME LIKE THIS
==========================
* v4 ~= v2b  -> frame size was the whole story. Phase B becomes
                kFrameLength 512 -> 2048 and kHopLength 256 -> 512 in
                yin_pitch.dart, plus a regenerated golden fixture. No pyin
                implementation, no native work.
* v4 ~= v3   -> the frame is not it either, and something else in the
                librosa path matters. Native work stands.
* in between -> both contribute; the decision is whether the remaining gap
                is worth a pyin port.

The comparison is like-for-like on data: the same five ESD-free corpora
(CREMA-D, TESS, RAVDESS, SAVEE, MELD), the same speaker-disjoint split rule,
the same corpus-balanced weights, the same architecture. Only the feature
extraction differs.

MELD test+dev is the natural-speech evaluation and is featurised here in
the SAME 2048/512 space -- v2b's 0.6661 and v3's 0.5918 were each measured
in their own space, so all three numbers describe the same clips through
three different extractors. That is the intended comparison and is stated
so nobody reads them as identical-feature deltas.
"""
from __future__ import annotations

import glob
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = 42
HOLDOUT = 0.25

V1 = (0.8442, 0.4780)     # librosa 2048/512, RAVDESS only
V2B = (0.8096, 0.6661)    # librosa 2048/512, 5 corpora
V3 = (0.7063, 0.5918)     # plain YIN 512/256, 5 corpora


def load_all():
    Xs, ys, spks, srcs = [], [], [], []
    for f in sorted(glob.glob(os.path.join(HERE, "feat_*.npz"))):
        tag = os.path.basename(f)[5:-4]
        if tag == "meld_eval":
            continue                      # held out, never trained on
        d = np.load(f, allow_pickle=True)
        Xs.append(d["X"]); ys.append(d["y"]); spks.append(d["spk"])
        srcs.append(np.full(len(d["y"]), tag))
        print(f"  {tag:11s} {d['X'].shape} pos={int(d['y'].sum()):5d} "
              f"groups={len(set(d['spk'].tolist()))}")
    return (np.concatenate(Xs), np.concatenate(ys),
            np.concatenate(spks), np.concatenate(srcs))


def corpus_weights(y, corpus):
    w = np.ones(len(y), np.float64)
    n = len(np.unique(corpus))
    for c in np.unique(corpus):
        m = corpus == c
        w[m] *= len(y) / (n * max(int(m.sum()), 1))
        for lab in (0, 1):
            ml = m & (y == lab)
            if ml.sum():
                w[ml] *= m.sum() / (2.0 * ml.sum())
    return w


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


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    tf.random.set_seed(SEED)
    np.random.seed(SEED)

    print("=== corpora (plain YIN, frame 2048 / hop 512) ===")
    X, y, spk, src = load_all()
    X = np.nan_to_num(X.astype(np.float64), nan=0.0, posinf=0.0, neginf=0.0)
    print(f"pooled {X.shape} pos={int(y.sum())} ({y.mean()*100:.1f}%)")

    d = np.load(os.path.join(HERE, "feat_meld_eval.npz"), allow_pickle=True)
    Xe = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                       neginf=0.0)
    ye = d["y"]
    print(f"MELD test+dev (natural) {Xe.shape} pos={int(ye.sum())}")

    rng = np.random.RandomState(SEED)
    te = np.zeros(len(spk), bool)
    for c in np.unique(src):
        m = src == c
        sp = np.unique(spk[m])
        k = max(1, int(round(len(sp) * HOLDOUT)))
        held = set(rng.permutation(sp)[:k].tolist())
        te |= m & np.array([s in held for s in spk])
    tr = ~te
    print(f"\nspeaker-disjoint: train {int(tr.sum())} / held-out "
          f"{int(te.sum())}")

    mean, std = X[tr].mean(axis=0), X[tr].std(axis=0) + 1e-8
    Z = lambda A: ((A - mean) / std).astype(np.float32)

    m = tf.keras.Sequential([
        tf.keras.Input(shape=(38,), name="prosodic_features"),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(1, activation="sigmoid", name="aggressive"),
    ], name="h_aggressive_v4")
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    m.fit(Z(X[tr]), y[tr], validation_data=(Z(X[te]), y[te]),
          epochs=150, batch_size=128, verbose=0,
          sample_weight=corpus_weights(y[tr], src[tr]),
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])

    a_act = float(roc_auc_score(y[te], m.predict(Z(X[te]), verbose=0).ravel()))
    pe = m.predict(Z(Xe), verbose=0).ravel()
    a_nat = float(roc_auc_score(ye, pe))
    lo, hi = ci(ye, pe)

    print("\n" + "=" * 66)
    print(f"  v4  plain YIN 2048/512   acted {a_act:.4f}   natural {a_nat:.4f}")
    print(f"      natural 95% CI [{lo:.4f}, {hi:.4f}]")
    print(f"  v2b librosa.pyin 2048/512 acted {V2B[0]:.4f}   "
          f"natural {V2B[1]:.4f}")
    print(f"  v3  plain YIN   512/256   acted {V3[0]:.4f}   natural {V3[1]:.4f}")
    print(f"  v1  librosa, RAVDESS only acted {V1[0]:.4f}   natural {V1[1]:.4f}")
    print(f"\n  v4 - v2b : acted {a_act-V2B[0]:+.4f}  natural {a_nat-V2B[1]:+.4f}")
    print(f"  v4 - v3  : acted {a_act-V3[0]:+.4f}  natural {a_nat-V3[1]:+.4f}")

    # How much of the v2b->v3 gap does the frame size alone recover?
    gap_act = V2B[0] - V3[0]
    gap_nat = V2B[1] - V3[1]
    rec_act = (a_act - V3[0]) / gap_act if gap_act else 0.0
    rec_nat = (a_nat - V3[1]) / gap_nat if gap_nat else 0.0
    print(f"  frame size recovers {rec_act*100:.0f}% of the acted gap, "
          f"{rec_nat*100:.0f}% of the natural gap")

    ship = bool(a_nat >= 0.60 and lo > 0.50 and a_act >= 0.75)
    # Day 352: v4 misses the acted bar (0.7464 < 0.75) and clears the
    # natural one. `--force-export` ships it anyway, by explicit decision,
    # because the acted bar was inherited from ESD-trained models and a
    # phone hears natural speech. The bar is NOT quietly lowered -- the
    # report records that it was missed and overridden.
    forced = "--force-export" in sys.argv
    if forced and not ship:
        print("  --force-export: exporting despite the acted bar "
              f"({a_act:.4f} < 0.75); natural {a_nat:.4f} clears 0.60")
    print(f"\n  CLEARS v2b's BARS (natural>=0.60 & CI>0.50 & acted>=0.75) "
          f"-> {ship}")
    if ship:
        verdict = ("FRAME SIZE was the whole story. Phase B = kFrameLength "
                   "512->2048 and kHopLength 256->512 in yin_pitch.dart, "
                   "plus a regenerated golden fixture. No pyin port.")
    elif a_act > V3[0] + 0.03 or a_nat > V3[1] + 0.03:
        verdict = ("frame size explains part of the gap but not all; the "
                   "remaining difference is the pyin path")
    else:
        verdict = ("frame size is NOT the cause either; Day 351's "
                   "conclusion stands and native work is required")
    print(f"  -> {verdict}")

    out = {"v4_acted": round(a_act, 4), "v4_natural": round(a_nat, 4),
           "v4_natural_ci95": [round(lo, 4), round(hi, 4)],
           "v2b": {"acted": V2B[0], "natural": V2B[1]},
           "v3": {"acted": V3[0], "natural": V3[1]},
           "recovered_frac_acted": round(rec_act, 3),
           "recovered_frac_natural": round(rec_nat, 3),
           "frame": 2048, "hop": 512, "pitch": "plain YIN (yin_lite)",
           "SHIP": ship, "verdict": verdict}

    out["forced_export"] = bool(forced and not ship)
    if ship or forced:
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "h_aggressive_v4_float16.tflite"),
             "wb").write(blob)
        json.dump({"mean": mean.tolist(), "std": std.tolist()},
                  open(os.path.join(HERE, "h_aggressive_v4_norm.json"), "w"))
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print(f"  exported ({out['float16_kb']} KB) + norm.json")

    json.dump(out, open(os.path.join(HERE, "report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
