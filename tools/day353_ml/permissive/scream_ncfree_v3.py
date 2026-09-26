"""Day 361E - arm C's composition at the REAL recipe, head-to-head with the
shipped NC model.

WHAT 361D SETTLED, AND WHAT IT DID NOT
======================================
Arm C -- ESC-50 dropped, FSD50K rows re-extracted from the CC0/CC-BY lists,
plus 2,500 fresh CC0/CC-BY negatives spanning 181 labels -- measured
**0.7900** against arm A's 0.7823, every seed above A's mean. So the DATA
COMPOSITION is fine: replacing the diversity works where deleting it
(arm B, 0.7628) did not.

But that ran the simplified A/B recipe: 12 epochs, batch 64. The shipped
`scream_classifier_v5` reads ~0.90. Shipping a 0.79 model to win a licence
argument would be the trade Day 361B correctly refused, in a new costume.

The two recipes turn out to differ ONLY in epochs and batch size --
`build_train_scream.py::net` and the A/B `net` are the same architecture
layer for layer. So the real recipe can simply be applied to arm C's data.

    A/B recipe    12 epochs, batch 64
    v5 recipe     30 epochs, batch 32

HOW THIS IS JUDGED
==================
Head-to-head against the SHIPPED `scream_classifier_v5.tflite`, both scored
on the SAME fixture (`Xf`/`yf` from features_v5.npz), the shipped model
through its real .tflite inference path. That matters: the 0.9057 on record
was measured by a different script on its own eval load, and comparing
against a number from a different eval set is exactly the mistake Day 352
made and had to withdraw.

SHIP RULE, fixed before running:
    worst seed >= shipped AUC on the same fixture.
Not the mean -- a mean that depends on one lucky seed is not a model, and
this would REPLACE a shipped safety detector. If it fails, report the trade
and keep v5.

CACHING: 361D re-extracted 5,018 clips and threw the arrays away. This
caches them, so the recipe can be re-run without paying for extraction.
"""
from __future__ import annotations

import io
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SV5 = r"C:\Users\hridy\Desktop\zapsafe\work\scream_v5"
ASSETS = (r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding"
          r"\zapsafe_mobile_main_reconcile\assets\models")
SHIPPED = "scream_classifier_v5.tflite"
CACHE = os.path.join(HERE, "armC_features.npz")

N_MELS, FRAMES = 128, 131
SEEDS = (42, 7, 123)
EPOCHS, BATCH = 30, 32          # the v5 recipe, not the A/B recipe


def build_arm_c():
    """Arm C exactly as 361D built it, cached after the first run."""
    if os.path.exists(CACHE):
        d = np.load(CACHE)
        print("arm C from cache: %s pos=%d" % (d["X"].shape, d["y"].sum()))
        return d["X"], d["y"].astype(int)

    import scream_ncfree_v2 as v2
    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    X, y, src = d["X"], np.asarray(d["y"]).astype(int), np.asarray(d["src"])
    DROP = {"esc_neg", "fsd_dev_neg", "fsd_dev_pos"}
    keep = np.array([s not in DROP for s in src])

    rng = np.random.RandomState(42)
    pos = v2.read_list(os.path.join(HERE, "scream_dev_pos.txt"))
    neg = v2.read_list(os.path.join(HERE, "scream_dev_neg.txt"))
    fresh = v2.fresh_negatives(set(pos) | set(neg), rng)

    def paths(ids):
        return [os.path.join(v2.DEV_AUDIO, "%s.wav" % f) for f in ids]

    Xp = v2.extract(paths(pos), "perm_pos")
    Xn = v2.extract(paths(neg), "perm_neg")
    Xr = v2.extract(paths(fresh), "fresh_neg")

    Xc = np.concatenate([X[keep].astype(np.float16), Xp, Xn, Xr])
    yc = np.concatenate([y[keep], np.ones(len(Xp), int),
                         np.zeros(len(Xn) + len(Xr), int)])
    np.savez_compressed(CACHE, X=Xc, y=yc)
    print("arm C built and cached: %s pos=%d" % (Xc.shape, yc.sum()))
    return Xc, yc.astype(int)


