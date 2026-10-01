"""Day 368C - the pre-registered decision for scream + Nonspeech7k over 10 seeds.

THIS RULE WAS COMMITTED BEFORE THE 7 NEW SEEDS WERE RUN.

Day 368B ran 3 seeds and missed its rule (worst seed >= shipped on FSD50K)
by 0.0008, with a bootstrap CI that included zero. Running more seeds after
a near-miss is how "re-roll until it passes" happens, so the rule for the
extended run is fixed here first, along with WHY the old one is replaced:

  * "Worst seed >= shipped" does not scale with the number of seeds. The
    minimum of 10 draws is lower than the minimum of 3 by sampling alone.
  * The shipped model is itself ONE draw of the control recipe. The control
    mean over 3 seeds is 0.8234 against shipped 0.8284, so beating shipped's
    single draw is partly a test of shipped's luck, not of the data.
  * The question is whether the data helps. Same seed means the same
    train/val split and the same initialisation, so the N - A difference
    per seed is the clean measurement.

RULE (all must hold)
  1. Paired over all 10 seeds (3 from Day 368B + 7 new: 11 23 31 47 59 71 97):
     mean(N - A) on FSD50K eval > 0, one-sided paired t-test p < 0.05.
  2. N's mean over 10 seeds >= shipped v5 on FSD50K eval, AudioSet held-out
     AND Nonspeech7k test.
  3. The exported model - the N seed with the MEDIAN FSD50K score, converted
     to float16 tflite - scores >= shipped on FSD50K eval through the real
     tflite inference path.

If 1 fails, the data does not reliably help; stop. If 1 passes but 2 or 3
fails, the data helps but not enough to replace what ships; record it.
"""
import glob
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUTS = [r"D:\zapsafe\kaggle_upload\kernel_scream_armd_ns7k\output",
        r"D:\zapsafe\kaggle_upload\kernel_scream_armd_ns7k\output_v2"]
FIRST = [42, 7, 123]
NEW = [11, 23, 31, 47, 59, 71, 97]
SETS = ("fsd50k_eval", "audioset_heldout", "nonspeech7k_test")
SHIPPED = {"fsd50k_eval": 0.8284, "audioset_heldout": 0.9069, "nonspeech7k_test": 0.9817}


def main():
    from scipy import stats
    rows = {}
    for o in OUTS:
        p = os.path.join(o, "progress.jsonl")
        if os.path.exists(p):
            for line in open(p):
                r = json.loads(line)
                rows[(r["arm"], r["seed"])] = (r["auc"], o)
    seeds = FIRST + NEW
    missing = [(a, s) for s in seeds for a in ("A_armD", "N_armD_plus_ns7k") if (a, s) not in rows]
    if missing:
        sys.exit(f"incomplete: missing {missing}")

    A = {k: np.array([rows[("A_armD", s)][0][k] for s in seeds]) for k in SETS}
    N = {k: np.array([rows[("N_armD_plus_ns7k", s)][0][k] for s in seeds]) for k in SETS}
    d = N["fsd50k_eval"] - A["fsd50k_eval"]
    t = stats.ttest_rel(N["fsd50k_eval"], A["fsd50k_eval"], alternative="greater")
    r1 = bool(d.mean() > 0 and t.pvalue < 0.05)
    r2 = {k: bool(N[k].mean() >= SHIPPED[k]) for k in SETS}

    order = np.argsort(N["fsd50k_eval"])
    med_seed = seeds[int(order[len(order) // 2])]
    res = {"seeds": seeds,
           "A": {k: {"mean": round(float(A[k].mean()), 4), "per_seed": A[k].tolist()} for k in SETS},
           "N": {k: {"mean": round(float(N[k].mean()), 4), "per_seed": N[k].tolist()} for k in SETS},
           "shipped": SHIPPED,
           "paired_fsd50k": {"mean_diff": round(float(d.mean()), 4),
                             "n_positive": int((d > 0).sum()), "n": len(d),
                             "t": round(float(t.statistic), 3),
                             "p_one_sided": round(float(t.pvalue), 4)},
           "rule1_data_helps": r1, "rule2_mean_ge_shipped": r2,
           "median_seed": med_seed}

    r3 = None
    if r1 and all(r2.values()):
        import tensorflow as tf
        sys.path.insert(0, HERE)
        import scream_nonspeech7k as ns
        from sklearn.metrics import roc_auc_score
        src = rows[("N_armD_plus_ns7k", med_seed)][1]
        m = tf.keras.models.load_model(os.path.join(src, f"armd_N_armD_plus_ns7k_seed{med_seed}.keras"))
        conv = tf.lite.TFLiteConverter.from_keras_model(m)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        path = os.path.join(HERE, "scream_classifier_v6_candidate.tflite")
        open(path, "wb").write(blob)
        f = np.load(os.path.join(ns.SV5, "features_v5.npz"), allow_pickle=True)
        Xn, yn, Xt, yt, _ = ns.build()
        sets = {"fsd50k_eval": (f["Xf"], f["yf"].astype(int)),
                "audioset_heldout": (f["Xa"], f["ya"].astype(int)),
                "nonspeech7k_test": (Xt, yt)}
        tfl = {k: round(float(roc_auc_score(yy, ns.tflite_scores(path, XX))), 4)
               for k, (XX, yy) in sets.items()}
        r3 = bool(tfl["fsd50k_eval"] >= SHIPPED["fsd50k_eval"])
        res["exported"] = {"seed": med_seed, "kb": round(len(blob) / 1024, 1), "tflite_auc": tfl}
    res["rule3_exported_ge_shipped"] = r3
    res["ships"] = bool(r1 and all(r2.values()) and r3)
    json.dump(res, open(os.path.join(HERE, "scream_ns7k_decision.json"), "w"), indent=2)
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
