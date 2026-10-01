"""ZapSafe Day 368 - scream v5 arm D +/- Nonspeech7k, on a Kaggle GPU.

Same experiment as tools/day353_ml/permissive/scream_ns7k_armd.py, moved off
a CPU where one model took 1.5-3 h. The network and augmentation are
IMPORTED from the uploaded train_scream_v5.py, not copied.

  A  control    v5 arm D rows (crying/pant/moan sources excluded) - the
                shipped composition
  N  treatment  arm D rows + Nonspeech7k train (leak-filtered by Freesound
                id against FSD50K eval and dev; crying excluded)

Three seeds per arm, 45 epochs max, batch 64, early stopping on val_auc
(patience 8, restore best) - arm D's fit.

Ship rule, fixed before running: N's worst seed >= shipped v5 on FSD50K eval,
AND N's mean >= shipped on AudioSet held-out and on Nonspeech7k test.
Exported from the MEDIAN seed. A paired bootstrap of (exported - shipped)
on FSD50K eval is reported alongside, so a narrow win is not over-read.
"""
import glob
import json
import os
import sys
import time

import numpy as np

IN = os.path.dirname(glob.glob("/kaggle/input/**/features_v5.npz", recursive=True)[0])
OUT = "/kaggle/working"
sys.path.insert(0, IN)
import train_scream_v5 as v5            # noqa: E402

import tensorflow as tf                  # noqa: E402
from sklearn.metrics import roc_auc_score             # noqa: E402
from sklearn.model_selection import train_test_split  # noqa: E402

print("TF", tf.__version__, "GPUs:", tf.config.list_physical_devices("GPU"), flush=True)
SEEDS = (42, 7, 123)


def tflite_scores(path, X):
    it = tf.lite.Interpreter(model_path=path)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    p = np.zeros(len(X))
    for k in range(len(X)):
        it.set_tensor(i0["index"], X[k:k + 1].astype(np.float32).reshape(shape))
        it.invoke()
        p[k] = float(it.get_tensor(o0["index"]).ravel()[0])
    return p


def fit_arm_d(X, y, seed):
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
    d = np.load(os.path.join(IN, "features_v5.npz"), allow_pickle=True)
    X, y, src = d["X"], d["y"].astype(int), np.asarray(d["src"])
    keep = ~np.isin(src, list(v5.CRY_SOURCES))
    Xd, yd = X[keep], y[keep]
    print(f"arm D rows {len(yd)} pos {int(yd.sum())} (expect 13960 / 2338)", flush=True)
    assert len(yd) == 13960 and int(yd.sum()) == 2338, "arm D composition mismatch"

    n = np.load(os.path.join(IN, "nonspeech7k_features.npz"))
    Xn, yn, Xt, yt = n["Xn"], n["yn"].astype(int), n["Xt"], n["yt"].astype(int)
    info = json.loads(str(n["info"]))
    print(f"Nonspeech7k train {len(yn)} (pos {int(yn.sum())}), test {len(yt)} "
          f"(pos {int(yt.sum())}); filter {info}", flush=True)

    sets = {"fsd50k_eval": (d["Xf"], d["yf"].astype(int)),
            "audioset_heldout": (d["Xa"], d["ya"].astype(int)),
            "nonspeech7k_test": (Xt, yt)}
    ship_path = os.path.join(IN, "scream_classifier_v5.tflite")
    ship_p = {k: tflite_scores(ship_path, XX) for k, (XX, _) in sets.items()}
    shipped = {k: round(float(roc_auc_score(sets[k][1], ship_p[k])), 4) for k in sets}
    print("shipped v5:", shipped, flush=True)

    arms = {"A_armD": (Xd, yd),
            "N_armD_plus_ns7k": (np.concatenate([Xd, Xn]), np.concatenate([yd, yn]))}
    done, preds = {}, {}
    for s in SEEDS:
        for name, (Xa_, ya_) in arms.items():
            t0 = time.time()
            print(f"\n=== {name} seed {s}: n={len(ya_)} pos={int(ya_.sum())}", flush=True)
            m = fit_arm_d(Xa_, ya_, s)
            p = {k: m.predict(XX.astype(np.float32)[..., None], verbose=0).ravel()
                 for k, (XX, _) in sets.items()}
            auc = {k: round(float(roc_auc_score(sets[k][1], p[k])), 4) for k in sets}
            done[(name, s)], preds[(name, s)] = auc, p
            m.save(os.path.join(OUT, f"armd_{name}_seed{s}.keras"))
            with open(os.path.join(OUT, "progress.jsonl"), "a") as fh:
                fh.write(json.dumps({"arm": name, "seed": s, "auc": auc,
                                     "minutes": round((time.time() - t0) / 60, 1)}) + "\n")
            print(f"{name} seed {s}: {auc} ({(time.time()-t0)/60:.1f} min)", flush=True)

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

    # Paired bootstrap on the fixture: median-seed N vs shipped, and N vs A (same seed).
    a = np.array(N["fsd50k_eval"]["seeds"])
    pick = SEEDS[int(np.argsort(a)[len(a) // 2])]
    yf = sets["fsd50k_eval"][1]
    pN = preds[("N_armD_plus_ns7k", pick)]["fsd50k_eval"]
    pA = preds[("A_armD", pick)]["fsd50k_eval"]
    rng = np.random.RandomState(0)
    dS, dA = [], []
    for _ in range(2000):
        i = rng.randint(0, len(yf), len(yf))
        if len(set(yf[i].tolist())) < 2:
            continue
        aN = roc_auc_score(yf[i], pN[i])
        dS.append(aN - roc_auc_score(yf[i], ship_p["fsd50k_eval"][i]))
        dA.append(aN - roc_auc_score(yf[i], pA[i]))
    res["bootstrap_fsd50k"] = {
        "median_seed": pick,
        "N_minus_shipped_ci95": [round(float(x), 4) for x in np.percentile(dS, [2.5, 97.5])],
        "P_N_better_than_shipped": round(float((np.array(dS) > 0).mean()), 3),
        "N_minus_A_ci95": [round(float(x), 4) for x in np.percentile(dA, [2.5, 97.5])],
        "P_N_better_than_A": round(float((np.array(dA) > 0).mean()), 3),
    }
    print("\nSHIP ->", ships, res["bootstrap_fsd50k"], flush=True)

    if ships:
        m = tf.keras.models.load_model(os.path.join(OUT, f"armd_N_armD_plus_ns7k_seed{pick}.keras"))
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        path = os.path.join(OUT, "scream_classifier_v6_candidate.tflite")
        open(path, "wb").write(blob)
        res["exported"] = {"seed": pick, "kb": round(len(blob) / 1024, 1),
                           "tflite_auc": {k: round(float(roc_auc_score(
                               sets[k][1], tflite_scores(path, sets[k][0]))), 4)
                               for k in sets}}
        print("exported", res["exported"], flush=True)

    json.dump(res, open(os.path.join(OUT, "scream_ns7k_armd_result.json"), "w"), indent=2)
    print(json.dumps(res, indent=2), flush=True)


main()
