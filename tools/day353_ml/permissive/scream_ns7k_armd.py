"""Day 368 - Nonspeech7k on top of the SHIPPED scream recipe (v5 arm D).

WHY THIS REPLACES scream_nonspeech7k.py
=======================================
That run trained on all 14,749 rows of features_v5.npz, which keeps the
Crying/Pant/Moan sources as POSITIVES. The shipped scream_classifier_v5 is
Day 346's arm D, which EXCLUDES them (13,960 rows). It also used Day 361E's
small network instead of v5's own model, augmentation and early stopping.
Its control therefore scored 0.790 against shipped 0.828, so the comparison
could not answer "does this beat what ships?". (Its paired result, kept in
scream_nonspeech7k_progress.jsonl, did show Nonspeech7k helping that recipe
on all three test sets, by +0.025, +0.044 and +0.073.)

THIS RUN
========
make_model and spec_augment are IMPORTED from work/scream_v5/train_scream_v5.py,
not copied, so the network and augmentation cannot drift from what shipped.
The fit is arm D's: crying sources dropped, 80/20 stratified split,
class weights, augmented copy appended, 45 epochs max, batch 64,
early stopping on val_auc (patience 8, restore best).

  A  control    arm D rows (reproduces the shipped composition)
  N  treatment  arm D rows + Nonspeech7k train (leak-filtered, crying excluded)

Three seeds each, interleaved A,N per seed, checkpointed after every fit.

SHIP RULE, FIXED BEFORE RUNNING (unchanged)
===========================================
N's worst seed >= shipped v5 on FSD50K eval, AND N's mean >= shipped on
AudioSet held-out and on Nonspeech7k test. Exported from the MEDIAN seed.
"""
from __future__ import annotations

import json
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
sys.path.insert(0, SV5)
sys.path.insert(0, HERE)

import train_scream_v5 as v5            # noqa: E402  make_model, spec_augment, CRY_SOURCES
import scream_nonspeech7k as ns          # noqa: E402  build() (cached features), tflite_scores

ASSETS = ns.ASSETS
SHIPPED = "scream_classifier_v5.tflite"
SEEDS = (42, 7, 123)
PROGRESS = os.path.join(HERE, "scream_ns7k_armd_progress.jsonl")
OUT = os.path.join(HERE, "scream_ns7k_armd.json")


def fit_arm_d(tf, X, y, seed):
    """Arm D's fit, line for line from train_scream_v5.main, seeded per run."""
    from sklearn.model_selection import train_test_split
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    rng = np.random.RandomState(seed)
    Xs = X.astype(np.float32)[..., None]
    Xtr, Xva, ytr, yva = train_test_split(Xs, y, test_size=0.2,
                                          random_state=seed, stratify=y)
    npos, nneg = int(ytr.sum()), int((1 - ytr).sum())
    cw = {0: len(ytr) / (2.0 * max(nneg, 1)), 1: len(ytr) / (2.0 * max(npos, 1))}
    model = v5.make_model(tf)
    aug = v5.spec_augment(Xtr, rng)
    model.fit(np.concatenate([Xtr, aug]), np.concatenate([ytr, ytr]),
              validation_data=(Xva, yva), epochs=v5.EPOCHS, batch_size=64,
              class_weight=cw, verbose=2,
              callbacks=[tf.keras.callbacks.EarlyStopping(
                  monitor="val_auc", mode="max", patience=8,
                  restore_best_weights=True)])
    return model


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    X, y, src = d["X"], d["y"].astype(int), np.asarray(d["src"])
    keep = ~np.isin(src, list(v5.CRY_SOURCES))
    Xd, yd = X[keep], y[keep]
    print(f"arm D rows {len(yd)} (pos {int(yd.sum())}) - expect 13960 / 2338", flush=True)

    Xn, yn, Xt, yt, info = ns.build()
    sets = {"fsd50k_eval": (d["Xf"], d["yf"].astype(int)),
            "audioset_heldout": (d["Xa"], d["ya"].astype(int)),
            "nonspeech7k_test": (Xt, yt)}
    shipped = {k: round(float(roc_auc_score(yy, ns.tflite_scores(
                   os.path.join(ASSETS, SHIPPED), XX))), 4) for k, (XX, yy) in sets.items()}
    print("shipped v5:", shipped, flush=True)

    arms = {"A_armD": (Xd, yd),
            "N_armD_plus_ns7k": (np.concatenate([Xd, Xn]), np.concatenate([yd, yn]))}
    done = {}
    if os.path.exists(PROGRESS):
        for line in open(PROGRESS, encoding="utf-8"):
            r = json.loads(line)
            done[(r["arm"], r["seed"])] = r["auc"]
    for s in SEEDS:
        for name, (Xa_, ya_) in arms.items():
            if (name, s) in done:
                print(f"{name} seed {s}: already done {done[(name, s)]}", flush=True)
                continue
            t0 = time.time()
            print(f"\n=== {name} seed {s}: n={len(ya_)} pos={int(ya_.sum())}", flush=True)
            m = fit_arm_d(tf, Xa_, ya_, s)
            auc = {k: round(float(roc_auc_score(
                       yy, m.predict(XX.astype(np.float32)[..., None], verbose=0).ravel())), 4)
                   for k, (XX, yy) in sets.items()}
            m.save(os.path.join(HERE, f"armd_{name}_seed{s}.keras"))
            with open(PROGRESS, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"arm": name, "seed": s, "auc": auc,
                                     "minutes": round((time.time() - t0) / 60, 1)}) + "\n")
            done[(name, s)] = auc
            print(f"{name} seed {s}: {auc}  ({(time.time()-t0)/60:.1f} min)", flush=True)

    res = {"shipped": shipped, "filter": info, "arms": {}}
    for name in arms:
        per = {k: [done[(name, s)][k] for s in SEEDS] for k in sets}
        res["arms"][name] = {k: {"seeds": v, "mean": round(float(np.mean(v)), 4),
                                 "min": round(float(np.min(v)), 4)} for k, v in per.items()}
    N = res["arms"]["N_armD_plus_ns7k"]
    ships = (N["fsd50k_eval"]["min"] >= shipped["fsd50k_eval"]
             and N["audioset_heldout"]["mean"] >= shipped["audioset_heldout"]
             and N["nonspeech7k_test"]["mean"] >= shipped["nonspeech7k_test"])
    res["ship_rule"] = ("worst seed >= shipped on FSD50K eval AND mean >= shipped "
                        "on AudioSet held-out and Nonspeech7k test")
    res["ships"] = bool(ships)
    print("\nSHIP ->", ships, flush=True)

    if ships:
        a = np.array(N["fsd50k_eval"]["seeds"])
        pick = SEEDS[int(np.argsort(a)[len(a) // 2])]      # median seed, not best
        m = tf.keras.models.load_model(os.path.join(HERE, f"armd_N_armD_plus_ns7k_seed{pick}.keras"))
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        path = os.path.join(HERE, "scream_classifier_v6_candidate.tflite")
        open(path, "wb").write(blob)
        res["exported"] = {"seed": pick, "kb": round(len(blob) / 1024, 1), "path": path,
                           "tflite_auc": {k: round(float(roc_auc_score(
                               yy, ns.tflite_scores(path, XX))), 4)
                               for k, (XX, yy) in sets.items()}}
        print("exported", res["exported"], flush=True)

    json.dump(res, open(OUT, "w"), indent=2)
    print("report ->", OUT, flush=True)


if __name__ == "__main__":
    main()
