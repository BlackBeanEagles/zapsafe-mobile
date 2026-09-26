"""Day 360 - scream's NC flag is 360 negative clips. Drop them.

THE EARLIER EXPERIMENT ASKED THE WRONG QUESTION
===============================================
Day 359C trained a permissive scream FROM SCRATCH on the 218 CC0/CC-BY
FSD50K positives and it lost badly (0.82-0.86 vs 0.9057). That was the wrong
comparison: it threw away every other source, including VocalAffectBench,
which is **MIT** and supplies most of the positives.

Looking at what scream v5 actually trained on:

    fsd_dev_neg      4257   0 pos     FSD50K (85% CC0/CC-BY per clip)
    asvp_neg/pos     2315   1115      ASVP-ESD (research)
    as_neg/scream    1262     68      AudioSet (labels CC-BY, YouTube audio)
    VocalAffectBench ~6100  1503      MIT  <- Cough/Laughter/Scream/Sneeze/
                                             Crying/Sigh/Sniff/Moan/Pant/...
    fsd_dev_pos       441    441
    esc_neg           360      0      ESC-50, CC BY-NC 3.0   <- THE NC SOURCE

**ESC-50 contributes 360 negative clips out of 14,749 -- 2.4% of the data
and none of the positives.** That is the entire hard-NC dependency.

So the question is not "can permissive data replace scream" but "does
removing 360 negatives cost anything". This measures that.

WHAT THIS DOES NOT FULLY CLEAR: FSD50K is per-clip licensed and roughly 15%
of its clips are CC BY-NC. Those rows are inside fsd_dev_neg/fsd_dev_pos and
cannot be separated from the cached feature array, which stores a source tag
but no filenames. Dropping ESC-50 removes the *named* NC corpus; the FSD50K
slice needs a re-extraction to address and is reported as still open rather
than glossed.

SHIP RULE, fixed before running: non-regression. Removing negatives should
not help, so anything from -0.005 upward counts as holding.
"""
from __future__ import annotations

import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
SEEDS = (42, 7, 123)
DROP = {"esc_neg"}


def net(shape, seed):
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=shape)
    x = tf.keras.layers.Reshape(shape + (1,))(inp) if len(shape) == 2 else inp
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    return tf.keras.Model(inp, out, name="scream_ncfree")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    X = d["X"].astype(np.float32)
    y = np.asarray(d["y"]).astype(int)
    src = np.asarray(d["src"])
    Xf = d["Xf"].astype(np.float32)          # the FSD50K eval fixture
    yf = np.asarray(d["yf"]).astype(int)
    print("pooled %s pos=%d | eval fixture %s pos=%d"
          % (X.shape, y.sum(), Xf.shape, yf.sum()))

    import collections
    print("sources:", dict(collections.Counter(src.tolist()).most_common(6)))
    keep = np.array([s not in DROP for s in src])
    print("dropping %s -> %d rows removed (%d pos)"
          % (sorted(DROP), int((~keep).sum()), int(y[~keep].sum())))

    res = {}
    for tag, mask in (("A: with ESC-50", np.ones(len(y), bool)),
                      ("B: NC-free", keep)):
        Xtr, ytr = X[mask], y[mask]
        n1, n0 = int(ytr.sum()), int((1 - ytr).sum())
        aucs, models = [], []
        for s in SEEDS:
            m = net(X.shape[1:], s)
            m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                      loss="binary_crossentropy",
                      metrics=[tf.keras.metrics.AUC(name="auc")])
            m.fit(Xtr, ytr, epochs=12, batch_size=64, verbose=0,
                  class_weight={0: len(ytr) / (2.0 * max(n0, 1)),
                                1: len(ytr) / (2.0 * max(n1, 1))})
            aucs.append(float(roc_auc_score(
                yf, m.predict(Xf, verbose=0).ravel())))
            models.append(m)
        a = np.array(aucs)
        res[tag] = {"mean": round(float(a.mean()), 4),
                    "min": round(float(a.min()), 4),
                    "n": int(len(ytr)), "models": models}
        print("  %-16s n=%-6d mean %.4f (min %.4f max %.4f)"
              % (tag, len(ytr), a.mean(), a.min(), a.max()), flush=True)

    dlt = res["B: NC-free"]["mean"] - res["A: with ESC-50"]["mean"]
    print("\n  B-A %+.4f" % dlt)
    holds = dlt >= -0.005
    print("  -> %s" % ("NC-FREE HOLDS - ESC-50's 360 negatives cost nothing"
                       if holds else
                       "removing ESC-50 costs accuracy; reporting as a trade"))
    out = {k: {kk: vv for kk, vv in v.items() if kk != "models"}
           for k, v in res.items()}
    out["delta"] = round(float(dlt), 4)
    out["holds"] = bool(holds)
    out["note"] = ("FSD50K's ~15% CC BY-NC slice is still inside "
                   "fsd_dev_neg/pos and needs a re-extraction to remove; "
                   "not addressed here")
    if holds:
        ms = res["B: NC-free"]["models"]
        pick = 1
        conv = tf.lite.TFLiteConverter.from_keras_model(ms[pick])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "scream_ncfree_v6.tflite"), "wb").write(blob)
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print("  exported scream_ncfree_v6.tflite (%s KB)"
              % out["float16_kb"])
    json.dump(out, open(os.path.join(HERE, "scream_ncfree.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
