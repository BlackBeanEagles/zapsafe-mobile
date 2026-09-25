"""Day 358 - WavLM embeddings vs the 38-dim vector, same task, same corpus.

THE NUMBER TO BEAT
==================
`h_aggressive_v4_38` reads **0.641** on MELD test+dev -- the gate's own
measurement through the shipped .tflite, and the figure six corpora failed
to move. The task is unchanged here: aggressive (anger, fear, disgust)
against calm (neutral, happy), trained on MELD train, scored on MELD
test+dev.

Nothing else differs. No new corpus, no new labels, no different window.
Only the representation.

WHAT EACH OUTCOME MEANS, fixed before running
=============================================
  >= 0.75   the Day 356 diagnosis was right: the 38-dim vector was the
            ceiling, and a learned representation is the path. The
            deployment problem (94M params vs a 4.7 MB budget) then becomes
            worth solving.
  0.68-0.75 real but modest gain; worth weighing against a large asset and
            a new Dart audio path.
  <= 0.68   the diagnosis was WRONG. The models are near the ceiling of the
            task on this data, and no representation change rescues them.
            That closes the question cheaply and honestly.

LAYERS ARE COMPARED because the last transformer layer is usually not the
best for paralinguistics -- top layers specialise toward the pretraining
objective. Reporting only layer 12 would under-measure the idea.

TWO CONTROLS, both able to embarrass the result:
  * a LINEAR probe as well as an MLP. If linear already reaches the MLP's
    score, the embedding is doing the work rather than the classifier, which
    is the stronger claim.
  * a SHUFFLED-LABEL run on the winning layer. 1536 dims on ~8k rows can
    memorise; if shuffled labels also score above chance, the evaluation is
    leaking and the headline means nothing.
"""
from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
LAYERS = (0, 4, 6, 8, 12)
POS = {"anger", "fear", "disgust"}
NEG = {"neutral", "happy"}
BASELINE_38DIM = 0.641
SEED = 42


def load(split, layer):
    d = np.load(os.path.join(HERE, "meld_%s_wavlm_L%d.npz" % (split, layer)),
                allow_pickle=True)
    X = np.nan_to_num(d["X"].astype(np.float32), nan=0.0, posinf=0.0,
                      neginf=0.0)
    emo = np.asarray(d["emo"])
    keep = np.array([e in (POS | NEG) for e in emo])
    y = np.array([1 if e in POS else 0 for e in emo], np.int64)
    return X[keep], y[keep], np.asarray(d["spk"])[keep]


def boot(y, p, n=2000):
    from sklearn.metrics import roc_auc_score
    rng = np.random.RandomState(0)
    b = []
    for _ in range(n):
        i = rng.randint(0, len(y), len(y))
        if len(set(y[i].tolist())) < 2:
            continue
        b.append(roc_auc_score(y[i], p[i]))
    return float(np.percentile(b, 2.5)), float(np.percentile(b, 97.5))


def mlp(Xtr, ytr, Xte, dim, seed=SEED):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    m = tf.keras.Sequential([
        tf.keras.Input(shape=(dim,)),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="binary_crossentropy",
              metrics=[tf.keras.metrics.AUC(name="auc")])
    n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
    m.fit(Xtr, ytr, epochs=40, batch_size=128, verbose=0,
          class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                        1: len(ytr) / (2.0 * max(n1, 1))})
    return m.predict(Xte, verbose=0).ravel()


def main():
    from sklearn.metrics import roc_auc_score
    from sklearn.linear_model import LogisticRegression

    missing = [l for l in LAYERS
               if not glob.glob(os.path.join(HERE, "meld_train_wavlm_L%d.npz" % l))]
    if missing:
        print("missing train layers: %s -- run extract first" % missing)
        return

    print("task: aggressive (anger/fear/disgust) vs calm (neutral/happy)")
    print("baseline, 38-dim shipped model on MELD eval: %.3f\n"
          % BASELINE_38DIM)

    rows = []
    best = None
    for l in LAYERS:
        Xtr, ytr, _ = load("train", l)
        Xte, yte, _ = load("eval", l)
        mu, sd = Xtr.mean(0), Xtr.std(0) + 1e-8
        Ztr = ((Xtr - mu) / sd).astype(np.float32)
        Zte = ((Xte - mu) / sd).astype(np.float32)

        lr = LogisticRegression(max_iter=3000, class_weight="balanced")
        lr.fit(Ztr, ytr)
        a_lin = float(roc_auc_score(yte, lr.predict_proba(Zte)[:, 1]))

        p = mlp(Ztr, ytr, Zte, Xtr.shape[1])
        a_mlp = float(roc_auc_score(yte, p))
        lo, hi = boot(yte, p)

        print("  layer %-2d  linear %.4f   MLP %.4f  CI [%.4f, %.4f]   "
              "vs 38-dim %+.4f" % (l, a_lin, a_mlp, lo, hi,
                                   a_mlp - BASELINE_38DIM), flush=True)
        rows.append({"layer": l, "linear": round(a_lin, 4),
                     "mlp": round(a_mlp, 4), "ci95": [round(lo, 4),
                                                      round(hi, 4)],
                     "delta_vs_38dim": round(a_mlp - BASELINE_38DIM, 4),
                     "n_train": int(len(ytr)), "n_eval": int(len(yte))})
        if best is None or a_mlp > best[1]:
            best = (l, a_mlp, Ztr, ytr, Zte, yte)

    l, a, Ztr, ytr, Zte, yte = best
    print("\n  best layer %d at %.4f (38-dim: %.3f, delta %+.4f)"
          % (l, a, BASELINE_38DIM, a - BASELINE_38DIM))

    # CONTROL: shuffled labels on the winning layer
    rng = np.random.RandomState(SEED)
    ysh = ytr.copy()
    rng.shuffle(ysh)
    p_sh = mlp(Ztr, ysh, Zte, Ztr.shape[1])
    a_sh = float(roc_auc_score(yte, p_sh))
    print("  CONTROL shuffled-label AUC: %.4f (must be ~0.50)" % a_sh)
    leaky = abs(a_sh - 0.5) > 0.06

    if a >= 0.75:
        v = ("LEARNED REPRESENTATION WINS - the 38-dim vector was the "
             "ceiling; the deployment problem is now worth solving")
    elif a >= 0.68:
        v = ("MODEST GAIN - real but weigh against a ~377 MB encoder and a "
             "new Dart audio path")
    else:
        v = ("NO GAIN - the Day 356 diagnosis was wrong; these models are "
             "near the task ceiling on this data and no representation "
             "change rescues them")
    if leaky:
        v = ("EVALUATION IS LEAKING (shuffled labels score %.4f) - the "
             "headline means nothing until that is explained" % a_sh)
    print("  -> %s" % v)

    json.dump({"baseline_38dim": BASELINE_38DIM, "layers": rows,
               "best_layer": l, "best_auc": round(a, 4),
               "shuffled_control": round(a_sh, 4), "verdict": v},
              open(os.path.join(HERE, "compare_report.json"), "w"), indent=2)
    print("report written")


if __name__ == "__main__":
    main()
