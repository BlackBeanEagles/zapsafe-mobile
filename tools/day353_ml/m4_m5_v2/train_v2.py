"""Day 350 - m4 and m5 v2: acted + natural speech.

WHAT IS BEING FIXED
===================
Day 349 measured both shipped models at chance the moment the recording
situation changed:

    m4_vocal_stress_en_38   held-out ESD speakers 0.8321 -> MELD        0.4813
    m5_vocal_stress_v2      held-out ESD speakers 0.7988 -> EmotionTalk 0.4865

Held-out *speaker* was not the problem and never caught it -- m5's own
report records 0.9984 on seen speakers vs 0.7988 held-out, a properly run
control that predicted nothing. Corpus was the confound.

Day 348 established the fix on h_aggressive: adding natural speech moved it
0.4780 -> 0.6661 against a 0.6832 ceiling, for a 0.035 cost on acted
speech. This applies the same treatment.

    m4  ESD English (3,400 acted)  +  MELD train (8,106 natural)
    m5  ESD Mandarin (3,400 acted) +  EmotionTalk (14,000 natural)

SUCCESS CRITERIA, FIXED BEFORE LOOKING
======================================
    natural-speech AUC >= 0.60 with a bootstrap CI excluding 0.50
    in-corpus (held-out acted speakers) >= 0.70

The second half is not optional. A model that reaches 0.66 on natural
speech by giving away acted speech has moved the failure, not fixed it, and
0.70 is the floor m5's own report used ("clears_ship_floor_070").

THE EVALUATION ROWS ARE THE DAY 349 ONES
========================================
m4 is scored on `m4_m5_crosscorpus/feat_meld_yin.npz` -- the identical 3,047
MELD test+dev rows v1 scored 0.4813 on. MELD's train split is disjoint from
test+dev by the dataset's own design and was featurised separately here.

m5 cannot reuse Day 349's cached rows: that run saved only X and y, so
speaker is unrecoverable and no speaker-disjoint split can be built from it.
EmotionTalk was therefore re-collected with group ids (14,000 clips, 13
conversation groups) and is split BY GROUP. Conversational audio shares
voice, room and mic within a dialogue, so a random split would leak.

That means m5's v1-vs-v2 comparison is on different rows, and the v1
baseline is re-measured here on the new held-out groups rather than quoted
from Day 349. Stated plainly because it is a real asymmetry with m4.
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
AVAIL = list(range(7, 33)) + [36, 37]          # the 28 features Dart can do

# Deterministic seed-42 held-out ESD speakers, from the training scripts.
M4_HELD = {"0012", "0016", "0019"}


def load(p, allow_no_spk=False):
    d = np.load(p, allow_pickle=True)
    spk = d["spk"] if "spk" in d.files else None
    if spk is None and not allow_no_spk:
        raise SystemExit(f"{p} has no speaker array")
    X = np.nan_to_num(d["X"].astype(np.float64), nan=0.0, posinf=0.0,
                      neginf=0.0)
    return X, d["y"], spk


def corpus_weights(ytr, corpus):
    """Equal TOTAL weight per corpus, class-balanced within each.

    m5 v2b's first run gave natural speech 82% of the training rows
    (11,157 EmotionTalk vs 2,380 ESD) and the acted number collapsed from
    0.7988 to 0.5989 -- it moved the failure rather than fixing it. A single
    pooled `class_weight` cannot see that, because the imbalance is between
    CORPORA, not between classes.

    So each corpus contributes the same total weight regardless of its size,
    and within a corpus the two classes are balanced. Capping the larger
    corpus instead would throw away most of EmotionTalk; weighting keeps
    every row and still stops one corpus dominating the loss.
    """
    w = np.ones(len(ytr), dtype=np.float64)
    for c in np.unique(corpus):
        m = corpus == c
        w[m] *= len(ytr) / (len(np.unique(corpus)) * max(int(m.sum()), 1))
        for lab in (0, 1):
            ml = m & (ytr == lab)
            if ml.sum():
                w[ml] *= m.sum() / (2.0 * ml.sum())
    return w


def fit(tf, Xtr, ytr, Xva, yva, dim, sw=None):
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
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
    kw = {"sample_weight": sw} if sw is not None else {
        "class_weight": {0: len(ytr) / (2.0 * max(nneg, 1)),
                         1: len(ytr) / (2.0 * max(npos, 1))}}
    m.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=150, batch_size=128,
          verbose=0, **kw,
          callbacks=[tf.keras.callbacks.EarlyStopping(
              monitor="val_auc", mode="max", patience=20,
              restore_best_weights=True),
              tf.keras.callbacks.ReduceLROnPlateau(
                  monitor="val_auc", mode="max", factor=0.5, patience=8)])
    return m


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


def tflite_scores(path, Xn, dim):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_path=path)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    out = []
    for s in range(0, len(Xn), 256):
        ch = Xn[s:s + 256].astype(np.float32)
        it.resize_tensor_input(i0["index"], [len(ch), dim])
        it.allocate_tensors()
        it.set_tensor(i0["index"], ch)
        it.invoke()
        r = np.ravel(it.get_tensor(o0["index"])).astype(np.float64)
        assert len(r) == len(ch)
        out.append(r)
    return np.concatenate(out)


def arm(tag, Xa, ya, spka, held_acted, Xn, yn, spkn, dim, sel,
        v1_path, v1_natural_recorded):
    """One model. Returns the report dict."""
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    tf.random.set_seed(SEED)
    np.random.seed(SEED)

    if sel is not None:
        Xa, Xn = Xa[:, sel], Xn[:, sel]

    # acted: the model's own deterministic held-out speakers
    a_te = np.array([str(s) in held_acted for s in spka])
    # natural: hold out groups, 25% by count, deterministic
    groups = np.unique(spkn)
    rng = np.random.RandomState(SEED)
    k = max(1, int(round(len(groups) * 0.25)))
    heldn = set(rng.permutation(groups)[:k].tolist())
    n_te = np.array([s in heldn for s in spkn])

    print(f"\n{'='*66}\n=== {tag} ===")
    print(f"  acted   {Xa.shape}  train {int((~a_te).sum())} / "
          f"held-out-speaker {int(a_te.sum())}  (speakers {sorted(held_acted)})")
    print(f"  natural {Xn.shape}  train {int((~n_te).sum())} / "
          f"held-out-group {int(n_te.sum())}  "
          f"({len(heldn)} of {len(groups)} groups)")

    Xtr = np.concatenate([Xa[~a_te], Xn[~n_te]])
    ytr = np.concatenate([ya[~a_te], yn[~n_te]])
    corpus = np.concatenate([np.full(int((~a_te).sum()), "acted"),
                             np.full(int((~n_te).sum()), "natural")])
    Xva = np.concatenate([Xa[a_te], Xn[n_te]])
    yva = np.concatenate([ya[a_te], yn[n_te]])
    print(f"  pooled train {Xtr.shape} pos={int(ytr.sum())} "
          f"({ytr.mean()*100:.1f}%)")

    mean = Xtr.mean(axis=0)
    std = Xtr.std(axis=0) + 1e-8
    Z = lambda A: ((A - mean) / std).astype(np.float32)

    sw = corpus_weights(ytr, corpus)
    print(f"  corpus-balanced weights: acted sum "
          f"{sw[corpus=='acted'].sum():.0f}  natural sum "
          f"{sw[corpus=='natural'].sum():.0f}")
    m = fit(tf, Z(Xtr), ytr, Z(Xva), yva, dim, sw=sw)
    p_act = m.predict(Z(Xa[a_te]), verbose=0).ravel()
    p_nat = m.predict(Z(Xn[n_te]), verbose=0).ravel()
    a_act = float(roc_auc_score(ya[a_te], p_act))
    a_nat = float(roc_auc_score(yn[n_te], p_nat))
    lo, hi = ci(yn[n_te], p_nat)
    sep = float(p_nat[yn[n_te] == 1].mean() - p_nat[yn[n_te] == 0].mean())

    # v1 on the SAME natural held-out rows, using its own norm
    v1norm = json.load(open(v1_path.replace(".tflite", "_norm.json")))
    v1m = np.asarray(v1norm["mean"], np.float32)
    v1s = np.asarray(v1norm["std"], np.float32)
    p_v1 = tflite_scores(v1_path, (Xn[n_te] - v1m) / (v1s + 1e-8), dim)
    a_v1 = float(roc_auc_score(yn[n_te], p_v1))

    print(f"\n  v1 on these natural rows     {a_v1:.4f}   "
          f"(Day 349 recorded {v1_natural_recorded})")
    print(f"  v2 natural (held-out group)  {a_nat:.4f}   "
          f"delta {a_nat-a_v1:+.4f}")
    print(f"     95% CI [{lo:.4f}, {hi:.4f}]   separation {sep:+.4f}")
    print(f"  v2 acted (held-out speaker)  {a_act:.4f}")

    ship = bool(a_nat >= 0.60 and lo > 0.50 and a_act >= 0.70)
    print(f"  SHIP  natural>=0.60 & CI>0.50 & acted>=0.70  ->  {ship}")

    rep = {"v1_natural_same_rows": round(a_v1, 4),
           "v1_natural_recorded_day349": v1_natural_recorded,
           "v2_natural": round(a_nat, 4), "v2_acted": round(a_act, 4),
           "delta_vs_v1": round(a_nat - a_v1, 4),
           "natural_ci95": [round(lo, 4), round(hi, 4)],
           "natural_separation": round(sep, 4),
           "n_train": int(len(ytr)), "n_natural_test": int(n_te.sum()),
           "n_acted_test": int(a_te.sum()),
           "held_out_groups": sorted(heldn), "SHIP": ship}

    if ship:
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, f"{tag}_float16.tflite"), "wb").write(blob)
        json.dump({"mean": mean.tolist(), "std": std.tolist()},
                  open(os.path.join(HERE, f"{tag}_norm.json"), "w"))
        rep["float16_kb"] = round(len(blob) / 1024, 1)
        print(f"  exported ({rep['float16_kb']} KB) + norm.json")
    else:
        print("  NOT exported")
    return rep


def main():
    out = {}

    # ---- m4: English, full 38-dim yin_lite vector -------------------
    Xa, ya, spka = load(os.path.join(WORK, "yin_lite", "yin_lite_feats.npz"))
    Xn, yn, spkn = load(os.path.join(HERE, "feat_meld_train.npz"))
    # m4's natural EVAL is Day 349's exact rows; MELD train is disjoint from
    # test+dev by dataset design, so the group split below only guards the
    # in-training validation signal.
    out["m4_vocal_stress_v2"] = arm(
        "m4_vocal_stress_v2", Xa, ya, spka, M4_HELD, Xn, yn, spkn,
        38, None, os.path.join(MODELS, "m4_vocal_stress_en_38.tflite"),
        0.4813)

    # Also score m4 v2 on the untouched Day 349 MELD test+dev rows, so the
    # headline is on identical rows to v1's 0.4813.
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score
    ev = np.load(os.path.join(WORK, "m4_m5_crosscorpus",
                              "feat_meld_yin.npz"), allow_pickle=True)
    Xev = np.nan_to_num(ev["X"].astype(np.float64), nan=0.0, posinf=0.0,
                        neginf=0.0)
    yev = ev["y"]
    nj = json.load(open(os.path.join(HERE, "m4_vocal_stress_v2_norm.json"))) \
        if os.path.exists(os.path.join(HERE,
                                       "m4_vocal_stress_v2_norm.json")) else None
    if nj:
        mm = np.asarray(nj["mean"]); ss = np.asarray(nj["std"])
        p = tflite_scores(os.path.join(HERE, "m4_vocal_stress_v2_float16.tflite"),
                          (Xev - mm) / ss, 38)
        a = float(roc_auc_score(yev, p))
        lo, hi = ci(yev, p)
        print(f"\n  m4 v2 on Day 349's EXACT MELD test+dev rows: {a:.4f} "
              f"CI [{lo:.4f}, {hi:.4f}]  (v1 was 0.4813)")
        out["m4_vocal_stress_v2"]["day349_identical_rows_auc"] = round(a, 4)
        out["m4_vocal_stress_v2"]["day349_identical_rows_ci"] = [
            round(lo, 4), round(hi, 4)]

    # ---- m5: Mandarin, 28 of the 38 ---------------------------------
    Xa5, ya5, spka5 = load(os.path.join(WORK, "m5_mandarin", "features.npz"))
    held5 = set(sorted(np.unique(spka5).tolist())[:3])
    # spk is now the REAL speaker_id, recovered by recover_speakers.py.
    # 10 of 15 EmotionTalk speakers recur across conversation groups, so the
    # first run's group-level holdout was not speaker-disjoint and its
    # natural AUC of 0.7969 was inflated.
    Xn5, yn5, spkn5 = load(os.path.join(HERE, "feat_etalk.npz"))
    out["m5_vocal_stress_v2b"] = arm(
        "m5_vocal_stress_v2b", Xa5, ya5, spka5, held5, Xn5, yn5, spkn5,
        28, AVAIL, os.path.join(MODELS, "m5_vocal_stress_v2.tflite"), 0.4865)

    # ---- m5 with ALL 38 features ------------------------------------
    # m5 v2b fails the acted floor (0.6294 vs the 0.70 required) while
    # scoring 0.7804 on natural Mandarin. m4 manages BOTH (0.7922 acted /
    # 0.6230 natural) and the obvious structural difference is that m4 uses
    # the full 38-dim vector while m5 uses only 28 -- it drops pitch,
    # shimmer, HNR and the RMS series because Dart cannot compute them.
    #
    # So: can the full vector do what the 28 cannot? If yes, the Mandarin
    # tradeoff is a FEATURE limitation, not a language one, and the wiring
    # cost of pitch in Dart becomes a decision worth having. If no, the
    # tradeoff is real and m5 stays as it is.
    #
    # Note the 38-feature Mandarin model failed before at 0.4286 (Day 348)
    # -- but that was ESD-only, with no natural speech at all.
    out["m5_vocal_stress_38_natural"] = arm(
        "m5_vocal_stress_38_natural", Xa5, ya5, spka5, held5,
        Xn5, yn5, spkn5, 38, None,
        os.path.join(MODELS, "m4_vocal_stress_en_38.tflite"), 0.4865)

    json.dump(out, open(os.path.join(HERE, "report.json"), "w"), indent=2)
    print("\nreport written")


if __name__ == "__main__":
    main()