def net(seed):
    """Layer for layer identical to build_train_scream.py::net."""
    import tensorflow as tf
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)
    inp = tf.keras.Input(shape=(N_MELS, FRAMES))
    x = tf.keras.layers.Reshape((N_MELS, FRAMES, 1))(inp)
    for f in (16, 32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D(2)(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    out = tf.keras.layers.Dense(1, activation="sigmoid", name="scream")(x)
    return tf.keras.Model(inp, out, name="scream_ncfree_v3")


def main():
    import tensorflow as tf
    from sklearn.metrics import roc_auc_score

    d = np.load(os.path.join(SV5, "features_v5.npz"), allow_pickle=True)
    Xf, yf = d["Xf"].astype(np.float32), np.asarray(d["yf"]).astype(int)
    print("eval fixture %s pos=%d (base rate %.3f)"
          % (Xf.shape, yf.sum(), yf.mean()))

    # The incumbent, through its real inference path, on THIS fixture.
    it = tf.lite.Interpreter(model_path=os.path.join(ASSETS, SHIPPED))
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
    shape = [int(v) for v in i0["shape"]]
    ps = np.zeros(len(Xf))
    for k in range(len(Xf)):
        it.set_tensor(i0["index"],
                      Xf[k:k + 1].reshape(shape).astype(i0["dtype"]))
        it.invoke()
        ps[k] = float(it.get_tensor(o0["index"]).ravel()[0])
    auc_ship = float(roc_auc_score(yf, ps))
    print("shipped %s (NC): AUC %.4f on this fixture\n" % (SHIPPED, auc_ship))

    Xc, yc = build_arm_c()
    n1, n0 = int(yc.sum()), int((1 - yc).sum())
    aucs, models = [], []
    for s in SEEDS:
        m = net(s)
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
        m.fit(Xc.astype(np.float32), yc, epochs=EPOCHS, batch_size=BATCH,
              verbose=0,
              class_weight={0: len(yc) / (2.0 * max(n0, 1)),
                            1: len(yc) / (2.0 * max(n1, 1))})
        a = float(roc_auc_score(yf, m.predict(Xf, verbose=0).ravel()))
        aucs.append(a)
        models.append(m)
        print("  NC-free seed %-5d AUC %.4f" % (s, a), flush=True)

    a = np.array(aucs)
    ship = bool(a.min() >= auc_ship)
    print("\n  shipped v5 (NC)   %.4f" % auc_ship)
    print("  NC-free arm C     mean %.4f  min %.4f  max %.4f"
          % (a.mean(), a.min(), a.max()))
    print("  delta mean %+.4f   worst seed %+.4f"
          % (a.mean() - auc_ship, a.min() - auc_ship))
    print("  SHIP (worst seed >= shipped) -> %s" % ship)

    out = {"shipped_auc_same_fixture": round(auc_ship, 4),
           "ncfree_mean": round(float(a.mean()), 4),
           "ncfree_min": round(float(a.min()), 4),
           "ncfree_max": round(float(a.max()), 4),
           "delta_mean": round(float(a.mean() - auc_ship), 4),
           "epochs": EPOCHS, "batch": BATCH,
           "n_train": int(len(yc)), "n_pos": int(yc.sum()),
           "ship_rule": "worst seed >= shipped on the same fixture",
           "ships": ship}
    if ship:
        pick = int(np.argsort(a)[len(a) // 2])      # median seed, not best
        conv = tf.lite.TFLiteConverter.from_keras_model(models[pick])
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
        blob = conv.convert()
        open(os.path.join(HERE, "scream_ncfree_v3.tflite"), "wb").write(blob)
        out["exported_seed"] = SEEDS[pick]
        out["float16_kb"] = round(len(blob) / 1024, 1)
        print("  exported scream_ncfree_v3.tflite from the MEDIAN seed "
              "(%d), %s KB" % (SEEDS[pick], out["float16_kb"]))
    else:
        print("  -> keep v5; this is a licence-for-accuracy trade of %.4f"
              % (auc_ship - a.min()))
    json.dump(out, open(os.path.join(HERE, "scream_ncfree_v3.json"), "w"),
              indent=2)
    print("report written")


if __name__ == "__main__":
    main()
